class SessionsController < ApplicationController
  unauthenticated_access_only only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { handle_create_rate_limit }

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "メールアドレスまたはパスワードが異なります。"
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end

  private

  # UX優先の制限（controller層）で抑止したことを明示的に観測する
  def handle_create_rate_limit
    ActiveSupport::Notifications.instrument(
      "security.throttle",
      layer: "rails_rate_limit",
      rule: "sessions#create",
      status: 302,
      method: request.request_method,
      path: request.path
    )

    redirect_to new_session_path, alert: "試行回数が上限に達しました。時間をおいて再度お試しください。"
  end
end
