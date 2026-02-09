class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "ログイン試行が上限に達しました。3分ほど待ってから再度お試しください。" }

  def new
    # 本番IP検証時のみ、Rack::Attackの判定キーを突き合わせる。
    return unless params[:ipcheck].present?

    Rails.logger.info(
      "[ip-check] token=#{params[:ipcheck]} " \
      "cf=#{request.get_header('HTTP_CF_CONNECTING_IP')} " \
      "rack_attack_key=#{Rack::Attack.client_ip(request)}"
    )
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
end
