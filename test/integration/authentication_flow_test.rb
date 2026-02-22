require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
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

    assert_response :redirect
    assert_redirected_to timeline_url
    assert cookies[:session_id].present?
  end

  test "ログイン失敗" do
    assert_no_difference("Session.count") do
      post session_path, params: { email_address: @user.email_address, password: "wrong-password" }
    end

    assert_redirected_to new_session_path
    assert_equal "メールアドレスまたはパスワードが異なります。", flash[:alert]
    assert cookies[:session_id].blank?
  end

  test "ログアウト" do
    sign_in_as(@user)

    assert_difference("Session.count", -1) do
      delete session_path
    end

    assert_response :see_other
    assert_redirected_to new_session_path
    assert cookies[:session_id].blank?
  end

  test "未ログインで認証必須エンドポイントへアクセスするとログイン画面へリダイレクトされる" do
    delete session_path

    assert_redirected_to new_session_path
  end

  test "未ログインで保護ページへアクセスするとログイン画面へリダイレクトされる" do
    get protected_page_path

    assert_redirected_to new_session_path
  end

  test "ログイン済みでルートへアクセスすると全体TLへリダイレクトされる" do
    sign_in_as(@user)

    get root_path

    assert_redirected_to timeline_path
  end

  test "未ログインで設定ページへアクセスするとログイン画面へリダイレクトされる" do
    get settings_path

    assert_redirected_to new_session_path
  end

  test "ログイン済みなら保護ページを表示できる" do
    sign_in_as(@user)

    get protected_page_path

    assert_response :success
    assert_select "h1", "Protected Page"
  end

  test "ログイン済みなら設定ページにメールアドレスとログアウトボタンを表示する" do
    sign_in_as(@user)

    get settings_path

    masked_email = ApplicationController.helpers.tt_masked_email(@user.email_address)

    assert_response :success
    assert_select "h1", "設定"
    assert_select "p", masked_email
    assert_select "p", text: @user.email_address, count: 0
    assert_select "a[href='#{tos_path}']", text: "利用規約"
    assert_select "a[href='#{privacy_path}']", text: "プライバシーポリシー"
    assert_select "a[href='#{licenses_path}']", text: "サードパーティーライセンス"
    assert_select "a[href='https://forms.gle/6ZxJ4TKCGQ1KdsqG6']", text: "お問い合わせ"
    assert_select "form.button_to[action='#{session_path}'] button", "ログアウト"
  end

  test "ログイン済みヘッダーは設定ナビを表示しログアウトボタンは表示しない" do
    sign_in_as(@user)

    get timeline_path

    assert_response :success
    assert_select "header a[href='#{settings_path}']", text: /設定/
    assert_select "header a", text: "ログアウト", count: 0
  end

  test "未ログインで保護ページへ遷移後にログインすると元ページへ戻る" do
    get protected_page_path
    assert_redirected_to new_session_path

    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to protected_page_path
    assert cookies[:session_id].present?
  end

  test "保護ページ復帰先は1回で消費され次回ログインでは全体TLへ戻る" do
    get protected_page_path
    assert_redirected_to new_session_path

    post session_path, params: { email_address: @user.email_address, password: "password" }
    assert_redirected_to protected_page_path

    delete session_path
    assert_redirected_to new_session_path

    post session_path, params: { email_address: @user.email_address, password: "password" }
    assert_redirected_to timeline_url
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

  test "期限切れセッションで保護ページへアクセスするとセッション無効化後にログイン画面へリダイレクトされる" do
    expired_session = @user.sessions.create!(updated_at: 8.days.ago)
    set_session_cookie(expired_session)

    assert_difference("Session.count", -1) do
      get protected_page_path
    end

    assert_redirected_to new_session_path
    assert cookies[:session_id].blank?
  end
end
