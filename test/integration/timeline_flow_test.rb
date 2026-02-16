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

  test "おすすめTLは直近投稿なしメッセージを表示する" do
    user = build_user(email: "similar-none@example.com")
    sign_in_as(user)

    get similar_timeline_path

    assert_response :success
    assert_includes @response.body, "※直近の投稿がありません。"
  end

  test "おすすめTLは解析中メッセージを表示する" do
    user = build_user(email: "similar-analyzing@example.com")
    sign_in_as(user)
    user.posts.create!(body: "解析中", created_at: Time.current)

    get similar_timeline_path

    assert_response :success
    assert_includes @response.body, "※おすすめを解析中です。反映までしばらくお待ちください。"
    assert_includes @response.body, "data-controller=\"similar-feed-poll\""
    assert_includes @response.body, "data-similar-feed-poll-enabled-value=\"true\""
  end

  test "おすすめTLはtimeline_feedフレーム要求でfeed部分を返す" do
    user = build_user(email: "similar-feed-frame@example.com")
    sign_in_as(user)
    user.posts.create!(body: "解析中", created_at: Time.current)

    get similar_timeline_path, headers: { "Turbo-Frame" => "timeline_feed" }

    assert_response :success
    assert_includes @response.body, "id=\"timeline_feed\""
    assert_not_includes @response.body, "<main"
  end

  test "おすすめTLは解析済みseedなしメッセージを表示する" do
    user = build_user(email: "similar-no-seed@example.com")
    sign_in_as(user)
    user.posts.create!(body: "seedなし", sentiment_label: "pos", sentiment_score: 0.2, created_at: Time.current)

    get similar_timeline_path

    assert_response :success
    assert_includes @response.body, "おすすめを作成できません。"
  end

  test "おすすめTLは新着順でページングできる" do
    me = build_user(email: "similar-me@example.com")
    other = build_user(email: "similar-other@example.com")
    sign_in_as(me)

    seed_term = Term.create!(term: "読書")
    seed_post = me.posts.create!(body: "読書が好き", sentiment_label: "pos", sentiment_score: 0.4, created_at: Time.current - 10.minutes)
    PostTerm.create!(post: seed_post, term: seed_term)

    candidates = []
    22.times do |i|
      post =
        other.posts.create!(
          body: "候補投稿#{i}",
          sentiment_label: "pos",
          sentiment_score: 0.2,
          created_at: Time.current - i.minutes
        )
      PostTerm.create!(post: post, term: seed_term)
      candidates << post
    end

    expected_ids = candidates.sort_by { |post| [ post.created_at, post.id ] }.reverse.map(&:id)
    first_page_last_id = expected_ids[19]
    first_page_last = Post.find(first_page_last_id)

    get similar_timeline_path

    assert_response :success
    assert_includes @response.body, "id=\"timeline_next\""
    assert_includes @response.body, "候補投稿0"
    assert_not_includes @response.body, "候補投稿21"

    get similar_timeline_path,
        params: { before_created_at: first_page_last.created_at.iso8601(6), before_id: first_page_last.id },
        headers: { "Turbo-Frame" => "timeline_next" }

    assert_response :success
    assert_includes @response.body, "候補投稿20"
    assert_includes @response.body, "候補投稿21"
    assert_not_includes @response.body, "候補投稿0"
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

  private

  def build_user(email:)
    password = "password12345"

    User.create!(
      email_address: email,
      password: password,
      password_confirmation: password,
      terms_agreed: "1"
    )
  end
end
