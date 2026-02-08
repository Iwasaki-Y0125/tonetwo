# [CI] GitHub Actions: RuboCop / Brakeman / 最小テスト導入メモ（Issue #10）

## 目的
- Issue #10（`[CI] GitHub Actions：RuboCop / Brakeman / 最小テストの導入`）の作業手順と判断基準を、再現できる形で残す。
- README の方針（「RuboCop / Brakeman / 最小テスト」）と、実際の CI 実装（`.github/workflows/ci.yml`）を対応づける。

## 結論
- このリポジトリの CI は `.github/workflows/ci.yml` で運用する。
- 実行ジョブは `scan_ruby`（Brakeman）/ `scan_js`（importmap audit）/ `lint`（RuboCop）/ `test`（Rails test + system test）の4つ。
- トリガーは `pull_request` と `main` への `push`。

## ローカル一次情報（このリポジトリの事実）
- `Gemfile.lock`
  - `rails 8.1.2`
  - `rubocop 1.84.1`
  - `brakeman 8.0.2`
- `.ruby-version`
  - `3.4.8`
- `.github/workflows/ci.yml`
  - `bin/brakeman --no-pager`
  - `bin/importmap audit`
  - `bin/rubocop -f github`
  - `bin/rails db:test:prepare test test:system`
- `README.md`
  - 技術スタックで「静的解析: RuboCop」「セキュリティ静的解析: Brakeman」「テスト: MVPでは最小限」を明記。

## 基礎知識
### GitHub Actions の前提
- GitHub Actions の `workflow` は `.github/workflows/*.yml` に置く。
- `job` は runner 上で独立実行されるため、別 job の成果物や apt インストール結果は共有されない。

### Brakeman の前提
- Brakeman は Rails コードを実行せず、危険な値の流れ・危険な書き方・危険な設定を静的解析（実際には動かさず危険なコードがないか読むだけ）する。
- `bin/brakeman --checks` の一覧には古い Rails 向けの CVE チェックも含まれるため、現行バージョンでは実質対象外の項目もある。
- Brakeman は万能ではなく、認可や業務ロジックの不備は Minitest の request/integration test とコードレビューで補完する。

### テスト実行の前提
- Rails の CI で `db:test:prepare` を先に実行すると、テストDB準備の失敗を早期検知しやすい。

### RuboCop 出力の前提
- `rubocop -f github` は GitHub Actions 向けの出力形式で、PR 上で指摘が追いやすい。

## Issue #10 の実作業手順
1. 依存を確認する。
- `Gemfile.lock` で `rubocop` / `brakeman` の導入を確認。

2. Workflow を配置する。
- `.github/workflows/ci.yml` を作成し、`pull_request` と `push (main)` をトリガーにする。

3. セキュリティ静的解析ジョブを追加する。
- `scan_ruby` job で `ruby/setup-ruby` + `bin/brakeman --no-pager` を実行。

4. JS 依存監査ジョブを追加する。
- `scan_js` job で `bin/importmap audit` を実行。
- このリポジトリは `natto`/MeCab を使うため、必要な OS パッケージ（`mecab` 系）を job ごとにインストールする。

5. Lint ジョブを追加する。
- `lint` job で `bin/rubocop -f github` を実行。

6. テストジョブを追加する。
- `test` job に Postgres service container を定義。
- `DATABASE_URL=postgres://postgres:postgres@localhost:5432` を指定し、`bin/rails db:test:prepare test test:system` を実行。

7. 失敗時調査をしやすくする。
- `test` job で失敗時のみ `tmp/screenshots` を artifact として保存する。

8. PR で完了判定する。
- `scan_ruby / scan_js / lint / test` がすべて Green なら完了。

## ローカル確認コマンド
```bash
make exec
bin/brakeman --no-pager
bin/importmap audit
bin/rubocop -f github
bin/rails db:test:prepare
bin/rails test
bin/rails test:system
```

## 補足（ローカル手動実行）
### Brakeman の検査項目一覧
- Brakeman のチェック一覧を見たいときは、アプリコンテナ内で次を実行する。
```bash
make exec
bin/brakeman --checks
```

### importmap の監査実行
- importmap の脆弱性監査は次で実行できる。
```bash
make importmap-audit
echo $?
```
- `No vulnerable packages found` かつ終了コード `0` なら、監査は成功（検出なし）。

### テストの一括実行
- CI と同じ流れ（`db:test:prepare` + `test` + `test:system`）は次で実行できる。
```bash
make test
```

### テストの個別実行
- 特定テストだけ確認したい場合は、アプリコンテナ内で次を実行する。
```bash
make exec
bin/rails test test/integration/basic_availability_test.rb
```

## 関連ドキュメント
- `docs/03_engineering/ci/2025-12-23-01-ci.md`
- `docs/04_operations/dependency_management/2026-02-07-01-dependabot-basics-and-ops.md`
- `README.md`

## 公式一次ソース
- GitHub Actions workflow syntax
  - https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax
- GitHub-hosted runners
  - https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- PostgreSQL service containers in Actions
  - https://docs.github.com/en/actions/use-cases-and-examples/using-containerized-services/creating-postgresql-service-containers
- ruby/setup-ruby（公式リポジトリ）
  - https://github.com/ruby/setup-ruby
- importmap-rails（公式リポジトリ）
  - https://github.com/rails/importmap-rails
- RuboCop formatter（公式 docs）
  - https://docs.rubocop.org/rubocop/formatters.html
- Brakeman options（公式 docs）
  - https://brakemanscanner.org/docs/options/
- Rails testing guide（公式）
  - https://guides.rubyonrails.org/testing.html
