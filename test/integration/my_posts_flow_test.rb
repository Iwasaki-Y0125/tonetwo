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

  test "投稿が多いときは次ページ読み込み用のlazy frameを表示する" do
    user = users(:one)
    sign_in_as(user)

    22.times { |i| user.posts.create!(body: "自分の投稿#{i}") }

    get my_posts_path

    assert_response :success
    assert_includes @response.body, "id=\"my_posts_next\""
    assert_includes @response.body, "loading=\"lazy\""
    assert_includes @response.body, "before_created_at="
    assert_includes @response.body, "before_id="
  end

  test "cursor付きアクセスで次ページの投稿を返す" do
    user = users(:one)
    sign_in_as(user)

    older_post = user.posts.create!(body: "my older")
    cursor_post = user.posts.create!(body: "my cursor")
    newer_post = user.posts.create!(body: "my newer")

    get my_posts_path, params: { before_created_at: cursor_post.created_at.iso8601(6), before_id: cursor_post.id },
                      headers: { "Turbo-Frame" => "my_posts_next" }

    assert_response :success
    assert_not_includes @response.body, newer_post.body
    assert_not_includes @response.body, cursor_post.body
    assert_includes @response.body, older_post.body
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
