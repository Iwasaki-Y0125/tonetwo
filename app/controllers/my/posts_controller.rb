module My
  class PostsController < ApplicationController
    def index
      # 一覧の先頭に最新投稿を出すため、作成日時の降順で取得する。
      @posts = Current.user.posts.order(created_at: :desc)
    end

    def show
      # 他ユーザー投稿の参照を防ぐため、ログイン中ユーザーの関連から検索する。
      @post = Current.user.posts.find(params[:id])
    end
  end
end
