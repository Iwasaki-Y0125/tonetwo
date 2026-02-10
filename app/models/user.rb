class User < ApplicationRecord
  PASSWORD_MIN_LENGTH = 12
  PASSWORD_COMPLEXITY = /\A(?=.*[A-Za-z])(?=.*\d).+\z/
  CURRENT_TERMS_VERSION = "v1"
  CURRENT_PRIVACY_VERSION = "v1"

  # 仮想属性: 利用規約同意チェックボックス
  attr_accessor :terms_agreed

  has_secure_password
  has_many :sessions, dependent: :destroy

  # DB保存前に規約同意のタイムスタンプとバージョンを設定する（新規登録時,同意有のみ）
  before_validation :stamp_policy_consents, on: :create, if: :terms_agreed_accepted?

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  validates :email_address, presence: true, uniqueness: { case_sensitive: false }

  validates :password, length: { minimum: PASSWORD_MIN_LENGTH, message: "は12文字以上で入力してください" }, allow_nil: true
  validates :password, format: { with: PASSWORD_COMPLEXITY, message: "は英字と数字を含めてください" }, allow_nil: true
  validates :terms_agreed, acceptance: { accept: "1", message: "に同意してください" }, on: :create
  validates :terms_accepted_at, :privacy_accepted_at, :terms_version, :privacy_version, presence: true,
            on: :create, if: :terms_agreed_accepted?

  private

  def terms_agreed_accepted?
    ActiveModel::Type::Boolean.new.cast(terms_agreed)
  end

  # 同意時点で有効な規約バージョンと日時をサーバ側で確定して保存する
  def stamp_policy_consents
    accepted_at = Time.current

    self.terms_accepted_at ||= accepted_at
    self.privacy_accepted_at ||= accepted_at
    self.terms_version ||= CURRENT_TERMS_VERSION
    self.privacy_version ||= CURRENT_PRIVACY_VERSION
  end
end
