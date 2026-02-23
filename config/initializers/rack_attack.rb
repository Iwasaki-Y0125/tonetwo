class Rack::Attack
  # 本番のみ有効化。切り分け時は RACK_ATTACK_ENABLED=0 で一時停止できる。
  Rack::Attack.enabled = Rails.env.production? && ENV.fetch("RACK_ATTACK_ENABLED", "1") == "1"

  # Cloudflare経由の本番では、接続元プロキシIPではなく利用者IPを優先して使う。
  # 前提: Render側でorigin直アクセスを遮断済みのため、CF-Connecting-IPを信頼する運用。
  # もし直アクセス許可へ変更する場合は、この実装を見直すこと。
  def self.client_ip(req)
    req.get_header("HTTP_CF_CONNECTING_IP").presence || req.ip
  end

  # 未ログイン時の全体アクセスだけを粗く抑止する。
  # ログイン後の通常閲覧は、個別エンドポイントの制限に任せる。
  throttle("req/ip", limit: 240, period: 1.minute) do |req|
    next if req.path == "/up"
    next if req.path.start_with?("/assets")
    next if req.path == "/favicon.ico"
    next if req.cookies["session_id"].present?

    client_ip(req)
  end

  # # Basic認証ヘッダ付きリクエストだけを制限対象にする（仮公開向け）
  # throttle("basic_auth/ip", limit: 20, period: 1.minute) do |req|
  #   client_ip(req) if req.path != "/up" && req.get_header("HTTP_AUTHORIZATION").present?
  # end

  # 役割分担:
  # - Rack::Attack はミドルウェア層で粗く遮断（429）
  # - Controller 側 rate_limit は UX を保った制御（主にリダイレクト）
  # 閾値は同一にせず、層ごとに分離して運用する。
  throttle("auth/session_create/ip", limit: 20, period: 1.minute) do |req|
    client_ip(req) if req.post? && req.path == "/session"
  end

  throttle("auth/sign_up_create/ip", limit: 20, period: 1.minute) do |req|
    client_ip(req) if req.post? && req.path == "/sign_up"
  end

  throttle("posts/create/ip", limit: 20, period: 1.minute) do |req|
    client_ip(req) if req.post? && req.path == "/posts"
  end

  throttle("posts/chat_create/ip", limit: 20, period: 1.minute) do |req|
    client_ip(req) if req.post? && req.path.match?(%r{\A/posts/\d+/chat\z})
  end

  throttle("chats/messages_create/ip", limit: 20, period: 1.minute) do |req|
    client_ip(req) if req.post? && req.path.match?(%r{\A/chats/\d+/messages\z})
  end

  # Rack::Attackで弾いたときに、監視イベントを記録して429を返す処理
  def self.throttled_response(request)
    ActiveSupport::Notifications.instrument("security.throttle", throttled_payload(request))
    [ 429, { "Content-Type" => "text/plain" }, [ "429 Too Many Requests" ] ]
  end

  def self.throttled_payload(request)
    {
      layer: "rack_attack",
      rule: request.env["rack.attack.matched"],
      status: 429,
      method: request.request_method,
      path: request.path
    }
  end
  private_class_method :throttled_payload

  self.throttled_responder = method(:throttled_response)
end
