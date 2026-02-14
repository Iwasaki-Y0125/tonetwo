class User < ApplicationRecord
  PASSWORD_MIN_LENGTH = 12
  PASSWORD_COMPLEXITY = /\A(?=.*[A-Za-z])(?=.*\d).+\z/
  CURRENT_TERMS_VERSION = "v1"
  CURRENT_PRIVACY_VERSION = "v1"
  ATTRIBUTE_JA_NAMES = {
    email_address: "メールアドレス",
    password: "パスワード",
    password_confirmation: "確認用パスワード",
    terms_agreed: "利用規約とプライバシーポリシー"
  }.freeze

  # 仮想属性: 利用規約同意チェックボックス
  attr_accessor :terms_agreed

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :posts, dependent: :restrict_with_error

  def self.human_attribute_name(attribute, options = {})
    ATTRIBUTE_JA_NAMES[attribute.to_sym] || super
  end

  # DB保存前に規約同意のタイムスタンプとバージョンを設定する（新規登録時,同意有のみ）
  before_validation :stamp_policy_consents, on: :create, if: :terms_agreed_accepted?

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  validates :email_address, presence: { message: "を入力してください" },
                            uniqueness: { case_sensitive: false }

  validates :password, length: { minimum: PASSWORD_MIN_LENGTH, message: "は12文字以上で入力してください" }, allow_nil: true
  validates :password, format: { with: PASSWORD_COMPLEXITY, message: "は英字と数字を含めてください" }, allow_nil: true

  # acceptance は nil を素通りするため、未送信も確実に弾けるよう inclusion を使う
  validates :terms_agreed, inclusion: { in: [ "1" ], message: "に同意にチェックしてください" }, on: :create
  validates :terms_accepted_at, :privacy_accepted_at, :terms_version, :privacy_version, presence: true,
            on: :create, if: :terms_agreed_accepted?

  # has_secure_password の英語メッセージを日本語化する
  validate :add_japanese_password_confirmation_error

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

  # has_secure_password の英語メッセージを画面表示用に日本語へ置き換える
  def add_japanese_password_confirmation_error
    return if password.blank?
    return if password == password_confirmation

    errors.delete(:password_confirmation)
    errors.add(:base, "確認用パスワードが一致しません")
  end
end
