require "test_helper"
require "digest/md5"

class SessionsControllerTest < ActionController::TestCase
  tests SessionsController
  include ActiveSupport::Testing::TimeHelpers

  setup do
    Rails.cache.clear
    @user = users(:one)
    @request.env["REMOTE_ADDR"] = test_remote_ip
  end

  test "return_to_after_authenticating(ログイン後のリダイレクト先）に外部URLが注入されたらrootにフォールバックする" do
    session[:return_to_after_authenticating] = "https://evil.example/phishing"

    post :create, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_url
  end

  test "11回目の`POST /session`で既存rate_limit経由の抑止が発火する" do
    throttle_events = []
    subscriber = ActiveSupport::Notifications.subscribe("security.throttle") do |_name, _start, _finish, _id, payload|
      throttle_events << payload if payload[:rule] == "sessions#create"
    end

    10.times do
      post :create, params: { email_address: @user.email_address, password: "wrong-password" }
      assert_redirected_to new_session_path
      assert_equal "メールアドレスまたはパスワードが異なります。", flash[:alert]
    end

    post :create, params: { email_address: @user.email_address, password: "wrong-password" }
    assert_redirected_to new_session_path
    assert_equal "試行回数が上限に達しました。時間をおいて再度お試しください。", flash[:alert]
    assert_equal 1, throttle_events.size
    assert_equal "rails_rate_limit", throttle_events.first[:layer]
    assert_equal "sessions#create", throttle_events.first[:rule]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "3分経過後はPOST /sessionのrate_limitが解除される" do
    10.times do
      post :create, params: { email_address: @user.email_address, password: "wrong-password" }
      assert_redirected_to new_session_path
      assert_equal "メールアドレスまたはパスワードが異なります。", flash[:alert]
    end

    post :create, params: { email_address: @user.email_address, password: "wrong-password" }
    assert_redirected_to new_session_path
    assert_equal "試行回数が上限に達しました。時間をおいて再度お試しください。", flash[:alert]

    travel 3.minutes + 1.second do
      post :create, params: { email_address: @user.email_address, password: "wrong-password" }
      assert_redirected_to new_session_path
      assert_equal "メールアドレスまたはパスワードが異なります。", flash[:alert]
    end
  end

  private

  # 並列実行時にrate_limitキー（IP単位）が衝突しないよう、テストごとに固定IPを分離する。
  def test_remote_ip
    hash = Digest::MD5.hexdigest(name).to_i(16)
    "203.0.113.#{(hash % 200) + 1}"
  end
end
