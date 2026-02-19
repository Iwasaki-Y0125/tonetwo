class PostsController < ApplicationController
  rate_limit to: 5, within: 3.minutes, only: :create,
             with: -> { handle_create_rate_limit }

  # TODO(UI): 将来的に個別投稿ページを再導入する場合は有効化する。
  # def new
  #   @post = Post.new
  # end

  def create
    @post = Current.user.posts.new(post_params)

    if @post.save
      redirect_to similar_timeline_path, notice: "投稿しました。"
    elsif @post.support_required?
      redirect_to support_page_path, notice: Post::SUPPORT_MESSAGE
    else
      # 投稿失敗時は、投稿内容とエラーメッセージをフラッシュに積んで、遷移元に戻す。
      if request.referer.present?
        redirect_back fallback_location: similar_timeline_path, flash: compose_error_flash(@post)
        return
      end
      # リファラーがない場合も、全体TLに戻してエラーを表示する。
      redirect_to timeline_path, flash: compose_error_flash(@post)
    end
  end

  private

  # 投稿連投を抑止し、制限発火を観測できるようにする。
  def handle_create_rate_limit
    ActiveSupport::Notifications.instrument(
      "security.throttle",
      layer: "rails_rate_limit",
      rule: "posts#create",
      status: 302,
      method: request.request_method,
      path: request.path
    )

    redirect_to similar_timeline_path, alert: "投稿回数が上限に達しました。時間をおいて再度お試しください。"
  end

  # 投稿失敗時に、エラーメッセージと投稿内容をリダイレクト先に渡すためのヘルパーメソッド
  def compose_error_flash(post)
    {
      compose_errors: post.errors.messages.values.flatten.uniq,
      # flash経由の保持データを最小化するため、本文は最大140文字までに制限する。
      compose_body: post.body.to_s.first(140)
    }
  end

  # ストロングパラメータ
  def post_params
    params.require(:post).permit(:body)
  end
end
