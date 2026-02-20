class ChatMessage < ApplicationRecord
  PROHIBIT_MESSAGE = "不適切なワードを含むため送信できません".freeze

  belongs_to :chatroom
  belongs_to :user

  validates :body,
            presence: { message: "を入力してください" },
            length: { maximum: 140, message: "は140文字以内で入力してください" }
  validate :user_is_chat_participant
  validate :reject_filtered_terms

  def support_required?
    @support_required == true
  end

  def prohibit_hit?
    errors[:body].include?(PROHIBIT_MESSAGE)
  end

  private

  # チャットルームの参加者以外がメッセージを送れないようにするバリデーション
  def user_is_chat_participant
    return unless chatroom && user
    return if chatroom.participant?(user)

    errors.add(:user_id, "はこのチャットに参加できません")
  end

  # メッセージ保存前に危険語を判定する。
  # support語がある場合はサポート導線を優先し、prohibitより先に扱う。
  def reject_filtered_terms
    @support_required = false
    return if body.blank?

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
