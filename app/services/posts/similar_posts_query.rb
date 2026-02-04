# app/queries/similar_posts_query.rb
# frozen_string_literal: true

module Posts
  class SimilarPostsQuery
    DEFAULT_SIMILAR_POSTS_LIMIT = 10
    RECENT_DAYS = 30

    def self.call(post_id:, limit: DEFAULT_SIMILAR_POSTS_LIMIT)
      target = Post.select(:id, :sentiment_score).find(post_id)

      # 共通のベース条件（公開・返信可・自分除外・30日以内の投稿）
      scope =
        Post
          .where(visibility: "public", reply_mode: "open")
          .where.not(id: target.id)
          .where("posts.created_at >= ?", RECENT_DAYS.days.ago)

      # ポジネガ振り分け（仕様：0以上=ポジ、0未満=ネガ）
      scope =
        if target.sentiment_score >= 0
          scope.where("posts.sentiment_score >= 0")
        else
          scope.where("posts.sentiment_score < 0")
        end

      # 除外語（私、ここ、今日など）
      excluded_terms = MatchingExcludedTerm.enabled.select(:term)

      term_ids =
        PostTerm
          .joins(:term)
          .where(post_id: target.id)
          .where.not(terms: { term: excluded_terms })
          .distinct
          .pluck(:term_id)

      # 名詞が0語ならフォールバック：同極性の最新投稿
      if term_ids.empty?
        return scope.order(created_at: :desc, id: :desc).limit(limit)
      end

      # 名詞一致（1語以上)
      # 一致する単語数が多い(オーバーラップする）ほど似ているとみなして、
      # overlap→新しい順で並べる。(id: :descは検証時のブレ対策)
      scope
        .joins(:post_terms)
        .where(post_terms: { term_id: term_ids })
        .select("posts.*, COUNT(DISTINCT post_terms.term_id) AS overlap")
        .group("posts.id")
        .order(Arel.sql("COUNT(DISTINCT post_terms.term_id) DESC"))
        .order(created_at: :desc, id: :desc)
        .limit(limit)
    end
  end
end
