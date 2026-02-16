require "test_helper"

module Posts
  class SimilarTimelineQueryTest < ActiveSupport::TestCase
    test "一致条件に合う他ユーザー投稿を新着順で返す" do
      user = users(:one)
      other = users(:two)
      term = Term.create!(term: "映画")
      now = Time.zone.parse("2026-02-16 10:00:00")

      recent_seed_post =
        Post.create!(
          user: user,
          body: "映画が好き",
          sentiment_label: "pos",
          sentiment_score: 0.4,
          created_at: now - 2.hours
        )
      PostTerm.create!(post: recent_seed_post, term: term)

      newer_candidate =
        Post.create!(
          user: other,
          body: "映画は最高",
          sentiment_label: "pos",
          sentiment_score: 0.8,
          created_at: now - 20.minutes
        )
      PostTerm.create!(post: newer_candidate, term: term)

      older_candidate =
        Post.create!(
          user: other,
          body: "映画みた",
          sentiment_label: "pos",
          sentiment_score: 0.5,
          created_at: now - 3.hours
        )
      PostTerm.create!(post: older_candidate, term: term)

      excluded_self =
        Post.create!(
          user: user,
          body: "自分の投稿は除外",
          sentiment_label: "pos",
          sentiment_score: 0.3,
          created_at: now - 10.minutes
        )
      PostTerm.create!(post: excluded_self, term: term)

      excluded_sentiment =
        Post.create!(
          user: other,
          body: "映画はしんどい",
          sentiment_label: "neg",
          sentiment_score: -0.4,
          created_at: now - 15.minutes
        )
      PostTerm.create!(post: excluded_sentiment, term: term)

      excluded_old =
        Post.create!(
          user: other,
          body: "古い映画投稿",
          sentiment_label: "pos",
          sentiment_score: 0.1,
          created_at: now - 8.days
        )
      PostTerm.create!(post: excluded_old, term: term)

      result = SimilarTimelineQuery.call(user: user, now: now)

      assert_equal :ready, result.state
      assert_equal [ newer_candidate.id, older_candidate.id ], result.scope.pluck(:id)
    end

    test "直近投稿がない場合は no_recent_posts を返す" do
      user = build_user(email: "no_recent@example.com")

      result = SimilarTimelineQuery.call(user: user)

      assert_equal :no_recent_posts, result.state
      assert_empty result.scope
    end

    test "直近投稿に sentiment_label 未確定があれば analyzing を返す" do
      user = users(:one)

      Post.create!(
        user: user,
        body: "解析待ちの投稿",
        sentiment_label: nil,
        sentiment_score: nil,
        created_at: Time.current
      )

      result = SimilarTimelineQuery.call(user: user)

      assert_equal :analyzing, result.state
      assert_empty result.scope
    end

    test "解析済みで seed が作れない場合は no_seed を返す" do
      user = build_user(email: "no_seed@example.com")

      Post.create!(
        user: user,
        body: "名詞なし想定",
        sentiment_label: "pos",
        sentiment_score: 0.2,
        created_at: Time.current
      )

      result = SimilarTimelineQuery.call(user: user)

      assert_equal :no_seed, result.state
      assert_empty result.scope
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
end
