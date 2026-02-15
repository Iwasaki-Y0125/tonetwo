class TimelineController < ApplicationController
  # 初回表示は20件、21件目があれば「次ページあり」と判定する。
  PER_PAGE = 20

  def index
    # 全体タブの表示状態をビューへ渡す。
    @active_tab = :all
    # タイムラインに必要な投稿データを取得してインスタンス変数へセットする。
    load_feed!

    # lazy frame からの追い読み時は一覧差分だけ返し、画面全体は再描画しない。
    return unless turbo_frame_request?

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
    # 投稿フォームは初回HTMLでのみ。無限スクロールのレスポンスには含めない。
    @post = Post.new unless turbo_frame_request?

    # created_at降順 + id降順で、同時刻投稿でも順序がぶれないようにする。
    result = Posts::CursorPaginator.call(
      scope: Post.order(created_at: :desc, id: :desc),
      before_created_at: params[:before_created_at],
      before_id: params[:before_id],
      per_page: PER_PAGE
    )

    @has_next = result.has_next
    @posts = result.posts
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
