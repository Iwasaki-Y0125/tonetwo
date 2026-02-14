require "test_helper"

class PostsControllerTest < ActionController::TestCase
  tests PostsController
  include ActiveSupport::Testing::TimeHelpers

  setup do
    Rails.cache.clear
    FilterTerm.delete_all
    @user = users(:one)
    sign_in_as(@user)
  end

  test "6回目のPOST /postsでrate_limit経由の抑止が発火する" do
    throttle_events = []
    subscriber = ActiveSupport::Notifications.subscribe("security.throttle") do |_name, _start, _finish, _id, payload|
      throttle_events << payload if payload[:rule] == "posts#create"
    end

    5.times do |index|
      post :create, params: { post: { body: "通常投稿#{index}" } }
      assert_redirected_to root_path
    end

    post :create, params: { post: { body: "通常投稿6回目" } }
    assert_redirected_to new_post_path
    assert_equal "投稿回数が上限に達しました。時間をおいて再度お試しください。", flash[:alert]
    assert_equal 1, throttle_events.size
    assert_equal "rails_rate_limit", throttle_events.first[:layer]
    assert_equal "posts#create", throttle_events.first[:rule]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "3分経過後はPOST /postsのrate_limitが解除される" do
    5.times do |index|
      post :create, params: { post: { body: "制限テスト#{index}" } }
      assert_redirected_to root_path
    end

    post :create, params: { post: { body: "制限中投稿" } }
    assert_redirected_to new_post_path
    assert_equal "投稿回数が上限に達しました。時間をおいて再度お試しください。", flash[:alert]

    travel 3.minutes + 1.second do
      post :create, params: { post: { body: "解除後投稿" } }
      assert_redirected_to root_path
    end
  end

  private

  def sign_in_as(user)
    session_record = user.sessions.create!

    ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar.signed[:session_id] = session_record.id
      cookies["session_id"] = cookie_jar[:session_id]
    end
  end
end
