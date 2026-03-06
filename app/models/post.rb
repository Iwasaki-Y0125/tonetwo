class Post < ApplicationRecord
  SENTIMENT_LABELS = %w[pos neg].freeze
  PROHIBIT_MESSAGE = "不適切なワードを含むため投稿できません".freeze

  belongs_to :user

  #  todo ここら辺の依存関係は、ややこしくなりそうなので、運用後に機能確定してきたら整理する
  # ポストの削除機能は追加しない予定だが、万が一のために関連するpost_termsは削除するようにしておく。
  has_many :post_terms, dependent: :delete_all
  has_many :terms, through: :post_terms

  # restrict_with_error: ポスト削除時に関連チャットがあると削除できず、エラーになる。
  # ユーザー退会後も投稿やチャット内容は残す方針のため。
  has_many :chatrooms, dependent: :restrict_with_error

  # 投稿作成を先に完了させ、解析は失敗時に再試行できるよう非同期で実行する。
  after_create_commit :enqueue_analysis_job

  validates :body,
            presence: { message: "を入力してください" },
            length: { maximum: 140, message: "は140文字以内で入力してください" }
  validates :sentiment_label,
            inclusion: { in: SENTIMENT_LABELS, message: "は不正な値です" },
            allow_nil: true
  validate :reject_filtered_terms

  # 検証のたびに状態を初期化し、前回判定のフラグ残りを防ぐ。
  # controller側で「サポートページへ遷移するか」を判定するためのフラグ。
  def support_required?
    @support_required == true
  end

  # prohibitヒット時だけ画面でエラー表示を出し分けるための判定。
  def prohibit_hit?
    errors[:body].include?(PROHIBIT_MESSAGE)
  end

  private

  # バリデーション
  # 投稿保存前に危険語を判定する。
  # support語が含まれる場合はサポート導線を優先し、prohibit語の通常エラーより先に扱う。
  def reject_filtered_terms
    @support_required = false
    moderation_result = Moderation::SupportProhibitChecker.call(body)
    if moderation_result.support?
      @support_required = true
      # 保存は止めつつ、controllerがサポートページへ自動遷移できるようにする。
      errors.add(:base, :invalid)
      return
    end

    if moderation_result.prohibit?
      errors.add(:body, PROHIBIT_MESSAGE)
      return
    end

    return if moderation_result.ok?
  end

  def enqueue_analysis_job
    Posts::AnalyzePostJob.perform_later(post_id: id)
  end
end
