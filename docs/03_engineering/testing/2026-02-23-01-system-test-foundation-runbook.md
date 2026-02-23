# Issue #153 実行ランブック: Systemテスト基盤整備と最小E2E追加

## 目的
- `bin/rails test:system` をローカル/CIで安定実行できる状態を作る。
- 重要導線（認証/投稿/チャット）に最小限のsystemテストを追加し、UI挙動を回帰検知できるようにする。
- request/integration中心の既存方針を維持しつつ、systemテストの担当範囲を明文化する。

## 結論
- このIssueでは「環境整備 -> 最小3導線のsystemテスト追加 -> docs更新」の順で進める。
- systemテストは増やしすぎず、壊れたときの影響が大きい導線に限定する。
- CI runnerは `ubuntu-latest` のままでも、テスト実行は `Dockerfile.dev` + `docker-compose.test.yml` に統一して再現性を担保する。

## ローカル一次情報（このリポジトリの事実）
- `Gemfile.lock`
  - `rails (8.1.2)`
  - `capybara (3.40.0)`
  - `selenium-webdriver (4.41.0)`
- `test/application_system_test_case.rb`
  - `driven_by :selenium, using: :headless_chrome`
- `Makefile`
  - `make test` は `bin/rails test` と `bin/rails test:system` を連続実行する。
- `.github/workflows/ci.yml`
  - 現状は `bin/rails test --exclude '/RackAttackThrottleTest/'` までで、`test:system` は未実行。

## 一次ソース（公式）
- Rails Guides: Testing Rails Applications（System Testing）
  - https://guides.rubyonrails.org/testing.html#system-testing
- Selenium公式: Selenium Manager
  - https://www.selenium.dev/documentation/selenium_manager/
- Selenium公式: Chrome WebDriver
  - https://www.selenium.dev/documentation/webdriver/browsers/chrome/
- GitHub公式: actions/runner-images（`ubuntu-latest` の扱い）
  - https://github.com/actions/runner-images

## 実装方針
### 1. systemテスト実行環境の整備
- Docker（test実行コンテナ）に、Chrome/ChromeDriver実行に必要なブラウザ実行環境を追加する。
- 依存追加時は「aptでブラウザ/driverを導入し、足りない共有ライブラリを `ldd` で特定して補完する」手順を使う。
- コンテナ内で次を通す。
  - `bin/rails test:system`

### 2. CIにsystemテストを組み込む
- `ci.yml` の test jobを `make test` 実行に寄せ、`Dockerfile.dev` ベースで `bin/rails test:system` まで実行する。
- `tmp/screenshots` をartifact保存し、失敗時の調査可能性を確保する。
- artifact保持期間は `retention-days: 1` とし、長期保管を避ける。

### 3. 最小3導線のsystemテストを追加
- 認証導線: ログイン成功/失敗（主要1導線）
- 投稿導線: 投稿作成（主要1導線）
- チャット導線: チャット表示・送信（主要1導線）
- 既存request/integrationテストと責務を重複させず、UI操作と遷移確認に絞る。

## 実装済みsystemテスト（Issue #153）
### 認証
- `test/system/authentication_system_test.rb`
  - 未ログインで `timeline` / `similar_timeline` へ直アクセスした場合にログイン画面へ遷移
  - ログイン失敗 -> 再入力 -> ログイン成功
  - ログイン済みで `new_session_path` / `new_sign_up_path` へアクセスした場合にタイムラインへリダイレクト
- `test/integration/authentication_flow_test.rb`
  - ログイン済みで `POST /session` を実行した場合に拒否され、未認証専用導線へ進めないことを確認

### 投稿
- `test/system/post_creation_system_test.rb`
  - タイムライン投稿フォームから投稿作成し、受付確認カードを表示
  - 141文字入力時に送信ボタンが無効化される（`post_body_length`）
  - 140文字ちょうどは送信できる（境界値）
- `test/integration/posts_flow_test.rb`
  - 未ログインで `POST /posts` を直叩きした場合に投稿作成されず、ログイン画面へリダイレクトされることを確認

### チャット
- `test/system/chat_message_system_test.rb`
  - チャット詳細で送信できる
  - 連投不可時に送信UIが無効化される
  - 141文字入力時に送信ボタンが無効化される（`post_body_length`）
  - 140文字ちょうどは送信できる（境界値）
  - 一覧バッジ（新着/返信待ち）の遷移
  - 詳細表示時の既読自動送信（`chat-read`）
  - 詳細表示時の最下部スクロール（`chat-scroll`）
  - 非参加ユーザーの直アクセス拒否（認可）
  - 未ログインユーザーの直アクセス拒否（認証）

### サインアップ/ポリシーUI
- `test/system/sign_up_frontend_system_test.rb`
  - 規約未同意で submit disabled、条件達成で enabled（`sign-up-submit` / `password-rules`）
  - パスワード条件未達成で submit が有効化されないこと
- `test/system/policy_modal_system_test.rb`
  - 利用規約リンク押下でモーダル表示、閉じるで非表示（`policy-modal`）

### 4. docs更新
- 本ドキュメントに、運用ルールと追加時の基準を維持管理する。
- `docs/03_engineering/testing/2026-02-08-01-testing-policy-minitest.md` と README のテスト説明を整合させる。

## 実作業チェックリスト
1. `Dockerfile.dev` にsystemテスト用ブラウザ実行環境を追加する。
2. `make dev-build` で再ビルドし、`make test` が通ることを確認する。
3. `test/system/` を作成し、認証/投稿/チャットの3本を追加する。
4. `.github/workflows/ci.yml` で `test:system` を実行し、失敗時artifactを保存する。
5. ローカルとCIで `make test` 相当が安定して通ることを確認する。
6. docs更新（README、testing policy、本ランブック）を完了する。

## 受け入れ条件との対応
- `make test`（`bin/rails test` + `bin/rails test:system`）がローカルで安定実行できる。
- CIでもsystemテストが定常実行され、失敗時に調査情報を取得できる。
- 追加したsystemテストが、認証/投稿/チャットの主要導線の回帰検知に使える。
- 「integrationとの棲み分け」と「systemテスト追加基準」がdocsに明記されている。

## 既知リスクと回避策
- `ubuntu-latest` 変動の影響を受けるリスク
  - 回避策: test jobの実行環境を `Dockerfile.dev` に寄せ、依存をDocker側で固定する。
- systemテスト増加によるCI時間悪化
  - 回避策: 最小3導線から開始し、追加時は「ユーザー価値に直結する導線」に限定する。
- headless環境の不安定化（表示タイミング/スクリーンショット不足）
  - 回避策: 失敗時artifact保存、待機条件の明示、1テスト1責務で切り分けやすく保つ。
- スクリーンショットartifactの情報露出リスク
  - 回避策: テストデータは原則ダミーのみを使う。`security-privacy-check` と GitGuardian を継続運用し、漏えい兆候を監視する。

## ローカル確認コマンド
```bash
# 全体
make test

# systemのみ
docker compose --env-file .env.test -f docker-compose.dev.yml -f docker-compose.test.yml \
  run --rm --workdir /app -e HOME=/tmp --user "$(id -u):$(id -g)" -e RAILS_ENV=test \
  web bash -lc 'bin/rails db:test:prepare && bin/rails test:system'
```

## 関連ドキュメント
- `docs/03_engineering/testing/2026-02-08-01-testing-policy-minitest.md`
- `docs/03_engineering/ci/2026-02-08-01-github-actions-rubocop-brakeman-min-tests.md`
- `README.md`
