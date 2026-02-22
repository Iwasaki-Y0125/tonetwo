class TimelineController < ApplicationController
  # 初回表示は20件、21件目があれば「次ページあり」と判定する。
  PER_PAGE = 20     # 投稿の取得件数
  SIMILAR_POLLING_INTERVAL_MS = 5000  # おすすめTLの解析中状態をポーリングで監視する間隔（ミリ秒）
  SIMILAR_EMPTY_MESSAGES = {
    no_recent_posts: [
      "ここにはあなたの直近の投稿をもとに",
      "ほかユーザーの投稿表示がされます。",
      "",
      "※直近の投稿がありません。"
    ],
    analyzing: [
      "ここにはあなたの直近の投稿をもとに",
      "ほかユーザーの投稿が表示されます。",
      "",
      "※おすすめを解析中です。反映までしばらくお待ちください。"
    ],
    no_seed: [
      "ここにはあなたの直近の投稿をもとに",
      "ほかユーザーの投稿が表示されます。",
      "",
      "※投稿数が少ないため、おすすめを作成できません。"
    ]
  }.freeze

  def index
    # 「今は全体タブがアクティブ」というビュー向けの状態フラグ
    @active_tab = :all
    # タイムラインに必要な投稿データを取得してインスタンス変数へセットする。
    load_feed!

    # turbo frame経由の追加読み込み時は、一覧部分だけ返す。def indexの場合は暗黙的にindexビューが呼ばれるため、return if は不要。
    render_feed_chunk_if_turbo_frame!
  end

  def similar
    # 「今はおすすめタブがアクティブ」というビュー向けの状態フラグ
    @active_tab = :similar
    # タイムラインに必要な投稿データを取得してインスタンス変数へセットする。
    load_feed!
    assign_posted_preview!

    # turbo frame経由の追加読み込み時は、一覧部分だけ返す。（ render :index を明示しているので、return if が必要 ）
    return if render_feed_chunk_if_turbo_frame!
    # 初回にindexと同じビューを使うため明示
    render :index
  end

  private

  def load_feed!
    # 投稿フォームは初回のみ。無限スクロールのレスポンスには含めない。
    @post = Post.new unless turbo_frame_request?

    # app/services/posts/cursor_paginator.rb を呼び出して、投稿のページネーションを行う。
    # created_at降順 + id降順を固定。同時刻投稿でも順序がぶれないようにする。
    result = Posts::CursorPaginator.call(
      # 一覧の取得条件はタブごとに切り替える。
      scope: feed_scope,
      # 次ページの取得に必要なカーソル時刻を前回のリクエストから取得する（初回はnil）
      before_created_at: params[:before_created_at],
      # 次ページの取得に必要なカーソルIDを前回のリクエストから取得する（初回はnil）
      before_id: params[:before_id],
      # PRE_PAGE件ずつ取得する（現在は20件）
      per_page: PER_PAGE
      )

    # Result: Posts::CursorPaginator.call の返り値
    # result.posts: 今回表示する1ページ分の投稿
    # result.has_next: 次ページがあるかのフラグ
    # result.last_post: 次ページカーソル生成の基準になる末尾投稿

    # 取得した投稿データをインスタンス変数へセットする。
    @posts = result.posts
    @has_next = result.has_next
    @next_path = build_next_path(result.last_post) if @has_next && result.last_post.present?
  end

  # 投稿の取得条件を返す。タブごとに条件が異なるため、現在のアクティブタブに応じて切り替える。
  def feed_scope
    # 全体タイムラインは全ユーザーの投稿を取得するスコープを返す。
    return Post.order(created_at: :desc, id: :desc) unless @active_tab == :similar

    # おすすめタイムラインは Posts::SimilarTimelineQuery を呼び出して、状態と投稿のスコープを取得する。
    similar_result = Posts::SimilarTimelineQuery.call(user: Current.user)
    @similar_state = similar_result.state
    @empty_state_lines = SIMILAR_EMPTY_MESSAGES[@similar_state]
    similar_result.scope
  end

  # turbo frame経由のアクセスかどうかを判定し、turbo frameなら投稿一覧部分のHTMLを返す。通常アクセスなら何もしない。
  def render_feed_chunk_if_turbo_frame!
    return false unless turbo_frame_request?

    # turbo frame経由のアクセスなら、投稿一覧部分のHTMLを返す。
    # どのpartialを使うかは、リクエストヘッダのTurbo-Frameで判断する。
    partial_name = request.headers["Turbo-Frame"] == "timeline_feed" ? "timeline/feed" : "timeline/feed_chunk"
    render partial: partial_name,
           locals: { posts: @posts, has_next: @has_next, next_path: @next_path, active_tab: @active_tab,
                     #  おすすめTL用の状態表示に必要なローカル変数も渡す
                     empty_state_lines: @empty_state_lines, similar_state: @similar_state,
                     #  おすすめTLの解析中状態をポーリングで監視するためのインターバル値も渡す
                     similar_polling_interval_ms: SIMILAR_POLLING_INTERVAL_MS }
    true
  end

  # 次ページのURLを生成する。現在のタブに応じてパスを切り替える。
  def build_next_path(last_post)
    # before_created_at: 今回最後に表示した投稿の時刻
    # before_id: 今回最後に表示した投稿のID
    # cursor_params: 次ページの取得に必要なカーソル情報
    cursor_params = { before_created_at: last_post.created_at.iso8601(6), before_id: last_post.id }

    # どのタブのURLにするか決める
    if @active_tab == :similar
      similar_timeline_path(cursor_params)
    else
      timeline_path(cursor_params)
    end
  end

  # おすすめTL遷移直後のみ、投稿受付確認カード用の情報を取り出す。
  def assign_posted_preview!
    return unless @active_tab == :similar

    posted_preview_post_id = flash[:posted_preview_post_id]
    return if posted_preview_post_id.blank?

    post = Current.user.posts.find_by(id: posted_preview_post_id)
    return if post.blank?

    @posted_preview = build_posted_preview(post)
  end

  # 投稿確認カードで表示する最小情報だけを整形する。
  def build_posted_preview(post)
    posted_at = post.created_at.in_time_zone("Asia/Tokyo")
    posted_at_label = posted_at.today? ? posted_at.strftime("%H:%M Today") : posted_at.strftime("%Y/%m/%d %H:%M")

    {
      body: post.body.to_s.squish.first(140),
      posted_at_label: posted_at_label
    }
  end
end
