require "application_system_test_case"

class SignUpFrontendSystemTest < ApplicationSystemTestCase
  test "利用規約未同意ではsubmit無効、条件達成で有効になる" do
    visit new_sign_up_path

    fill_in "user_email_address", with: "new_frontend_user@example.com"
    fill_in "user_password", with: "abc123def456"
    fill_in "user_password_confirmation", with: "abc123def456"

    submit = find("input[type='submit'][value='登録する']")
    assert page.evaluate_script("arguments[0].disabled", submit)

    check "user_terms_agreed"
    assert_equal false, page.evaluate_script("arguments[0].disabled", submit)
    assert_text "英字と数字を含む - OK"
    assert_text "12文字以上 - OK"
  end

  test "パスワード条件未達成のときsubmitは有効化されない" do
    visit new_sign_up_path

    fill_in "user_email_address", with: "invalid_frontend_user@example.com"
    fill_in "user_password", with: "abcdefghijkl"
    fill_in "user_password_confirmation", with: "abcdefghijkl"
    check "user_terms_agreed"

    submit = find("input[type='submit'][value='登録する']")
    assert page.evaluate_script("arguments[0].disabled", submit)
    assert_text "英字と数字を含む - 未達成"
    assert_text "12文字以上 - OK"
  end
end
