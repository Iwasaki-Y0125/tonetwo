require "test_helper"

class PolicyLinksTest < ActionDispatch::IntegrationTest
  test "LPフッターにポリシー導線が表示される" do
    get root_path

    assert_response :success
    assert_select "a[href='#{tos_path}']", text: "利用規約"
    assert_select "a[href='#{privacy_path}']", text: "プライバシーポリシー"
    assert_select "a[href='#{licenses_path}']", text: "サードパーティーライセンス"
  end

  test "ログイン画面にポリシー導線が表示される" do
    get new_session_path

    assert_response :success
    assert_select "a[href='#{tos_path}']", text: "利用規約"
    assert_select "a[href='#{privacy_path}']", text: "プライバシーポリシー"
    assert_select "a[href='#{licenses_path}']", text: "サードパーティーライセンス"
  end
end
