class PasswordsMailer < ApplicationMailer
  # TODO(Auth): MVP時点では未使用（routes未公開）。
  # 本リリースまでにパスワードリセット実装時に利用する。
  def reset(user)
    @user = user
    mail subject: "Reset your password", to: user.email_address
  end
end
