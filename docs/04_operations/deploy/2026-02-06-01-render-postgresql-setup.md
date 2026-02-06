# Render PostgreSQL 作成・接続・マイグレーション導線整備

本ドキュメントは Issue「[Deploy] Render PostgreSQL作成・接続・マイグレーション導線整備」の実施手順をまとめる。

## 1. 事前確認（根拠）

### ローカル根拠
- `Gemfile.lock`
  - `rails (8.0.4)`
  - `pg (1.6.3-x86_64-linux)`
- `Dockerfile`
  - `ENTRYPOINT ["/rails/bin/docker-entrypoint"]`
  - `CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]`
- `bin/docker-entrypoint`
  - `puma` 起動時にも `./bin/rails db:prepare` を実行するよう修正済み

### 公式一次ソース
- Render Docs: PostgreSQL の作成・接続
  - https://render.com/docs/postgresql-creating-connecting
- Render Docs: Environment Variables
  - https://render.com/docs/configure-environment-variables
- Render Docs: Deploys / Deploy Hooks
  - https://render.com/docs/deploys
- Rails Guides: `db:prepare`
  - https://guides.rubyonrails.org/active_record_migrations.html

## 2. Render で PostgreSQL を作成

1. Render Dashboard で `New +` -> `PostgreSQL` を選択する。
2. DB 名、リージョン、プランを選び作成する。
3. 作成後、DB詳細画面で接続情報（Internal Database URL）を確認する。
   - Web Service から同一リージョンで接続する前提では Internal URL を使う。

## 3. Web Service に `DATABASE_URL` を設定

1. Render の対象 Web Service を開く。
2. `Environment` で `DATABASE_URL` を追加する。
   - 値は PostgreSQL 側の Internal Database URL を設定する。
3. 可能なら Render の「DB から環境変数を紐づける導線（Add from Database）」を使い、手入力ミスを避ける。

## 4. 初回デプロイ時のマイグレーション導線

### このリポジトリの導線
- `Dockerfile` の `ENTRYPOINT` で `bin/docker-entrypoint` を呼ぶ。
- `bin/docker-entrypoint` で、Web 起動コマンドが `puma`（または `rails server`）なら `db:prepare` を先に実行する。
- `db:prepare` は未作成DBの作成 + 未適用 migration の反映を行う。

### 補足（運用上の選択肢）
- より明示的に「デプロイ前に一度だけ migration を走らせたい」場合は、Render の Deploy Hook（Pre-Deploy Command）で `bundle exec rails db:migrate` を使う運用も可能。
- ただし本構成では entrypoint 側で `db:prepare` を実行するため、まずはこの導線で運用できる。

## 5. 本番での確認手順（DoD チェック）

1. Render で手動デプロイを実行する（`Manual Deploy`）。
2. Deploy Logs で以下を確認する。
   - `db:prepare` 実行ログが出ていること
   - migration が成功していること
   - Web 起動が成功していること
3. アプリURLへアクセスし、500 や DB 接続エラーが出ないことを確認する。
4. 必要に応じて DB 側で `schema_migrations` を確認し、最新 migration が反映済みであることを確認する。

## 6. トラブル時の確認ポイント

- `DATABASE_URL` の設定ミス（空、誤URL、External URLの誤利用）
- Web Service と DB のリージョン不一致による接続遅延/失敗
- migration で必要な ENV が不足（認証系・外部API系の初期化で失敗）
- deploy image の更新漏れ（古いイメージが起動している）

## 7. 今回のリポジトリ変更

- `bin/docker-entrypoint`:
  - `bundle exec puma` 起動でも `db:prepare` を実行するよう条件を拡張。
- `lib/preview_access_control.rb`:
  - 仮公開時のアクセス制限（Basic認証）を追加。
- `config/environments/production.rb`:
  - `APP_ALLOWED_HOSTS` で許可ホストを制限できるように追加。
  - `PreviewAccessControl` ミドルウェアを追加。

## 8. 独自ドメイン + アクセス制限（仮公開）

### 8-1. Cloudflare で DNS を設定

1. Render Web Service の `Settings` -> `Custom Domains` でドメインを追加する。
2. Render が表示する DNS レコード（通常は `CNAME`）を Cloudflare DNS に設定する。
3. SSL モードは `Full` か `Full (strict)` を使う。

### 8-2. Render 側の環境変数を設定

| 変数名 | 例 | 用途 |
|---|---|---|
| `APP_ALLOWED_HOSTS` | `example.com,www.example.com,app-name.onrender.com` | Host ヘッダ許可リスト |
| `PREVIEW_BASIC_AUTH_USER` | `preview_user` | Basic認証ユーザー |
| `PREVIEW_BASIC_AUTH_PASSWORD` | `strong-password` | Basic認証パスワード |

- Basic認証を無効化したい場合は `PREVIEW_BASIC_AUTH_USER` と `PREVIEW_BASIC_AUTH_PASSWORD` を未設定にする。
- 本番ヘルスチェック `/up` は制限対象外（監視維持のため）。

### 8-3. 動作確認

1. デプロイ後、未認証アクセスで 401 が返ることを確認する（Basic有効時）。
2. 認証情報入力後に画面表示できることを確認する。
3. Render Health Check が継続して成功することを確認する。
