module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    # 未ログインならログイン画面へ送る
    def require_authentication
      resume_session || request_authentication
    end

    # 1リクエスト中は Current.session を再利用し、なければ cookie から復元する
    def resume_session
      Current.session ||= find_session_by_cookie
    end

    # cookie の session_id からセッションを復元し、期限切れなら破棄する
    def find_session_by_cookie
      return unless cookies.signed[:session_id]

      session = Session.find_by(id: cookies.signed[:session_id])
      return unless session

      if session_expired?(session)
        session.destroy
        cookies.delete(:session_id)
        return
      end

      session.touch
      session
    end

    # 元のアクセス先を保持してログイン画面へリダイレクトする
    def request_authentication
      session[:return_to_after_authenticating] = normalize_return_to_path(request.fullpath)
      redirect_to new_session_path
    end

    # ログイン後は元の遷移先へ、なければ root に戻す
    def after_authentication_url
      normalize_return_to_path(session.delete(:return_to_after_authenticating))
    end

    # DBセッション作成と署名付きcookie発行を同時に行う
    def start_new_session_for(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed[:session_id] = {
          value: session.id,
          httponly: true,
          same_site: :lax,   # CSRF対策:クロスサイトでPOSTは送信されない
          secure: Rails.env.production?,
          expires: SessionPolicy::ABSOLUTE_TIMEOUT.from_now
        }
      end
    end

    # 明示ログアウト時にDBセッションとcookieを削除する
    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
    end

    # 7日アイドル or 30日絶対期限のどちらかを超えたら失効
    def session_expired?(session)
      session.updated_at < SessionPolicy::IDLE_TIMEOUT.ago || session.created_at < SessionPolicy::ABSOLUTE_TIMEOUT.ago
    end

    # 外部URLや不正値は受け入れず、同一オリジンの相対パスのみ許可する
    def normalize_return_to_path(path)
      return root_path unless path.is_a?(String)
      return root_path unless path.start_with?("/")
      return root_path if path.start_with?("//")

      path
    end
end
