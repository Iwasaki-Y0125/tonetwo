require "test_helper"

class TimelineFlowTest < ActionDispatch::IntegrationTest
  test "未ログインユーザーはタイムラインへアクセスできない" do
    get timeline_path

    assert_redirected_to new_session_path
  end

  test "全体TLは新しい投稿順に表示される" do
    user = users(:one)
    sign_in_as(user)

    older_post = user.posts.create!(body: "全体TLの古い投稿")
    newer_post = user.posts.create!(body: "全体TLの新しい投稿")

    get timeline_path

    assert_response :success
    assert_includes @response.body, "role=\"tablist\""
    assert_includes @response.body, "全体"
    assert_includes @response.body, "おすすめ"
    assert_includes @response.body, "投稿"
    assert_includes @response.body, "今どんな感じ？"
    assert_includes @response.body, "data-post-body-length-target=\"message\""
    assert_operator @response.body.index(newer_post.body), :<, @response.body.index(older_post.body)
  end

  test "投稿が多いときは次ページ読み込み用のlazy frameを表示する" do
    user = users(:one)
    sign_in_as(user)

    22.times { |i| user.posts.create!(body: "TL投稿#{i}") }

    get timeline_path

    assert_response :success
    assert_includes @response.body, "id=\"timeline_next\""
    assert_includes @response.body, "loading=\"lazy\""
    assert_includes @response.body, "before_created_at="
    assert_includes @response.body, "before_id="
  end

  test "cursor付きアクセスで次ページの投稿を返す" do
    user = users(:one)
    sign_in_as(user)

    older_post = user.posts.create!(body: "cursor older")
    cursor_post = user.posts.create!(body: "cursor middle")
    newer_post = user.posts.create!(body: "cursor newer")

    get timeline_path, params: { before_created_at: cursor_post.created_at.iso8601(6), before_id: cursor_post.id },
                       headers: { "Turbo-Frame" => "timeline_next" }

    assert_response :success
    assert_not_includes @response.body, newer_post.body
    assert_not_includes @response.body, cursor_post.body
    assert_includes @response.body, older_post.body
  end

  test "おすすめTLは画面を表示できる(UIのみ)" do
    sign_in_as(users(:one))

    get similar_timeline_path

    assert_response :success
    assert_includes @response.body, "全体"
    assert_includes @response.body, "おすすめ"
    assert_includes @response.body, "投稿"
  end

  test "タイムライン上で自分の投稿は詳細ページへのリンクになる" do
    user = users(:one)
    other_user = users(:two)
    sign_in_as(user)

    own_post = user.posts.create!(body: "自分のTL投稿")
    other_post = other_user.posts.create!(body: "他人のTL投稿")

    get timeline_path

    assert_response :success
    assert_select "a[href='#{my_post_path(own_post)}']", text: /自分のTL投稿/
    assert_select "a[href='#{my_post_path(other_post)}']", count: 0
  end
end
