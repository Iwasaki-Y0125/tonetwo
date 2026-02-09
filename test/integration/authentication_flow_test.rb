require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "ログイン画面表示" do
    get new_session_path
    assert_response :success
  end

  test "ログイン成功" do
    assert_difference("Session.count", 1) do
      post session_path, params: { email_address: @user.email_address, password: "password" }
    end

    assert_redirected_to root_url
    assert cookies[:session_id].present?
  end

  test "ログイン失敗" do
    assert_no_difference("Session.count") do
      post session_path, params: { email_address: @user.email_address, password: "wrong-password" }
    end

    assert_redirected_to new_session_path
    assert cookies[:session_id].blank?
  end

  test "ログアウト" do
    sign_in_as(@user)

    assert_difference("Session.count", -1) do
      delete session_path
    end

    assert_redirected_to new_session_path
    assert cookies[:session_id].blank?
  end

  test "未ログインで認証必須エンドポイントへアクセスするとログイン画面へリダイレクトされる" do
    delete session_path

    assert_redirected_to new_session_path
  end

  test "アイドル期限切れセッションは無効化される" do
    expired_session = @user.sessions.create!(updated_at: 8.days.ago)
    set_session_cookie(expired_session)

    assert_difference("Session.count", -1) do
      delete session_path
    end

    assert_redirected_to new_session_path
    assert cookies[:session_id].blank?
  end

  test "絶対期限切れセッションは無効化される" do
    expired_session = @user.sessions.create!(created_at: 31.days.ago, updated_at: Time.current)
    set_session_cookie(expired_session)

    assert_difference("Session.count", -1) do
      delete session_path
    end

    assert_redirected_to new_session_path
    assert cookies[:session_id].blank?
  end
end
