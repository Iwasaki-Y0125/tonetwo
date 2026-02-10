require "test_helper"

class SignUpsFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "未ログインで登録画面を表示できる" do
    get new_sign_up_path

    assert_response :success
  end

  test "登録画面にサインアップ用Stimulus配線が埋め込まれる" do
    get new_sign_up_path

    assert_response :success
    assert_select "form[data-controller='sign-up-submit']"
    assert_select "input[data-sign-up-submit-target='email']"
    assert_select "input[data-sign-up-submit-target='password']"
    assert_select "input[data-sign-up-submit-target='confirmation']"
    assert_select "input[data-sign-up-submit-target='terms']"
    assert_select "input[type='submit'][data-sign-up-submit-target='submit'][disabled]"
  end

  test "有効な入力でユーザー登録でき、セッションが作成される" do
    assert_difference("User.count", 1) do
      assert_difference("Session.count", 1) do
        post sign_up_path, params: {
          user: {
            email_address: "new_user@example.com",
            password: "abc123def456",
            password_confirmation: "abc123def456",
            terms_agreed: "1"
          }
        }
      end
    end

    created_user = User.find_by!(email_address: "new_user@example.com")
    assert_redirected_to root_path
    assert cookies[:session_id].present?
    assert_not_nil created_user.terms_accepted_at
    assert_not_nil created_user.privacy_accepted_at
    assert_equal User::CURRENT_TERMS_VERSION, created_user.terms_version
    assert_equal User::CURRENT_PRIVACY_VERSION, created_user.privacy_version
  end

  test "無効な入力では422でフォームを再表示する" do
    assert_no_difference("User.count") do
      post sign_up_path, params: {
        user: {
          email_address: "invalid_signup@example.com",
          password: "abcdefabcdef",
          password_confirmation: "abcdefabcdef"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "div.alert.alert-error", /入力内容を確認してください/
    assert_select "li", /英字と数字を含めてください/
  end

  test "同意チェックなしでは登録できない" do
    assert_no_difference("User.count") do
      post sign_up_path, params: {
        user: {
          email_address: "no_terms@example.com",
          password: "abc123def456",
          password_confirmation: "abc123def456",
          terms_agreed: "0"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "li", /Terms agreed に同意してください/
  end

  test "ログイン済みユーザーは登録画面にアクセスできずrootへリダイレクトされる" do
    sign_in_as(@user)

    get new_sign_up_path

    assert_redirected_to root_path
  end

  test "ログイン済みユーザーは登録処理を実行できずrootへリダイレクトされる" do
    sign_in_as(@user)

    assert_no_difference("User.count") do
      post sign_up_path, params: {
        user: {
          email_address: "new_user@example.com",
          password: "abc123def456",
          password_confirmation: "abc123def456"
        }
      }
    end

    assert_redirected_to root_path
  end
end
