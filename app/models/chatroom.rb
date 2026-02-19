class Chatroom < ApplicationRecord
  belongs_to :post
  belongs_to :reply_user, class_name: "User"
  has_many :chat_messages, dependent: :delete_all

  validates :post_id, uniqueness: { scope: :reply_user_id }
  validate :reply_user_is_not_post_owner

  # クエリ用に、自分が投稿者か返信者か、どちらかならそのチャットを見せるためのスコープ（一覧画面で使用）
  scope :for_user, lambda { |user|
    joins(:post).where("chatrooms.reply_user_id = :user_id OR posts.user_id = :user_id", user_id: user.id)
  }

  # 一覧画面で、最新メッセージの日時順に並べるためのクラスメソッド
  def self.for_index(user)
    for_user(user)
      .includes(:post, :reply_user, chat_messages: :user)
      .to_a
      .sort_by { |chatroom| chatroom.latest_message_at || chatroom.created_at }
      .reverse
  end

  # 投稿を起点に、チャットルーム作成（既存再利用）と初回メッセージ保存を1トランザクションで行う。
  def self.start_with_message!(post:, reply_user:, body:)
    ActiveRecord::Base.transaction do
      chatroom = find_or_create_for!(post: post, reply_user: reply_user)
      chat_message = chatroom.chat_messages.create!(user: reply_user, body: body)
      [ chatroom, chat_message ]
    end
  end

  # 詳細画面で、チャットルームとそのメッセージを取得するためのクラスメソッド
  def self.for_show(id:, user:)
    chatroom = includes(:post, :reply_user, chat_messages: :user).find(id)
    raise ActiveRecord::RecordNotFound unless chatroom.participant?(user)

    chatroom
  end

  # アプリ用に、自分が投稿者か返信者か、どちらかならそのチャットを見せるための絞り条件（詳細画面で使用）
  def participant?(user)
    user_id = user.is_a?(User) ? user.id : user
    reply_user_id == user_id || post.user_id == user_id
  end

  # 一覧画面で最新メッセージ本文と日時を表示するためのメソッド
  # association(:chat_messages).loaded? : すでにチャットルームオブジェクトにチャットメッセージがロードされている場合はDBアクセスを避ける
  def latest_message
    if association(:chat_messages).loaded?
      chat_messages.select(&:persisted?).max_by { |message| [ message.created_at, message.id ] }
    else
      chat_messages.order(created_at: :desc, id: :desc).first
    end
  end

  # 最新メッセージの日時を返すためのメソッド
  def latest_message_at
    latest_message&.created_at
  end

  # 詳細画面で、チャットメッセージを日時順に並べるためのインスタンスメソッド
  def sorted_messages
    chat_messages.select(&:persisted?).sort_by { |message| [ message.created_at, message.id ] }
  end

  # 同じ投稿×同じ返信者のチャットルームを、安全に1件だけ確保する
  # =>ダブルクリックなどで同時にリクエストが来た場合でも、ユニーク制約違反を起こさずに1件だけ作成されるようにする。
  def self.find_or_create_for!(post:, reply_user:)
    # find_or_create_by! : あれば取得、なければ作成
    find_or_create_by!(post: post, reply_user: reply_user)
  # 同時リクエスト競合で、作成時にユニーク制約にぶつかった場合に例外
  rescue ActiveRecord::RecordNotUnique
    # 競合相手が先に作った既存レコードを取り直す
    find_by!(post: post, reply_user: reply_user)
  end

  private

  # 投稿者本人が返信者にならないようにするバリデーション
  def reply_user_is_not_post_owner
    return unless post && reply_user_id
    return unless post.user_id == reply_user_id

    errors.add(:reply_user_id, "投稿者本人は指定できません")
  end
end
