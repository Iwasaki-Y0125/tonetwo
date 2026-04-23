# Puma 8 更新時の IPv4/IPv6 影響メモ（初学者向け）

## 目的
- `puma 7.2.0 -> 8.0.0` で、なぜ「本番影響がありうる」のかを短く説明できる状態にする。
- 特に `Render` 運用での `IPv4/IPv6` 論点を、初学者でも判断しやすい形で残す。

## まず結論
- このアプリでは、`Render` 上の本番でも `Puma` を使っている。
- `Puma 8` ではデフォルト bind が `IPv6` 側へ寄るため、`config/puma.rb` で待ち受け先を明示しないと環境依存の差が出る可能性がある。
- 現時点の運用方針としては、`0.0.0.0`（IPv4）を明示するのが安全。

## 役割分担（超要約）
- `Rails`: アプリ本体（画面遷移、業務ロジック）
- `Puma`: HTTPリクエストを受けて Rails に渡すアプリサーバ
- `Render`: Puma + Rails を動かす実行環境（PaaS）

つまり「Render を使っているから Puma は無関係」ではない。Render から渡された通信を受けるのは Puma。

## このリポジトリで確認できる事実（ローカル一次情報）
- 本番起動コマンドは `bundle exec puma -C config/puma.rb`
  - [Dockerfile](../../../Dockerfile)
- エントリポイントでも `puma` 起動を前提に `db:prepare` を実行している
  - [bin/docker-entrypoint](../../../bin/docker-entrypoint)
- `config/puma.rb` は `port` 指定のみで、host/bind の明示がない
  - [config/puma.rb](../../../config/puma.rb)
- 開発環境は `bin/rails server -b 0.0.0.0 -p 3000` を明示している
  - [docker-compose.dev.yml](../../../docker-compose.dev.yml)

## どこが変更点か（公式一次情報）
- Puma 8 の Upgrade Guide に、デフォルト bind 挙動の変更が記載されている。
  - <https://github.com/puma/puma/blob/main/docs/8.0-Upgrade.md>
- リリースノート
  - <https://github.com/puma/puma/releases/tag/v8.0.0>

## Render の文脈で何が問題になるか
Render 公式ドキュメントでは、Web Service は `0.0.0.0` に bind して待ち受ける前提で説明されている。

- Render が受けたリクエストをアプリへ転送する
- Puma がその受け口で待っていないと接続失敗になる

参考: <https://render.com/docs/web-services>

## 初学者向けイメージ
1. ブラウザが `https://...` にアクセスする
2. Render が受け取る
3. Render がコンテナ内の Puma に渡す
4. Puma が受け取って Rails に処理を渡す

このとき、Render が渡す入口と Puma の待受がズレると失敗する。

## IPv6を使う/使わないの判断
### IPv6寄り（Puma 8 デフォルト寄り）
- メリット: デフォルト挙動に沿える。
- デメリット: 環境依存の差を踏みやすく、運用確認コストが上がる。

### IPv4固定（`0.0.0.0` 明示）
- メリット: Render の説明と一致し、挙動が読みやすい。
- メリット: 開発環境の待受設定とも整合しやすい。
- デメリット: 将来 IPv6 方針を採る場合は見直しが必要。

## このアプリでの推奨
- Puma 8 を採用する場合は、`config/puma.rb` で待受を明示する。
- まずは `0.0.0.0` 明示で安全側に寄せ、デプロイ直後に `/up` と主要画面の疎通を確認する。

## 今回の採用方針（2026-04-23）
- 本アプリでは当面 `IPv4` 待受を採用する。
- 待受の固定は Dockerfile ではなく Puma 設定で行う。
- 具体的には [config/puma.rb](../../../config/puma.rb) の `port` 設定を以下にする。

```ruby
port ENV.fetch("PORT", 3000), "0.0.0.0"
```

## 反映状況
- 2026-04-23 時点で [config/puma.rb](../../../config/puma.rb) に上記設定を反映済み。

## 関連ドキュメント
- [Issue 194: Kamal proxy と Thruster の構成比較と採用方針](./2026-03-11-01-issue-194-kamal-proxy-vs-thruster-decision.md)
- [Deploy runbook](./00_deploy_runbook.md)
- [Issue #74 死活監視（Render Health Check）実施手順](../monitoring/2026-02-08-01-render-health-check-issue-74-runbook.md)
