require "test_helper"
require_relative "test_helpers/system_auth_test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include SystemAuthTestHelper

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    options.binary = "/usr/bin/chromium"
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--window-size=1400,1400")
  end
end
