class TimelineController < ApplicationController
  # 初回表示は20件、21件目があれば「次ページあり」と判定する。
  PER_PAGE = 20

  def index
    # 「今は全体タブがアクティブ」というビュー向けの状態フラグ
    @active_tab = :all
    # タイムラインに必要な投稿データを取得してインスタンス変数へセットする。
    load_feed!

    # _next_frame.html.erb からのturbo_frameでリクエストされてるかチェック
    return unless turbo_frame_request?

    # 次ページのturbo_frameリクエストの場合は、部分テンプレートを返す。
    render partial: "timeline/feed_chunk",
           locals: { posts: @posts, has_next: @has_next, next_path: @next_path }
  end

  def similar
    # Issue #19時点ではUI先行のため、取得ロジックは全体TLと共通にしている。
    # todo: おすすめTLのアルゴリズムができたら、ここを分岐させる。
    @active_tab = :similar
    load_feed!

    if turbo_frame_request?
      render partial: "timeline/feed_chunk",
             locals: { posts: @posts, has_next: @has_next, next_path: @next_path }
    else
      render :index
    end
  end

  private

  def load_feed!
    # 投稿フォームは初回のみ。無限スクロールのレスポンスには含めない。
    @post = Post.new unless turbo_frame_request?

    # app/services/posts/cursor_paginator.rb を呼び出して、投稿のページネーションを行う。
    # created_at降順 + id降順を固定。同時刻投稿でも順序がぶれないようにする。
    result = Posts::CursorPaginator.call(
      # タイムライン全体の投稿を対象にする（実際のpostが入っているわけではなく、クエリのための範囲指定の指示だけがはいっているイメージ。なので、処理重くならない）
      scope: Post.order(created_at: :desc, id: :desc),
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
end
