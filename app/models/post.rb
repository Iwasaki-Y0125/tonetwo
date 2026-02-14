class Post < ApplicationRecord
  SENTIMENT_LABELS = %w[pos neg].freeze
  PROHIBIT_MESSAGE = "は不適切なワードを含むため投稿できません".freeze
  SUPPORT_MESSAGE = "サポートページへ移動します".freeze

  belongs_to :user

  # ポストの削除機能は追加しない予定だが、万が一のために関連するpost_termsは削除するようにしておく。
  has_many :post_terms, dependent: :delete_all
  has_many :terms, through: :post_terms

  # 投稿作成を先に完了させ、解析は失敗時に再試行できるよう非同期で実行する。
  after_create_commit :enqueue_analysis_job

  validates :body,
            presence: { message: "を入力してください" },
            length: { maximum: 140, message: "は140文字以内で入力してください" }
  validates :sentiment_label,
            inclusion: { in: SENTIMENT_LABELS, message: "は不正な値です" },
            allow_nil: true
  validate :reject_filtered_terms

  # controller側で「サポートページへ遷移するか」を判定するためのフラグ。
  def support_required?
    @support_required == true
  end

  # prohibitヒット時だけ画面でエラー表示を出し分けるための判定。
  def prohibit_hit?
    errors[:body].include?(PROHIBIT_MESSAGE)
  end

  private

  # 投稿保存前に危険語を判定する。
  # support語が含まれる場合はサポート導線を優先し、prohibit語の通常エラーより先に扱う。
  def reject_filtered_terms
    # 検証のたびに状態を初期化し、前回判定のフラグ残りを防ぐ。
    @support_required = false
    return if body.blank?

    matched_terms = FilterTerm.matching(body)
    return if matched_terms.empty?

    if matched_terms.where(action: "support").exists?
      @support_required = true
      # 保存は止めつつ、controllerがサポートページへ自動遷移できるようにメッセージを積む。
      errors.add(:base, SUPPORT_MESSAGE)
    else
      errors.add(:body, PROHIBIT_MESSAGE)
    end
  end

  def enqueue_analysis_job
    Posts::AnalyzePostJob.perform_later(post_id: id)
  end
end
