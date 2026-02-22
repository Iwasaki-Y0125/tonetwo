require "test_helper"

class BasicAvailabilityTest < ActionDispatch::IntegrationTest
  test "GET / returns success" do
    get root_path
    assert_response :success
  end

  test "GET /up returns success" do
    get "/up"
    assert_response :success
  end

  test "GET /tos returns success" do
    get tos_path
    assert_response :success
  end

  test "GET /privacy returns success" do
    get privacy_path
    assert_response :success
  end

  test "GET /licenses returns success" do
    get licenses_path
    assert_response :success
  end
end
