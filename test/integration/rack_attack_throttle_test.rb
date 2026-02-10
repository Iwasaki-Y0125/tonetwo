require "test_helper"

class RackAttackThrottleTest < ActionDispatch::IntegrationTest
  setup do
    @original_enabled = Rack::Attack.enabled
    @original_cache_store = Rack::Attack.cache.store

    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rack::Attack.enabled = @original_enabled
    Rack::Attack.cache.store = @original_cache_store
  end

  test "basic auth付きリクエストは上限超過で429を返す" do
    headers = { "HTTP_AUTHORIZATION" => "Basic dGVzdDp0ZXN0" }

    20.times do
      get new_session_path, headers: headers
      assert_response :success
    end

    get new_session_path, headers: headers
    assert_response :too_many_requests
    assert_equal "Too Many Requests", response.body
  end

  test "通常リクエストは上限超過で429を返す" do
    240.times do
      get new_session_path
      assert_response :success
    end

    get new_session_path
    assert_response :too_many_requests
    assert_equal "Too Many Requests", response.body
  end

  test "POST /session は上限超過で抑止される" do
    # controller層(302)とmiddleware層(429)の両方で抑止し得るため、固定ステータスは検証しない
    20.times do
      post session_path, params: { email_address: "one@example.com", password: "wrong-password" }
      assert_includes [ 302, 429 ], response.status
    end

    post session_path, params: { email_address: "one@example.com", password: "wrong-password" }
    assert_includes [ 302, 429 ], response.status
    if response.redirect?
      assert_redirected_to new_session_path
      assert_equal "メールアドレスまたはパスワードが異なります。", flash[:alert]
    else
      assert_response :too_many_requests
      assert_equal "Too Many Requests", response.body
    end
  end

  test "POST /sign_up は上限超過で429を返す" do
    20.times do
      post sign_up_path, params: {
        user: {
          email_address: "",
          password: "Password1!",
          password_confirmation: "Password1!"
        }
      }
      assert_response :unprocessable_entity
    end

    post sign_up_path, params: {
      user: {
        email_address: "",
        password: "Password1!",
        password_confirmation: "Password1!"
      }
    }
    assert_response :too_many_requests
    assert_equal "Too Many Requests", response.body
  end
end
