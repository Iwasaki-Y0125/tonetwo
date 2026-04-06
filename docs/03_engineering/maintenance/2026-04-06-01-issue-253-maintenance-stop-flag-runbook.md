# Issue #253 DBメンテナンス時の全停止フラグ 実装手順

## 目的
- DBメンテナンス中に、利用者へ案内を表示しつつ、アプリ本体機能を安全に停止できる状態を作る。
- 監視用エンドポイント `/up` は停止対象から除外し、運用監視を継続できる状態を維持する。

## 事前確認（根拠）
### ローカル一次情報
- [README.md](../../../README.md)
  - 開発/本番の前提（Rails 8, PostgreSQL, Render）
- [Gemfile.lock](../../../Gemfile.lock)
  - `rails (8.1.3)` を利用中
- [config/routes.rb](../../../config/routes.rb)
  - `get "up" => "rails/health#show"` が定義済み
- [app/controllers/application_controller.rb](../../../app/controllers/application_controller.rb)
  - 全コントローラで `Authentication` concern を利用
- [app/controllers/concerns/authentication.rb](../../../app/controllers/concerns/authentication.rb)
  - デフォルトで `before_action :require_authentication`
- [config/environments/production.rb](../../../config/environments/production.rb)
  - `config.silence_healthcheck_path = "/up"`
  - `config.host_authorization` で `/up` を除外
- [config/initializers/rack_attack.rb](../../../config/initializers/rack_attack.rb)
  - `/up` を制限対象から除外する実装あり
- [docs/04_operations/monitoring/2026-02-08-01-render-health-check-issue-74-runbook.md](../../../docs/04_operations/monitoring/2026-02-08-01-render-health-check-issue-74-runbook.md)
  - 監視は `/up` を利用する方針
- [public](../../../public)
  - 4xx/5xx静的ページはあるが、メンテナンス専用ページは未配置

### 公式一次ソース（Web）
- Rails Guides（Rails 8.0）Action Controller Overview
  - Built-in Health Check Endpoint: `/up` は 200/500 返却、必要に応じて独自ヘルスチェックへ差し替え可能
  - <https://guides.rubyonrails.org/v8.0.0/action_controller_overview.html#built-in-health-check-endpoint>
- RFC 9110（HTTP Semantics）
  - 503 は「一時的過負荷または計画メンテナンス」を意味する
  - <https://www.rfc-editor.org/rfc/rfc9110#section-15.6.4>

## 実装方針
- 停止スイッチは `MAINTENANCE_MODE` が環境変数に設定されているかで判定する。
- 停止判定は `ApplicationController` の `prepend_before_action` で行う。
- 停止中は原則 503 を返す。
- 監視維持のため `/up` は常に通す。
- `robots.txt` やアセット配信など、運用上必要な静的ファイルは通す（最低限 `/assets/`, `/favicon.ico`, `/robots.txt` を許可対象に含める）。
- 利用者向け表示は ERB で実装する（[app/views/layouts/maintenance.html.erb](../../../app/views/layouts/maintenance.html.erb)）。
- 専用レイアウトを [app/views/layouts/maintenance.html.erb](../../../app/views/layouts/maintenance.html.erb) に用意し、`authenticated?` など DB/セッションに触れる処理を避ける。

## 実装手順
1. `MaintenanceMode` concern を追加する。
- 追加ファイル候補: [app/controllers/concerns/maintenance_mode.rb](../../../app/controllers/concerns/maintenance_mode.rb)
- 役割:
  - `MAINTENANCE_MODE` が無効なら何もしない
  - 有効時は許可パスを除き 503 + ERB で返却

2. `ApplicationController` に `MaintenanceMode` を適用する。
- 編集対象: [app/controllers/application_controller.rb](../../../app/controllers/application_controller.rb)
- 方式: `include MaintenanceMode` + `prepend_before_action :enforce_maintenance_mode`

3. メンテナンス画面（レイアウト内完結）を追加する。
  - [app/views/layouts/maintenance.html.erb](../../../app/views/layouts/maintenance.html.erb)
- 記載内容:
  - 「現在、定期メンテナンス中です。」
  - 「メンテナンスは4/9 13:30 ~ 15:00を予定しています。」
- `ApplicationController` の `enforce_maintenance_mode` で `template: "layouts/maintenance"`, `layout: false` を明示し、`authenticated?` を呼ばないレイアウトにする。

4. `/up` 非停止の保証をテストで固定する。
- 追加テスト候補: [test/integration/maintenance_mode_test.rb](../../../test/integration/maintenance_mode_test.rb)
- 確認項目:
  - `MAINTENANCE_MODE` を設定して `GET /up` は 200
  - `MAINTENANCE_MODE` を設定して `GET /timeline` は 503
  - `MAINTENANCE_MODE` 未設定では通常動作

5. 運用手順（Render）を docs 化して更新する。
- メンテ開始:
  - Render の対象 Web Service の `Environment` に `MAINTENANCE_MODE` を追加する
  - `Manual Deploy` を実行して反映する
- メンテ終了:
  - `MAINTENANCE_MODE` を削除する
  - `Manual Deploy` を実行して反映する
- 監視確認:
  - `/up` が200のままか
  - 主要ページが503であるか

## 受け入れ条件（Definition of Done）
- `MAINTENANCE_MODE` が設定されている間、アプリ主要機能（ログイン・主要画面・投稿導線）へ到達できず、利用者にはメンテナンス画面が返る。
- レスポンスコードが 503 である。
- `/up` は200を返し続ける。
- テストで上記挙動を固定できている。
- 運用手順（開始・終了・確認）が docs で参照可能。

## 作業チェックリスト（Issue TODO対応）
- [x] 現在の認証・セッション・主要機能がDB停止で影響を受ける範囲を整理する
- [x] メンテナンス中にアプリ全体を停止する方式を決める
- [x] 環境変数でON/OFFできるメンテナンスフラグを実装する
- [x] メンテナンス中に表示する画面文言と挙動を実装する
- [x] 監視エンドポイント `/up` の扱い方針を確定して実装する
- [x] メンテナンス開始前後の運用手順を整備する

## 検証コマンド（Docker/Make優先）
1. テスト環境で総合確認
```bash
make test-all
```

2. 追加したテストのみ確認
```bash
make test-one t="test/integration/maintenance_mode_test.rb"
```

## 備考
- `Retry-After` は今回は付与しない。停止時間が長く、クライアント側で待機・再試行を前提にしない運用方針のため。
- `MAINTENANCE_MODE` は値の内容ではなく存在で判定する。値のタイポで無効になる事故を避けるため。
- メンテ終了時は `MAINTENANCE_MODE` を削除する運用とする。
