# Hostヘッダ偽装とヘルスチェックの基礎メモ

## 目的
- Issue #74 の作業で出てきた「Hostヘッダ」「DNSリバインディング保護」「/up」の関係を、後で見返せる形で残す。

## 結論
- `Host` は URL のドメイン部を示すHTTP情報で、クライアント側で任意値を送れる。
- そのため、許可していないHostをアプリが受け入れると、URL生成やセキュリティ前提が崩れるリスクがある。
- ToneTwo では Cloudflare と Rails (`config.hosts`) の二段で防御し、監視用の `/up` だけ例外で通している。

## 用語
- Host（ホスト）:
  URL のドメイン部分（例: `www.tonetwo.net`）。
- Hostヘッダ:
  リクエストが「どのホスト宛てか」を示すHTTPヘッダ。
- エンドポイント:
  外部からアクセスするURLの受け口（例: `/up`）。
- Basic認証:
  ユーザー名/パスワードでアクセス制御する簡易認証方式。

## なぜ Host 偽装が問題か
1. アプリが正規ドメインを誤認する可能性がある。
2. 絶対URL生成（例: メールリンク生成）で不正ドメインが混入するリスクがある。
3. フィッシング導線や他の攻撃の足場になりやすくなる。

## このリポジトリでの防御ポイント
1. `config/environments/production.rb`
   - `APP_ALLOWED_HOSTS` を `config.hosts` に反映し、許可Hostのみ受け付ける。
   - `config.host_authorization = { exclude: ->(request) { request.path == "/up" } }` で `/up` のみ例外。
2. `lib/preview_access_control.rb`
   - `HEALTHCHECK_PATH = "/up"` をBasic認証対象から除外。
   - 監視導線を塞がないため。
3. Cloudflare
   - 不正HostがCloudflare層で `403` になる場合がある（Rails到達前に遮断）。

## 確認コマンド例
```bash
curl -i https://www.tonetwo.net/up
curl -H 'Host: waruihost.tonetwo.net' https://www.tonetwo.net
```

## 2026-02-08 時点の確認結果
- `/up` は `HTTP/2 200` を確認。
- `Host: waruihost.tonetwo.net` を付けたアクセスは `403 Forbidden (cloudflare)` を確認。

## 運用上のメモ
- `/up` は「死活確認のため公開で到達できる」前提のエンドポイント。
- `/up` には機密情報を出さない（現状はステータス確認用途の最小情報）。
- Render監視確認は「`Health Check Path = /up`」「`/up` が200」「Events/Logsに異常連発がない」の3点で判定する。

## 参考（ローカル）
- `config/routes.rb`
- `config/environments/production.rb`
- `lib/preview_access_control.rb`
- `docs/04_operations/monitoring/2026-02-08-01-render-health-check-issue-74-runbook.md`
