# Cloudflare セットアップ手順（Render デプロイ用）

本ドキュメントは、`www.tonetwo.net` を Render Web Service に向けるための Cloudflare 設定手順をまとめる。

## 1. 前提

- 対象ドメイン: `tonetwo.net`
- 公開ホスト名: `www.tonetwo.net`
- Render 側で Web Service が作成済みであること

## 2. 設定順序（重要）

1. Render で `Custom Domain` に `www.tonetwo.net` を追加する
2. Render が表示した DNS レコード値（通常 `CNAME`）を確認する
3. Cloudflare DNS にその値を登録する

先に推測値で DNS を作らず、必ず Render が提示した値を使う。

## 3. Cloudflare 側の設定

## 3-1. SSL/TLS モード

- 場所: `SSL/TLS` -> `Overview` -> `Encryption mode`
- 推奨: `Full (strict)`
- うまく接続できない場合のみ一時的に `Full` へ下げる
- 問題解消後は `Full (strict)` に戻す

### Full / Full (strict) の違い

- `Full`: Cloudflare -> Render 間は HTTPS だが証明書の厳密検証はしない
- `Full (strict)`: Cloudflare -> Render 間の証明書有効性とドメイン一致まで検証する

## 3-2. HTTPS 強制

- 場所: `SSL/TLS` -> `Edge Certificates` -> `Always Use HTTPS`
- 初回は接続確認後に有効化でよい

## 3-3. DNS レコード

- 場所: `DNS` -> `Records` -> `Add record`
- `Type`: Render の指示どおり（通常 `CNAME`）
- `Name`: `www`
- `Target`: Render 指示値

初回の切り分けでは `Proxy status` を `DNS only`（灰色雲）にすると原因調査しやすい。  
動作確認後に `Proxied`（橙色雲）へ切り替える。

## 4. トラブル時の切り分け

- `525/526` が出る: SSL 設定・証明書反映を疑う
- まず `DNS only` で到達性確認
- それでも失敗する場合、Render 側の Custom Domain 状態と証明書発行状態を確認
- 一時対応で `Full` に下げ、安定後 `Full (strict)` に戻す

## 5. 最終チェック

1. `https://www.tonetwo.net` で表示できる
2. Render 側でドメイン検証が `Verified` になる
3. Cloudflare SSL モードが `Full (strict)` になっている
4. 必要に応じて `Always Use HTTPS` が有効

