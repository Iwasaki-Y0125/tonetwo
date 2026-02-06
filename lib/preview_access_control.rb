require "digest"

# リリース前のデプロイメント向けに一時的なアクセス制御を適用
# デフォルトでは無効化されており、環境変数が指定された場合のみ有効化されます。
class PreviewAccessControl
  # TODO(MVP公開前): パブリック公開に切り替える場合は、この制限の適用方針を再確認する。
  # - Basic認証を外すなら PREVIEW_BASIC_AUTH_* を未設定にする
  HEALTHCHECK_PATH = "/up".freeze

  def initialize(app, basic_user:, basic_password:)
    @app = app
    @basic_user = basic_user.to_s
    @basic_password = basic_password.to_s
  end

  def call(env)
    req = ActionDispatch::Request.new(env)
    # Render の監視導線は常に通す（ここを塞ぐとヘルスチェックが落ちる）。
    return @app.call(env) if req.path == HEALTHCHECK_PATH
    # Basic認証が有効なときは、認証失敗なら 401 を返す。
    return unauthorized unless basic_auth_ok?(req)

    @app.call(env)
  end

  private

  def basic_auth_ok?(req)
    # 環境変数が未設定なら Basic認証は無効（通過）とする。
    return true unless basic_auth_enabled?

    user, password = ActionController::HttpAuthentication::Basic.user_name_and_password(req)
    return false if user.blank? || password.blank?

    secure_compare(user, @basic_user) && secure_compare(password, @basic_password)
  end

  def basic_auth_enabled?
    @basic_user.present? && @basic_password.present?
  end

  def secure_compare(left, right)
    left_digest = ::Digest::SHA256.hexdigest(left)
    right_digest = ::Digest::SHA256.hexdigest(right)
    ActiveSupport::SecurityUtils.secure_compare(left_digest, right_digest)
  end

  def unauthorized
    headers = {
      "Content-Type" => "text/plain; charset=utf-8",
      "WWW-Authenticate" => %(Basic realm="ToneTwo Preview")
    }
    [ 401, headers, [ "Unauthorized" ] ]
  end
end
