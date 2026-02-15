require "test_helper"

class MyPostsFlowTest < ActionDispatch::IntegrationTest
  test "未ログインユーザーは自分の投稿一覧へアクセスできない" do
    get my_posts_path

    assert_redirected_to new_session_path
  end

  test "ログイン済みユーザーは自分の投稿だけを新しい順で表示できる" do
    user = users(:one)
    other_user = users(:two)
    sign_in_as(user)

    older_post = user.posts.create!(body: "自分の古い投稿")
    newer_post = user.posts.create!(body: "自分の新しい投稿")
    other_user.posts.create!(body: "他人の投稿")

    get my_posts_path

    assert_response :success
    assert_includes @response.body, newer_post.body
    assert_includes @response.body, older_post.body
    assert_not_includes @response.body, "他人の投稿"
    assert_operator @response.body.index(newer_post.body), :<, @response.body.index(older_post.body)
  end

  test "ログイン済みユーザーは自分の投稿詳細を表示できる" do
    sign_in_as(users(:one))
    own_post = posts(:one)

    get my_post_path(own_post)

    assert_response :success
    assert_includes @response.body, own_post.body
  end

  test "ログイン済みユーザーでも他人の投稿詳細は表示できない" do
    sign_in_as(users(:one))
    others_post = posts(:two)

    get my_post_path(others_post)

    assert_response :not_found
  end
end
