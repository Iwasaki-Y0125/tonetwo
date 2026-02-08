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
end
