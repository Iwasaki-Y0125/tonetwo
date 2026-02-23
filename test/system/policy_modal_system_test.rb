require "application_system_test_case"

class PolicyModalSystemTest < ApplicationSystemTestCase
  test "利用規約リンクでモーダル表示し閉じるで非表示になる" do
    visit new_sign_up_path

    click_link "利用規約"
    assert_selector "#policy_modal_overlay"
    assert_selector "#policy_modal .tt-policy-title", text: "利用規約"

    find("#policy_modal button[aria-label='閉じる']").click
    assert_no_selector "#policy_modal_overlay"
  end
end
