require "application_system_test_case"

class AuthenticationSystemTest < ApplicationSystemTestCase
  test "未ログインでタイムラインへアクセスするとログイン画面へ遷移する" do
    visit timeline_path

    assert_current_path new_session_path
  end

  test "未ログインでおすすめタイムラインへアクセスするとログイン画面へ遷移する" do
    visit similar_timeline_path

    assert_current_path new_session_path
  end

  test "ログイン失敗後に再入力してログイン成功できる" do
    visit new_session_path

    within all("form[action='#{session_path}']").first do
      fill_in "email_address", with: users(:one).email_address
      fill_in "password", with: "wrong-password"
      click_button "ログイン"
    end

    assert_current_path new_session_path
    assert_text "メールアドレスまたはパスワードが異なります。"

    within all("form[action='#{session_path}']").first do
      fill_in "email_address", with: users(:one).email_address
      fill_in "password", with: "password12345"
      click_button "ログイン"
    end

    assert_current_path timeline_path
    assert_selector "h1", text: "全体タイムライン"
  end

  test "ログイン済みでログイン画面へアクセスするとタイムラインへ戻る" do
    login_as(users(:one))

    visit new_session_path

    assert_current_path timeline_path
  end

  test "ログイン済みでユーザー登録画面へアクセスするとタイムラインへ戻る" do
    login_as(users(:one))

    visit new_sign_up_path

    assert_current_path timeline_path
  end
end
