require "test_helper"

class PostsFlowTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    Rails.cache.clear
    FilterTerm.delete_all
  end

  test "ログイン済みユーザーはタイムラインで投稿フォームを表示できる" do
    sign_in_as(users(:one))

    get timeline_path

    assert_response :success
    assert_select "form[action='#{posts_path}'] textarea[name='post[body]']"
  end

  test "prohibit語が含まれRefererがない場合は全体TLへ戻りエラーを表示する" do
    sign_in_as(users(:one))
    FilterTerm.create!(term: "しね", action: "prohibit")

    post posts_path, params: { post: { body: "しね" } }

    assert_redirected_to timeline_path
    follow_redirect!
    assert_response :success
    assert_select ".alert.alert-error", text: /不適切なワードを含むため投稿できません/
    assert_select "textarea[name='post[body]']", text: "しね"
  end

  test "prohibit語が含まれRefererがある場合は投稿元ページへ戻り、投稿フォーム上にエラーを表示する" do
    sign_in_as(users(:one))
    FilterTerm.find_or_create_by!(term: "しね", action: "prohibit")

    post posts_path, params: { post: { body: "しね" } }, headers: { "HTTP_REFERER" => timeline_path }

    assert_redirected_to timeline_path
    follow_redirect!
    assert_response :success
    assert_select ".alert.alert-error", text: /不適切なワードを含むため投稿できません/
    assert_select "textarea[name='post[body]']", text: "しね"
  end

  test "support語が含まれる場合はサポートページへ遷移する" do
    sign_in_as(users(:one))
    FilterTerm.create!(term: "らくにしにたい", action: "support")

    post posts_path, params: { post: { body: "らくにしにたい" } }

    assert_redirected_to support_page_path
  end
end
