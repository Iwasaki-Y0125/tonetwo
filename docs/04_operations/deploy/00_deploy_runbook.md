# Deploy Runbook（実行順）

本ドキュメントは「何をどの順番で実行するか」だけをまとめた実行用チェックリスト。  
詳細手順は各ドキュメントを参照する。

## 0. 参照ドキュメント

- Render PostgreSQL / DB導線:
  - `docs/04_operations/deploy/2026-02-06-01-render-postgresql-setup.md`
- MVP公開時の修正事項:
  - `docs/04_operations/deploy/2026-02-06-02-mvp-release-deploy-checklist.md`
- Cloudflare設定:
  - `docs/04_operations/deploy/2026-02-06-03-cloudflare-setup-for-render.md`
- トラブルシュート記録:
  - `docs/04_operations/deploy/2026-02-07-01-render-deploy-troubleshooting-notes.md`
- 用語整理（Custom Domain / DNS）:
  - `docs/04_operations/deploy/2026-02-07-02-custom-domain-dns-quick-reference.md`

## 1. 事前準備

- [x] Render の対象リージョンを決める（Web/DBは同一リージョン）
- [x] 公開ホスト名を決める（例: `www.tonetwo.net`）
- [x] Cloudflare の対象ゾーンが `Active` であることを確認する

## 2. Render で DB を作成

- [x] Render で PostgreSQL を作成する
- [x] Internal Database URL を確認する

## 3. 初回デプロイ前の修正作業

- [x] `tone_two_production_cache` DB と `solid_cache_entries` テーブルを作成する
- [x] `config/database.yml` の `production.primary` が `ENV["DATABASE_URL"]` を参照する状態に修正する
- [x] `tailwind.css` アセット生成のため、`Dockerfile` の build ステージで `npm run build:css` を実行するように修正する

## 4. Render で Web Service を準備

- [x] Web Service を作成（または既存Serviceを確認）
- [x] Web Service の基本設定
  - [x] `Language`: `Docker`
  - [x] `Branch`: `main`
  - [x] `Root Directory`: 空欄（repo root）
  - [x] `Docker Build Context Directory`: `.`
  - [x] `Dockerfile Path`: `./Dockerfile`（または空欄デフォルト）
  - [x] `Health Check Path`: `/up`
- [x] 環境変数を設定
  - [x] `DATABASE_URL`（PostgreSQL の Internal URL）
  - [x] `APP_ALLOWED_HOSTS`（例: `www.tonetwo.net,<service>.onrender.com`）
  - [x] `SECRET_KEY_BASE` を設定
  - [x] 仮公開する場合のみ `PREVIEW_BASIC_AUTH_USER` / `PREVIEW_BASIC_AUTH_PASSWORD`
- [x] 初回デプロイ前の設定確認を完了する


## 5. デプロイ実行（初回）

- [x] Render で Manual Deploy を実行
- [x] Deploy Logs で `db:prepare` 成功を確認
- [x] Web 起動成功を確認

## 6. Render で Custom Domain を追加

- [x] Render の Web Service で `Custom Domain` に `www.tonetwo.net` を追加
- [x] Render が表示する DNS レコード値（CNAME/A）を控える

## 7. Cloudflare で DNS/SSL を設定

- [x] Cloudflare DNS に Render 指示値を登録する（推測値で作らない）
- [x] 初回は `DNS only`（灰色雲）で設定する
- [x] `SSL/TLS -> Overview` で `Full (strict)` を設定する
- [x] `SSL/TLS -> Edge Certificates` で `Always Use HTTPS` を有効化する

## 8. 動作確認

- [x] `https://www.tonetwo.net` でアクセスできる
- [x] `https://www.tonetwo.net/up` が 200 で応答する
- [x] 仮公開時: Basic認証の期待通りに動作する
- [x] Host制限が有効（許可外Hostはブロック）

## 9. 切り替え

- [x] 問題なければ Cloudflare を `Proxied`（橙色雲）へ切り替える
- [x] Render の `Render Subdomain` を `Disabled` にする（公開URLを独自ドメインへ一本化）
- [x] `APP_ALLOWED_HOSTS` から `<service>.onrender.com` を外す（例: `www.tonetwo.net` のみ）
- [x] `APP_ALLOWED_HOSTS` 変更時は再デプロイして反映を確認する

## 10. 注意点

- Web/DB のリージョン不一致にしない
- 先に Render で `Custom Domain` を追加し、表示値を確認してから Cloudflare DNS を作成する
- `APP_ALLOWED_HOSTS` に公開ホストを入れ忘れない。カスタムドメインを設定後に`<service>.onrender.com` を外し忘れない。
- 初回から `Proxied` にしてエラーの切り分けを難しくしない

## 11. トラブルシューティング（詰まったときのTODO）

- [ ] 起動失敗時: Render Environment に `SECRET_KEY_BASE` が設定されているか確認する
- [ ] DB接続失敗時: `DATABASE_URL` が Render PostgreSQL の Internal URL になっているか確認する
- [ ] DB接続失敗時: `config/database.yml` の `production.primary` が `ENV["DATABASE_URL"]` を参照しているか確認する
- [ ] `solid_cache_entries` エラー時: `tone_two_production_cache` と `solid_cache_entries` の存在を確認する
- [ ] `tailwind.css` エラー時: Build Logs に `npm run build:css` が出ているか確認する
- [ ] 500系エラー時: Render の Deploy Logs / Runtime Logs で直近の例外メッセージを確認する
