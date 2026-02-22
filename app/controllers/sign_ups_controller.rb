class SignUpsController < ApplicationController
  unauthenticated_access_only only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { handle_create_rate_limit }

  def new
    @user = User.new
  end

  def create
    @user = User.new(sign_up_params)

    if @user.save
      start_new_session_for(@user)
      redirect_to timeline_path
    else
      # メール重複の詳細エラーメッセージはアカウント列挙攻撃につながるため、
      # ユーザー画面には表示しない
      if @user.errors.where(:email_address).any? { |error| error.type == :taken }
        @user.errors.delete(:email_address)
      end
      flash.now[:alert] = "入力内容を確認してください。"
      render :new, status: :unprocessable_entity
    end
  end

  private

  # UX優先の制限（controller層）で抑止したことを明示的に観測する
  def handle_create_rate_limit
    ActiveSupport::Notifications.instrument(
      "security.throttle",
      layer: "rails_rate_limit",
      rule: "sign_ups#create",
      status: 302,
      method: request.request_method,
      path: request.path
    )

    redirect_to new_sign_up_path, alert: "試行回数が上限に達しました。時間をおいて再度お試しください。"
  end

  def sign_up_params
    params.require(:user).permit(:email_address, :password, :password_confirmation, :terms_agreed)
  end
end
