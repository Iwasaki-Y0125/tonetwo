require "test_helper"

class PostsFlowTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    Rails.cache.clear
    FilterTerm.delete_all
  end

  test "未ログインユーザーは投稿作成できない" do
    assert_no_difference("Post.count") do
      post posts_path, params: { post: { body: "unauthorized post" } }
    end

    assert_redirected_to new_session_path
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

  test "投稿成功後はおすすめTLに投稿受付確認カードを表示する" do
    sign_in_as(users(:one))

    travel_to Time.zone.now.change(hour: 14, min: 27, sec: 0) do
      post posts_path, params: { post: { body: "投稿確認\nテキスト" } }
    end

    assert_redirected_to similar_timeline_path
    follow_redirect!

    assert_response :success
    assert_select ".tt-post-confirm-card", count: 1
    assert_select ".tt-post-confirm-title", "あなたの投稿を受付けました"
    assert_select ".tt-post-confirm-body", "投稿確認 テキスト"
    assert_select ".tt-post-confirm-time", "14:27 Today"
  end
end
