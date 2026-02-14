require "test_helper"

class PostsFlowTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    Rails.cache.clear
    FilterTerm.delete_all
  end

  test "ログイン済みユーザーは投稿画面を表示できる" do
    sign_in_as(users(:one))

    get new_post_path

    assert_response :success
    assert_select "h1", "投稿作成"
  end

  test "prohibit語が含まれる場合は投稿できずエラーを表示する" do
    sign_in_as(users(:one))
    FilterTerm.create!(term: "しね", action: "prohibit")

    post posts_path, params: { post: { body: "しね" } }

    assert_response :unprocessable_entity
    assert_select ".alert.alert-error", text: /不適切なワードを含むため投稿できません/
  end

  test "support語が含まれる場合はサポートページへ遷移する" do
    sign_in_as(users(:one))
    FilterTerm.create!(term: "らくにしにたい", action: "support")

    post posts_path, params: { post: { body: "らくにしにたい" } }

    assert_redirected_to support_page_path
  end

end
