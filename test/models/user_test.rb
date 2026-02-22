require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "email_addressは必須" do
    user = User.new(email_address: nil)
    assert_not user.valid?
    assert_includes user.errors[:email_address], "を入力してください"
  end

  test "email_addressは重複不可" do
    existing = users(:one)
    user = User.new(email_address: "  #{existing.email_address.upcase}  ")
    assert_not user.valid?
    assert user.errors.where(:email_address).any? { |error| error.type == :taken }
  end

  test "email_addressは前後空白を除去して小文字化される" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "passwordは12文字以上が必須" do
    user = User.new(
      email_address: "password_length@example.com",
      password: "abc123def45",
      password_confirmation: "abc123def45"
    )

    assert_not user.valid?
    assert_includes user.errors[:password], "は12文字以上で入力してください"
  end

  test "passwordは英字と数字の両方を含む必要がある" do
    user = User.new(
      email_address: "password_complexity@example.com",
      password: "abcdefghijkl",
      password_confirmation: "abcdefghijkl"
    )

    assert_not user.valid?
    assert_includes user.errors[:password], "は英字と数字を含めてください"
  end

  test "passwordが12文字以上かつ英字と数字を含む場合は有効" do
    user = User.new(
      email_address: "valid_password@example.com",
      password: "abc123def456",
      password_confirmation: "abc123def456",
      terms_agreed: "1"
    )

    assert user.valid?
  end

  test "terms_agreedが未同意だと無効" do
    user = User.new(
      email_address: "terms_required@example.com",
      password: "abc123def456",
      password_confirmation: "abc123def456",
      terms_agreed: "0"
    )

    assert_not user.valid?
    assert_includes user.errors[:terms_agreed], "に同意にチェックしてください"
  end

  test "terms_agreedに同意した場合は同意日時とバージョンが保存される" do
    user = User.create!(
      email_address: "terms_stamped@example.com",
      password: "abc123def456",
      password_confirmation: "abc123def456",
      terms_agreed: "1"
    )

    assert_not_nil user.terms_accepted_at
    assert_not_nil user.privacy_accepted_at
    assert_equal User.current_terms_version, user.terms_version
    assert_equal User.current_privacy_version, user.privacy_version
  end
end
