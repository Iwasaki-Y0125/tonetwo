# MVP公開時 デプロイ修正チェックリスト（Render + Cloudflare）

本ドキュメントは、仮公開用の制限（Basic認証）から、MVPの一般公開へ切り替える際の修正手順をまとめる。

## 1. 事前確認（根拠）

### ローカル根拠
- `config/environments/production.rb`
  - `APP_ALLOWED_HOSTS` を `config.hosts` に反映する実装
  - `PreviewAccessControl` middleware を組み込む実装
- `lib/preview_access_control.rb`
  - `PREVIEW_BASIC_AUTH_USER` / `PREVIEW_BASIC_AUTH_PASSWORD` で Basic認証を有効化
  - `/up` は除外
- `bin/docker-entrypoint`
  - `bundle exec puma` 起動時に `db:prepare` を実行する実装

### 公式一次ソース
- Render Docs: Custom Domains
  - https://render.com/docs/custom-domains
- Render Docs: Environment Variables
  - https://render.com/docs/configure-environment-variables
- Render Docs: Health Checks
  - https://render.com/docs/health-checks
- Cloudflare Docs: DNS records
  - https://developers.cloudflare.com/dns/manage-dns-records/how-to/create-dns-records/

## 2. MVP公開時の修正方針

- 仮公開ガードを外して一般公開にする。
- ただし Host 制限は維持し、公開対象ドメインのみ許可する。
- DB準備導線（`db:prepare`）はそのまま維持する。

## 3. 実作業手順

1. Cloudflare の DNS を最終ドメインに合わせる。
2. Render の Custom Domain 設定を最終ドメインに合わせる。
3. Render 環境変数を更新する。
   - `APP_ALLOWED_HOSTS` を最終ドメイン値へ更新  
     例: `example.com,www.example.com`
   - `PREVIEW_BASIC_AUTH_USER` を削除（未設定にする）
   - `PREVIEW_BASIC_AUTH_PASSWORD` を削除（未設定にする）
4. デプロイを実行する（Manual Deploy）。

## 4. 公開後の確認

1. 独自ドメインでアクセスできる。
2. Basic認証ダイアログが出ない。
3. 許可ドメイン以外の Host ヘッダはブロックされる。
4. `/up` が 200 を返す（Render Health Check 成功）。
5. Deploy Logs で `db:prepare` が成功している。

## 5. 任意のコード整理（公開後）

現状は、仮公開用 middleware が残っていても、関連環境変数未設定なら制限は有効化されない。  
運用を明確にしたい場合は、以下を別Issueで実施する。

- `config/environments/production.rb` から `PreviewAccessControl` の組み込みを削除
- `lib/preview_access_control.rb` を削除
- 関連ドキュメントの更新
