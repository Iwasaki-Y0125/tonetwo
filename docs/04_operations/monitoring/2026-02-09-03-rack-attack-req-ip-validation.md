# Rack::Attack `req.ip` 検証メモ（Render + Cloudflare）

## 目的
- 本番経路（Render + Cloudflare）で、Rack::Attack のIP判定キーが利用者IPを正しく見ているか確認する。
- 誤ってCloudflare側IPでレート制限しないようにする。

## 結論（2026-02-09時点）
- 本番ログの `Started ... for ...` には `172.69.x.x` / `172.70.x.x` / `162.158.x.x` が出ており、利用者IPではなくCloudflare側IPを拾っている可能性が高い。
- `config/initializers/rack_attack.rb` を修正し、Rack::Attack の判定キーを `CF-Connecting-IP` 優先に統一した。
- `throttle("req/ip")` は試行値として `240/min` に設定した。運用中の429エラーの件数次第で調整。

## 事実ベースの確認ログ
- 検証アクセス:
  - `GET /session/new?ipcheck=iptest-20260209-2355`
- Renderログ:
  - `Started GET "/session/new?ipcheck=iptest-20260209-2355" for 172.69.165.64 ...`
  - フォント取得でも `162.158.162.136` / `172.69.165.54` が記録
- 判定:
  - Cloudflare配下のエッジIP帯が見えており、`req.ip` のみをキーにすると利用者単位の制限にならないリスクがある。

## 実施したコード修正
- 対象: `config/initializers/rack_attack.rb`
- 変更内容:
  - `Rack::Attack.client_ip(req)` を追加
  - `req/ip` と `basic_auth/ip` の両throttleで `client_ip(req)` を利用
  - `client_ip(req)` は `HTTP_CF_CONNECTING_IP` を優先し、未設定時は `req.ip` にフォールバック

```ruby
def self.client_ip(req)
  req.get_header("HTTP_CF_CONNECTING_IP").presence || req.ip
end
```

## 参考にした根拠
### ローカル根拠
- `Gemfile.lock`
  - `rails (8.1.2)`
  - `rack (3.2.4)`
  - `rack-attack (6.8.0)`
- `config/initializers/rack_attack.rb`
  - throttleキーとして `req.ip` を使っていた実装を確認
- `config/environments/production.rb`
  - `trusted_proxies` の明示設定なし

### 公式一次ソース
- Rack::Attack README（`throttle` と instrumentation）
  - https://github.com/rack/rack-attack/blob/6-stable/README.md
- Rails `ActionDispatch::Request#ip` / `ActionDispatch::RemoteIp`
  - https://github.com/rails/rails/tree/v8.1.2/actionpack/lib/action_dispatch

## 手順
1. `rack_attack.rb` で `Rack::Attack.client_ip(req)` に変更
2. `SessionsController#new` に検証用の一時ログを追記する。
3. 本番へデプロイする。
4. `?ipcheck=<token>` 付きで `session/new` にアクセスする。
5. 一時ログで `cf` と `rack_attack_key` と自分のIPアドレスが一致することを確認。
6. 検証用の一時ログを削除する。

## 補足_1 CF-Connecting-IP を使う前提
- クライアントは `CF-Connecting-IP` ヘッダを任意送信できるが、Cloudflare 経由時は Cloudflare が origin へ渡すヘッダを再構成する前提で運用する。
- そのため、`HTTP_CF_CONNECTING_IP` を信頼する場合は「origin（`.onrender.com`）の直接到達を閉じる」ことが必須。
- origin 直アクセスが可能だと、ヘッダ偽装でレート制限回避される余地が残る。
- 実運用では「Cloudflare 経由のみ到達可能」であることを設定とログで証跡化しておく。
- 参考（Cloudflare公式）:
  - https://developers.cloudflare.com/fundamentals/reference/http-request-headers/

## 補足_2 origin 直アクセス遮断の証跡
- 実施日: 2026-02-09
- 実行コマンド:
  - `curl -i https://tonetwo.onrender.com/up`
  - `curl -i https://tonetwo.onrender.com/session/new`
- 結果:
  - いずれも `HTTP/2 404`
  - レスポンスヘッダに `x-render-routing: no-render-subdomain`
- 判定:
  - Renderサブドメイン（`.onrender.com`）は直接ルーティングされておらず、origin 直アクセスは閉じられている。

## 補足_3 ログイン試行制限の方針
- `POST /session` は `SessionsController#create` の `rate_limit` を主担当とする。
- 同一対象を `rack_attack.rb` 側でも重複して絞ると、誤遮断時の原因切り分けが難しくなるため原則避ける。
- `rack_attack.rb` は全体防御（`req/ip`）と Basic認証向け（`basic_auth/ip`）を主目的に運用する。
