require "test_helper"

class SessionsControllerTest < ActionController::TestCase
  tests SessionsController

  setup do
    @user = users(:one)
  end

  test "return_to_after_authenticating(ログイン後のリダイレクト先）に外部URLが注入されたらrootにフォールバックする" do
    session[:return_to_after_authenticating] = "https://evil.example/phishing"

    post :create, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_url
  end
end
