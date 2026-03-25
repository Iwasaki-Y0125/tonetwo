Rails.application.configure do
  config.content_security_policy do |policy|
    # デフォルトは同一オリジンからのリソースのみ許可
    # fallback 対象の一覧は docs/03_engineering/2026-03-23-01-csp-basics.md を参照
    policy.default_src :self

    # baseタグ自体を禁止して、相対URLの基準書き換えを防ぐ
    # Railsでは基本的に使わないため、使わない前提で閉じる
    policy.base_uri :none

    # フォーム送信先は同一オリジンのみに限定
    policy.form_action :self

    # 他サイトからの iframe 埋め込みを禁止
    policy.frame_ancestors :none

    # 画像は同一オリジンのみ許可
    policy.img_src :self

    # object/embed/applet は読み込み自体を禁止
    policy.object_src :none

    # スクリプトは同一オリジン配信のみ許可
    # importmap 用 nonce をレスポンスヘッダの script-src に載せるためにも必須
    policy.script_src :self
  end

  # importmap が生成する inline script を許可するため、script-src に nonce を付与する。
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]

  # 初回導入は遮断せず、違反の有無を確認できるようにする。
  config.content_security_policy_report_only = true
end
