require "test_helper"

class SignUpsControllerTest < ActionController::TestCase
  tests SignUpsController
  include ActiveSupport::Testing::TimeHelpers

  setup do
    Rails.cache.clear
  end

  test "11回目の`POST /sign_up`で既存rate_limit経由の抑止が発火する" do
    throttle_events = []
    subscriber = ActiveSupport::Notifications.subscribe("security.throttle") do |_name, _start, _finish, _id, payload|
      throttle_events << payload if payload[:rule] == "sign_ups#create"
    end

    10.times do
      post :create, params: {
        user: {
          email_address: "",
          password: "Password1!",
          password_confirmation: "Password1!"
        }
      }
      assert_response :unprocessable_entity
    end

    post :create, params: {
      user: {
        email_address: "",
        password: "Password1!",
        password_confirmation: "Password1!"
      }
    }
    assert_redirected_to new_sign_up_path
    assert_equal "試行回数が上限に達しました。時間をおいて再度お試しください。", flash[:alert]
    assert_equal 1, throttle_events.size
    assert_equal "rails_rate_limit", throttle_events.first[:layer]
    assert_equal "sign_ups#create", throttle_events.first[:rule]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "3分経過後はPOST /sign_upのrate_limitが解除される" do
    10.times do
      post :create, params: {
        user: {
          email_address: "",
          password: "Password1!",
          password_confirmation: "Password1!"
        }
      }
      assert_response :unprocessable_entity
    end

    post :create, params: {
      user: {
        email_address: "",
        password: "Password1!",
        password_confirmation: "Password1!"
      }
    }
    assert_redirected_to new_sign_up_path
    assert_equal "試行回数が上限に達しました。時間をおいて再度お試しください。", flash[:alert]

    travel 3.minutes + 1.second do
      post :create, params: {
        user: {
          email_address: "",
          password: "Password1!",
          password_confirmation: "Password1!"
        }
      }
      assert_response :unprocessable_entity
    end
  end
end
