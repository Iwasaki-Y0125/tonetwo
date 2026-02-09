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
end
