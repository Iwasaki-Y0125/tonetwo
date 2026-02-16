# frozen_string_literal: true

module Posts
  class SimilarTimelineQuery
    RECENT_DAYS = 7            # 直近何日分の投稿を対象にするか
    RECENT_POSTS_LIMIT = 10    # 直近投稿のうち、何件までをseed候補とするか

    # Result = Struct.new(...):　型定義
    # scope: おすすめTLに表示する投稿のスコープ
    # state: おすすめTLの状態（:ready, :no_recent_posts, :analyzing, :no_seed）
    # keyword_init: true キーワード引数で渡すためのオプション
    Result = Struct.new(:scope, :state, keyword_init: true)

    # ユーザーのおすすめTLに表示する投稿のスコープを返す。
    def self.call(user:, now: Time.current)
      # おすすめTLの状態を判定するために、まずはユーザーの直近投稿を取得する。直近投稿の期間は RECENT_DAYS で定義。
      window_from = now - RECENT_DAYS.days  # 7日前の時刻（下限日時 = now - 7日）
      recent_posts = recent_posts_for(user_id: user.id, window_from: window_from)

      # 直近投稿がない場合は no_recent_posts を返す。
      # おすすめTLには投稿がないことを知らせるメッセージを表示する。
      return Result.new(scope: Post.none, state: :no_recent_posts) unless recent_posts.exists?

      # 直近投稿に sentiment_label 未確定があれば analyzing を返す。
      # おすすめTLにはおすすめを解析中であることを知らせるメッセージを表示する。
      return Result.new(scope: Post.none, state: :analyzing) if recent_posts.where(sentiment_label: nil).exists?

      # 解析済みで seed が作れない場合は no_seed を返す。
      # おすすめTLには投稿数が少ないためおすすめを作成できないことを知らせるメッセージを表示する。
      seed = seed_for(recent_posts: recent_posts)
      return Result.new(scope: Post.none, state: :no_seed) unless seed.exists?

      # おすすめTLの投稿のスコープを返す。スコープは、直近投稿と同じ用語を含み、かつ同じ感情ラベルの投稿で、ユーザー自身の投稿は除外する。
      Result.new(scope: candidate_scope(user_id: user.id, window_from: window_from, seed: seed), state: :ready)
    end

    # ユーザーの直近投稿を取得する。7日前の時刻（下限日時 = now - 7日）以降の投稿を recent_posts として返す。
    def self.recent_posts_for(user_id:, window_from:)
      Post
        .where(user_id: user_id)
        .where("posts.created_at >= ?", window_from)
    end
    private_class_method :recent_posts_for

    # 直近投稿からおすすめTLのseedを作成する。
    # seedは、直近投稿と同じ用語を含み、かつ同じ感情ラベルの投稿を抽出するための集合。
    def self.seed_for(recent_posts:)
      # recent_posts のうち、sentiment_label が確定しているものを直近投稿のseedとする。
      recent_seed_posts =
        recent_posts
          .where.not(sentiment_label: nil)
          .select(:id, :sentiment_label)
          .order(created_at: :desc, id: :desc)
          .limit(RECENT_POSTS_LIMIT)

      # recent_seed_posts を元に、用語ごとの感情ラベルを取得する。
      PostTerm
        .joins("INNER JOIN (#{recent_seed_posts.to_sql}) recent_posts ON recent_posts.id = post_terms.post_id")
        .select("DISTINCT post_terms.term_id, recent_posts.sentiment_label AS sentiment_label")
    end
    private_class_method :seed_for

    # seedを元に、おすすめTLの投稿のスコープを返す。
    def self.candidate_scope(user_id:, window_from:, seed:)
      # seedの用語と同じ用語を含み、かつ同じ感情ラベルの投稿を抽出する。
      candidates =
        Post
          .joins(:post_terms)
          .joins("INNER JOIN (#{seed.to_sql}) seed ON seed.term_id = post_terms.term_id")
          .where("posts.sentiment_label = seed.sentiment_label")
          .where.not(user_id: user_id)
          .where("posts.created_at >= ?", window_from)

      # 安全に重複を排除するため、投稿IDのみを対象に DISTINCT をかける。
      candidate_ids = candidates.select(:id).distinct

      # candidate_ids を元に、投稿のスコープを返す。
      # スコープは、created_at降順 + id降順で並び替える。
      Post.where(id: candidate_ids).order(created_at: :desc, id: :desc)
    end
    private_class_method :candidate_scope
  end
end
