require "test_helper"

class AdminAuthFlowTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
    @member = users(:one)
    @member.update!(role: "member")

    @admin = User.create!(
      email_address: "admin-flow@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      terms_agreed: "1",
      role: "admin"
    )
  end

  test "未ログインで /admin へアクセスするとログイン画面へリダイレクトされる" do
    get admin_root_path

    assert_redirected_to new_session_path
  end

  test "member で /admin へアクセスすると root_path へリダイレクトされる" do
    sign_in_as(@member)

    get admin_root_path

    assert_redirected_to root_path
  end

  test "admin で /admin へアクセスすると管理画面を表示できる" do
    sign_in_as(@admin)

    get admin_root_path

    assert_response :success
  end
end
