# Issue #240 CSP導入メモ

- CSPの概要を確認したい場合は [CSP概要メモ](./2026-03-23-01-csp-basics.md) を参照。

## 目的
- Issue `#240` の実装前に、CSP導入の進め方と判断ポイントを短く整理する。
- Cloudflare の既存設定と重複しない責務分担を明文化する。
- 実装前に「先に直す箇所」と「導入後に確認する箇所」を見える化する。

## 対象 Issue
- Repo: `Iwasaki-Y0125/tonetwo`
- Issue: `#240`
- Title: `[Security] CSP導入とインラインJS整理`

## 背景
- 本番では [config/environments/production.rb](../../config/environments/production.rb) で `force_ssl` と `config.hosts` を使い、HTTPS 強制と Host 制限を行っている。
- Cloudflare 側では [2026-02-06-03-cloudflare-setup-for-render.md](../04_operations/deploy/2026-02-06-03-cloudflare-setup-for-render.md) の通り、DNS / TLS / WAF / Bot 対策を運用している。
- ただし、ブラウザ上で実行できるスクリプトや読み込み元を制御する `Content-Security-Policy` は未設定で、[config/initializers/content_security_policy.rb](../../config/initializers/content_security_policy.rb) はテンプレート状態のまま。
- 現状のレイアウトには [app/views/layouts/application.html.erb](../../app/views/layouts/application.html.erb) に `onclick` とインライン `<script>` が残っているため、厳格な CSP をいきなり enforce すると抵触する。

## このドキュメントで決めること
- このアプリで CSP を導入する順序を決める。
- `Report-Only` から enforce へ切り替える判断材料を整理する。
- Cloudflare と Rails CSP の責務差分を説明できる状態にする。

## 現時点の整理

### 1. Cloudflare と CSP の責務
- Cloudflare:
  - DNS
  - TLS 終端
  - WAF
  - Bot / JS Detections
  - Host 偽装など入口側の遮断
- CSP:
  - ブラウザ上で、どの script / style / image / frame / connect 先を許可するかを制御する
  - XSS 発生時の被害を減らす
  - アプリが返す HTML に対して、実行可能なリソースを制限する

結論:
- 両者は重複ではなく補完関係。
- Cloudflare が前段にあっても、ブラウザ向けの実行制御として CSP を入れる価値は残る。

### 2. 現状の CSP 抵触候補
- [app/views/layouts/application.html.erb](../../app/views/layouts/application.html.erb)
  - flash close ボタンの `onclick`
  - flash 自動消去用のインライン `<script>`
- [app/views/layouts/mailer.html.erb](../../app/views/layouts/mailer.html.erb)
  - `<style>` があるが、通常のWebページ向けCSPとは分けて考える

### 3. 導入しやすさ
- JS は [config/importmap.rb](../../config/importmap.rb) の importmap と [app/javascript](../../app/javascript) 配下の Stimulus controller 中心で、外部 CDN 依存は薄い。
- CSS は [package.json](../../package.json) の通り Tailwind をローカルビルドしている。
- そのため、アプリ側のインライン JS / style を除去すれば `self` 中心の比較的シンプルな CSP に寄せやすい。

## 実装方針

### 方針 1. 先にインライン JS を外す
- `onclick` は Stimulus controller か `data-action` に移した。
- flash 自動消去処理も `app/javascript` 側へ移した。
- inline style も外出しし、通常ページ向けでは `unsafe-inline` に依存しない構成にした。

### 方針 2. CSP は最小構成から始める
- 初期案は `default-src 'self'` をベースに必要なものだけ個別許可する。
- `base-uri 'none'`、`form-action 'self'`、`frame-ancestors 'none'`、`img-src 'self'`、`object-src 'none'` を個別指定する。
- `script-src 'self'` は importmap 用 nonce をレスポンスヘッダに載せるためにも残す。
- `style-src 'self'` は nonce 付き `<style>` を許可するために明示する。

### 方針 2-1. importmap の inline script は nonce で許可する
- [app/views/layouts/application.html.erb](../../app/views/layouts/application.html.erb) の `javascript_importmap_tags` は inline script を出力する。
- そのため、`script-src 'self'` を明示しつつ、`config.content_security_policy_nonce_directives = %w(script-src)` で nonce を有効にする。

### 方針 2-2. Turbo の動的 style 要素も nonce で許可する
- 本番 `Report-Only` 確認で、Turbo の動的 `<style nonce="...">` が `style-src-elem` violation になった。
- そのため、`policy.style_src :self` を明示しつつ、`config.content_security_policy_nonce_directives = %w[script-src style-src]` として `style-src` にも nonce を載せる。

### 方針 3. 先に Report-Only で本番確認し、enforce へ切り替える。
- まずは `Report-Only` のまま本番に載せる。
- [CSP本番確認とEnforce切り替えチェック #244](https://github.com/Iwasaki-Y0125/tonetwo/issues/244) の確認が完了したら、enforce へ切り替える。
- 個人開発の間は CSP 違反レポートの受け口は実装せず、ブラウザ DevTools の Console で violation を確認する。

## 手順
1. 通常ページ向けのインライン JS / inline style を除去する。
2. [config/initializers/content_security_policy.rb](../../config/initializers/content_security_policy.rb) に最小構成の CSP を定義する。
3. importmap の inline script 向けに `script-src` と nonce を設定する。
4. Turbo の動的 `<style>` 向けに `style-src` と nonce を設定する。
5. nonce generator が空文字を返さないことを確認する。
6. `Report-Only` のまま本番で主要画面を確認する。
7. CSP violation が出るなら許可元ではなく実装側を先に見直す。
8. 問題がなければ enforce へ切り替える。

## nonce 周りの調査メモ

### 1. `script-src` は nonce のためにも必要
- `script-src` を削ると、HTML 側に `nonce="..."` が付いていても、レスポンスヘッダ側に `script-src 'nonce-...'` を載せられない。
- そのため、importmap の inline script を nonce で許可する前提では `script-src 'self'` を残す必要がある。

### 1-1. `style-src` も nonce のために必要
- `default-src 'self'` は `style-src` の fallback にはなるが、nonce を載せる先としては使えない。
- そのため、nonce 付き `<style>` を許可する前提では `style-src 'self'` を明示する必要がある。

### 2. `request.session.id.to_s` は nonce generator に向かなかった
- `request.session.id.to_s` を nonce generator に使うと、未ログイン初回リクエストで空文字になりうる。
- 実際に確認したレスポンスでも、`nonce=""` と `script-src 'nonce-'` になった。

### 3. 現在は `SecureRandom.base64(16)` を使う
- 現在は `SecureRandom.base64(16)` を使って毎レスポンスで空にならない nonce を生成する構成にしている。
- 一次情報:
  - [config/initializers/content_security_policy.rb](../../config/initializers/content_security_policy.rb)
  - [Ruby SecureRandom](https://ruby-doc.org/3.4/stdlibs/securerandom/SecureRandom.html)
  - [MDN nonce](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes/nonce)
- 実レスポンスでも、CSP ヘッダ側の `script-src 'nonce-...'` と HTML 側の `nonce="..."` に同じ値が入ることを確認した。
- 本番確認では、`style-src 'nonce-...'` と `<style nonce="...">` の対応も見る。

## 参考
- ローカル一次情報
  - [config/initializers/content_security_policy.rb](../../config/initializers/content_security_policy.rb)
  - [app/views/layouts/application.html.erb](../../app/views/layouts/application.html.erb)
  - [app/views/layouts/mailer.html.erb](../../app/views/layouts/mailer.html.erb)
  - [config/environments/production.rb](../../config/environments/production.rb)
  - [config/importmap.rb](../../config/importmap.rb)
  - [package.json](../../package.json)
- 関連 docs
  - [2026-02-06-03-cloudflare-setup-for-render.md](../04_operations/deploy/2026-02-06-03-cloudflare-setup-for-render.md)
  - [2026-02-08-02-host-header-and-health-check-basics.md](../04_operations/monitoring/2026-02-08-02-host-header-and-health-check-basics.md)
