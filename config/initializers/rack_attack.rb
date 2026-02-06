class Rack::Attack
  # 本番のみ有効化（必要に応じて調整）
  Rack::Attack.enabled = Rails.env.production?

  # TODO(deploy後): Render/Cloudflare経由の本番で req.ip が期待どおりか検証し、必要ならしきい値/プロキシ設定を調整する
  # 1分あたりのリクエスト数をIPごとに制限（仮値）
  throttle("req/ip", limit: 120, period: 1.minute) do |req|
    req.ip
  end

  # Basic認証ヘッダ付きリクエストだけを制限対象にする（仮公開向け）
  throttle("basic_auth/ip", limit: 20, period: 1.minute) do |req|
    req.ip if req.path != "/up" && req.get_header("HTTP_AUTHORIZATION").present?
  end

  # 429応答
  self.throttled_responder = lambda do |_env|
    [429, { "Content-Type" => "text/plain" }, ["Too Many Requests"]]
  end
end
