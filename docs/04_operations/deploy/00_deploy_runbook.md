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

## 1. 事前準備

- [ ] Render の対象リージョンを決める（Web/DBは同一リージョン）
- [ ] 公開ホスト名を決める（例: `www.tonetwo.net`）
- [ ] Cloudflare の対象ゾーンが `Active` であることを確認する

## 2. Render で DB を作成

- [ ] Render で PostgreSQL を作成する
- [ ] Internal Database URL を確認する

## 3. Render で Web Service を準備

- [ ] Web Service を作成（または既存Serviceを確認）
- [ ] Web Service の基本設定
  - [ ] `Language`: `Docker`
  - [ ] `Branch`: `main`
  - [ ] `Root Directory`: 空欄（repo root）
  - [ ] `Docker Build Context Directory`: `.`
  - [ ] `Dockerfile Path`: `./Dockerfile`（または空欄デフォルト）
  - [ ] `Health Check Path`: `/up`
- [ ] 環境変数を設定
  - [ ] `DATABASE_URL`（PostgreSQL の Internal URL）
  - [ ] `APP_ALLOWED_HOSTS`（例: `www.tonetwo.net,<service>.onrender.com`）
  - [ ] 仮公開する場合のみ `PREVIEW_BASIC_AUTH_USER` / `PREVIEW_BASIC_AUTH_PASSWORD`
- [ ] 先に一度デプロイして起動確認する（Custom Domain 設定はその後）

## 4. Render で Custom Domain を追加

- [ ] Render の Web Service で `Custom Domain` に `www.tonetwo.net` を追加
- [ ] Render が表示する DNS レコード値（CNAME/A）を控える

## 5. Cloudflare で DNS/SSL を設定

- [ ] Cloudflare DNS に Render 指示値を登録する（推測値で作らない）
- [ ] 初回は `DNS only`（灰色雲）で設定する
- [ ] `SSL/TLS -> Overview` で `Full (strict)` を設定する
- [ ] 必要に応じて `SSL/TLS -> Edge Certificates` で `Always Use HTTPS` を有効化する

## 6. デプロイ実行

- [ ] Render で Manual Deploy を実行
- [ ] Deploy Logs で `db:prepare` 成功を確認
- [ ] Web 起動成功を確認

## 7. 動作確認

- [ ] `https://www.tonetwo.net` でアクセスできる
- [ ] `/up` が 200 で応答する
- [ ] 仮公開時: Basic認証の期待通りに動作する
- [ ] Host制限が有効（許可外Hostはブロック）

## 8. 切り替え

- [ ] 問題なければ Cloudflare を `Proxied`（橙色雲）へ切り替える
- [ ] MVP一般公開時は仮公開用ENVを削除
  - [ ] `PREVIEW_BASIC_AUTH_USER`
  - [ ] `PREVIEW_BASIC_AUTH_PASSWORD`

## 9. よくある順番ミス

- [ ] Render の Custom Domain 追加前に Cloudflare DNS を作らない
- [ ] Web/DB のリージョン不一致にしない
- [ ] `APP_ALLOWED_HOSTS` に実際の公開ホストを入れ忘れない
- [ ] 初回から `Proxied` にして切り分けを難しくしない
