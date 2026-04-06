require "test_helper"

class MaintenanceModeTest < ActionDispatch::IntegrationTest
  setup do
    @original_maintenance_mode = ENV["MAINTENANCE_MODE"]
  end

  teardown do
    if @original_maintenance_mode.nil?
      ENV.delete("MAINTENANCE_MODE")
    else
      ENV["MAINTENANCE_MODE"] = @original_maintenance_mode
    end
  end

  test "メンテ中でも /up は成功する" do
    ENV["MAINTENANCE_MODE"] = "1"
    get "/up"
    assert_response :success
  end

  test "メンテ中は /timeline が 503 になる" do
    ENV["MAINTENANCE_MODE"] = "1"
    get timeline_path
    assert_response :service_unavailable
  end

  test "メンテ未設定時は通常の認証フローに従う" do
    ENV.delete("MAINTENANCE_MODE")
    get timeline_path
    assert_redirected_to new_session_path
  end
end
