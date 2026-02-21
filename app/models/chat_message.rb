class ChatMessage < ApplicationRecord
  # ===== 定数 =====
  PROHIBIT_MESSAGE = "不適切なワードを含むため送信できません".freeze
  CONSECUTIVE_SEND_MESSAGE = "今は相手の番です。相手からの返信をお待ちください。".freeze

  # ===== 関連 =====
  belongs_to :chatroom
  belongs_to :user

  # ===== バリデーション =====
  validates :body,
            presence: { message: "を入力してください" },
            length: { maximum: 140, message: "は140文字以内で入力してください" }
  validate :user_is_chat_participant
  validate :prevent_consecutive_send
  validate :reject_filtered_terms

  # ===== メッセージ作成用 =====
  # with_lock : 対象レコードに対して行ロックをかける。ブロック内の処理は一つずつ順番に処理される（=直列化）
  def self.create_in_room!(chatroom:, user:, body:)
    chatroom.with_lock do
      message = chatroom.chat_messages.create!(user: user, body: body)
      # 一覧バッジ判定のため、直近送信者と未読状態を同時に更新する
      chatroom.update!(last_sender: user, has_unread: true)
      message
    end
  end

  # ===== 判定参照用 =====
  # サポートワードが含まれているかどうかを判定するためのメソッド
  def support_required?
    @support_required == true
  end

  private

  # ===== 保存前バリデーション（チャット制約 / モデレーション） =====

  # チャットルームの参加者以外がメッセージを送れないようにするバリデーション
  def user_is_chat_participant
    return unless chatroom && user
    return if chatroom.participant?(user)

    errors.add(:base, "このチャットには参加できません")
  end

  # 連続送信を禁止し、交互返信の前提をサーバ側でも保証する
  def prevent_consecutive_send
    return unless chatroom && user
    return if chatroom.sendable_by?(user)

    errors.add(:base, CONSECUTIVE_SEND_MESSAGE)
  end

  # メッセージ保存前に危険語を判定する。
  # support語がある場合はサポート導線を優先し、prohibitより先に扱う。
  def reject_filtered_terms
    @support_required = false

    matched_terms = FilterTerm.matching(body)
    return if matched_terms.empty?

    if matched_terms.where(action: "support").exists?
      @support_required = true
      errors.add(:base, :invalid)
    else
      errors.add(:body, PROHIBIT_MESSAGE)
    end
  end
end
