class PostsController < ApplicationController
  rate_limit to: 5, within: 3.minutes, only: :create,
             with: -> { handle_create_rate_limit }

  def new
    @post = Post.new
  end

  def create
    @post = Current.user.posts.new(post_params)

    if @post.save
      redirect_to timeline_path, notice: "投稿しました。"
    elsif @post.support_required?
      redirect_to support_page_path, notice: Post::SUPPORT_MESSAGE
    else
      flash.now[:alert] = Post::PROHIBIT_MESSAGE if @post.prohibit_hit?
      render :new, status: :unprocessable_entity
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

    redirect_to new_post_path, alert: "投稿回数が上限に達しました。時間をおいて再度お試しください。"
  end

  def post_params
    params.require(:post).permit(:body)
  end
end
