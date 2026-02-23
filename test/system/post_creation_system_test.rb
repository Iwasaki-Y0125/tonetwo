require "application_system_test_case"

class PostCreationSystemTest < ApplicationSystemTestCase
  test "タイムラインから投稿作成して受付確認カードを表示する" do
    login_as(users(:one))

    within all("form.tt-compose-form").first do
      find("textarea[name='post[body]']").set("system投稿テスト")
      click_on "投稿"
    end

    assert_current_path similar_timeline_path
    assert_selector ".tt-post-confirm-card"
    assert_selector ".tt-post-confirm-title", text: "あなたの投稿を受付けました"
    assert_selector ".tt-post-confirm-body", text: "system投稿テスト"
  end

  test "投稿フォームで140字超過時は送信が無効化される" do
    login_as(users(:one))

    within all("form.tt-compose-form").first do
      textarea = find("textarea[name='post[body]']")
      textarea.set("a" * 141)
      page.execute_script("arguments[0].dispatchEvent(new Event('input', { bubbles: true }))", textarea)
      assert page.evaluate_script("arguments[0].disabled", find("input[type='submit']"))
      assert_text "140字を超えているため投稿できません。"
    end

    assert_current_path timeline_path
  end

  test "投稿フォームで140字ちょうどは送信できる" do
    login_as(users(:one))

    body = "b" * 140
    within all("form.tt-compose-form").first do
      textarea = find("textarea[name='post[body]']")
      textarea.set(body)
      page.execute_script("arguments[0].dispatchEvent(new Event('input', { bubbles: true }))", textarea)
      assert_equal false, page.evaluate_script("arguments[0].disabled", find("input[type='submit']"))
      click_on "投稿"
    end

    assert_current_path similar_timeline_path
    assert_selector ".tt-post-confirm-body", text: body
  end
end
