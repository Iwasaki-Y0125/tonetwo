module SystemAuthTestHelper
  def login_as(user, password: "password12345")
    visit new_session_path

    within all("form[action='#{session_path}']").first do
      fill_in "email_address", with: user.email_address
      fill_in "password", with: password
      click_button "ログイン"
    end

    assert_current_path timeline_path
  end
end
