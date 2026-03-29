require "test_helper"

class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  test "root page includes csp header" do
    get root_path

    assert_response :success

    header = response.headers["Content-Security-Policy"]
    assert_includes header, "default-src 'self'"
    assert_includes header, "base-uri 'none'"
    assert_includes header, "form-action 'self'"
    assert_includes header, "frame-ancestors 'none'"
    assert_includes header, "img-src 'self'"
    assert_includes header, "style-src 'self'"
    assert_includes header, "object-src 'none'"
    assert_match(/style-src 'self' 'nonce-[^']+'/, header)
    assert_match(/script-src 'self' 'nonce-[^']+'/, header)
  end
end
