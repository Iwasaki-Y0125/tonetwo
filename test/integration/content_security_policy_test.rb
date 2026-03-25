require "test_helper"

class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  test "root page includes report only csp header" do
    get root_path

    assert_response :success

    header = response.headers["Content-Security-Policy-Report-Only"]
    assert_includes header, "default-src 'self'"
    assert_includes header, "base-uri 'none'"
    assert_includes header, "form-action 'self'"
    assert_includes header, "frame-ancestors 'none'"
    assert_includes header, "img-src 'self'"
    assert_includes header, "object-src 'none'"
  end
end
