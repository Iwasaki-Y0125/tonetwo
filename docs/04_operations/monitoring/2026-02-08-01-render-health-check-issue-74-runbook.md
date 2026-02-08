# Issue #74 死活監視（Render Health Check）実施手順

## 目的
- サービスが停止していないことを、外部からのHTTP 200で継続確認できる状態にする。
- ヘルスチェック失敗時に、Render上で異常検知できる運用手順を明文化する。

## 結論
- ToneTwo は Rails 標準の `/up` をヘルスチェックエンドポイントとして利用する。
- Render Web Service の `Health Check Path` は `/up` を設定する。
- 仮公開時の Basic 認証や Host 制限が有効でも、`/up` は疎通を維持する実装になっている。

## 事前確認（根拠）
### ローカル根拠
- `config/routes.rb`
  - `get "up" => "rails/health#show"` が定義済み。
- `config/environments/production.rb`
  - `config.host_authorization` で `/up` を除外。
- `lib/preview_access_control.rb`
  - Basic 認証適用中でも `HEALTHCHECK_PATH = "/up"` は除外。
- `docs/04_operations/deploy/00_deploy_runbook.md`
  - Render 側設定値として `Health Check Path: /up` を採用済み。
- `README.md`
  - 技術スタックで本番デプロイ先を Render として明記。

### 公式一次ソース
- Render Docs: Health Checks
  - https://render.com/docs/health-checks
- Rails Guides: Routing from the Outside In
  - https://guides.rubyonrails.org/routing.html

## Issue #74 対応方針（タスク対応）
- `RenderのHealth Checkを設定`
  - Render の Web Service に `/up` を設定する。
- `/healthz などヘルスチェック用エンドポイントを用意`
  - 現状は Rails 標準の `/up` を採用し、追加エンドポイントは作らない（運用を単純化）。
- `監視が失敗した場合の挙動（再起動/通知）を確認`
  - Render Dashboard の Health / Event / Logs で失敗検知が見えることを確認する。

## 実作業手順
1. ローカル実装を確認する。
   - `bin/rails routes | rg 'rails_health_check|up'`
   - `rg -n 'HEALTHCHECK_PATH|host_authorization|/up' config lib`
2. Render Dashboard の対象 Web Service を開く。
3. `Settings` で `Health Check Path` を `/up` に設定（未設定なら追加、相違があれば修正）。
4. `Environment` で仮公開設定を使う場合は次を確認する。
   - `PREVIEW_BASIC_AUTH_USER` / `PREVIEW_BASIC_AUTH_PASSWORD` が有効でも `/up` が除外される実装であること。
5. デプロイ後に外形確認する。
   - `curl -i https://www.tonetwo.net/up`
   - 期待値: `HTTP/2 200`（または `HTTP/1.1 200`）
6. Render Dashboard で監視状態を確認する。
   - `Events` でデプロイ失敗や再起動ループの兆候が連発していないこと。
   - `Logs`（Runtime）に継続的な異常（`failed` / `exception` / `timeout` など）が出ていないこと。

## 障害時の確認手順（運用）
1. `/up` が 200 で返るかをまず確認する。
2. 200 でない場合は Render Runtime Logs を確認し、直近の例外を特定する。
3. `APP_ALLOWED_HOSTS` の設定値と公開ドメインの不一致がないか確認する。
4. 仮公開中は `PREVIEW_BASIC_AUTH_*` を見直し、`/up` 以外への制限が意図どおりか確認する。

## 受け入れ条件（Definition of Done）
- 外部から `https://www.tonetwo.net/up` にアクセスして 200 を定期確認できる。
- Render Dashboard 上で Health Check 設定値（`/up`）と異常兆候（Events/Logs）を確認できる。

## 参考
- `docs/04_operations/monitoring/00_initial_monitoring.md`
- `docs/04_operations/deploy/00_deploy_runbook.md`
- `docs/04_operations/deploy/2026-02-06-02-mvp-release-deploy-checklist.md`
