module My
  class PostsController < ApplicationController
    PER_PAGE = 20

    def index
      load_feed!

      return unless turbo_frame_request?

      render partial: "my/posts/feed_chunk",
             locals: { posts: @posts, has_next: @has_next, next_path: @next_path }
    end

    def show
      # 他ユーザー投稿の参照を防ぐため、ログイン中ユーザーの関連から検索する。
      @post = Current.user.posts.find(params[:id])
    end

    private

    # created_at降順 + id降順で、同時刻投稿でも順序がぶれないようにする。
    def load_feed!
      result = Posts::CursorPaginator.call(
        scope: Current.user.posts.order(created_at: :desc, id: :desc),
        before_created_at: params[:before_created_at],
        before_id: params[:before_id],
        per_page: PER_PAGE
      )

      @has_next = result.has_next
      @posts = result.posts
      @next_path = build_next_path(result.last_post) if @has_next && result.last_post.present?
    end

    def build_next_path(last_post)
      my_posts_path(before_created_at: last_post.created_at.iso8601(6), before_id: last_post.id)
    end
  end
end
