require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "email_addressは必須" do
    user = User.new(email_address: nil)
    assert_not user.valid?
    assert_includes user.errors[:email_address], "can't be blank"
  end

  test "email_addressは重複不可" do
    existing = users(:one)
    user = User.new(email_address: "  #{existing.email_address.upcase}  ")
    assert_not user.valid?
    assert_includes user.errors[:email_address], "has already been taken"
  end

  test "email_addressは前後空白を除去して小文字化される" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end
end
