# Issue #240 CSP導入メモ

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
- 先に除去すべきインライン JS を明示する。
- 初回を `Report-Only` にするか、最初から enforce にするかの判断材料を整理する。
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
- そのため、インライン JS を除去すれば `self` 中心の比較的シンプルな CSP に寄せやすい。

## 実装方針

### 方針 1. 先にインライン JS を外す
- `onclick` は Stimulus controller か `data-action` に移す。
- flash 自動消去処理も `app/javascript` 側へ移す。
- ここを先に片付けることで、`unsafe-inline` に依存しない CSP を目指しやすくする。

### 方針 2. CSP は最小構成から始める
- 初期案は `default-src 'self'` をベースに必要なものだけ個別許可する。
- 少なくとも `object-src 'none'`、`base-uri 'self'` は入れる方向で考える。
- `script-src` と `style-src` は、実際の importmap / asset 配信形態に合わせて最小化する。

### 方針 3. 初回は Report-Only を第一候補にする
- 理由:
  - まだインライン JS が残っている
  - 画面ごとの読み込み元を網羅確認していない
  - 本番で Cloudflare 配下の挙動も含めて、違反の有無を先に見たい
- ただし、実装中に違反箇所を解消し切れて、許可元も限定できるなら enforce 直行も再判断する。

## 手順
1. [app/views/layouts/application.html.erb](../../app/views/layouts/application.html.erb) のインライン JS を棚卸しする。
2. 該当処理を `app/javascript` 配下へ移し、HTML 側は `data-*` 属性中心にする。
3. [config/initializers/content_security_policy.rb](../../config/initializers/content_security_policy.rb) に暫定 CSP を定義する。
4. 必要なら nonce と `Report-Only` を設定する。
5. 主要画面を確認し、違反が出るなら許可元ではなく実装側を先に見直す。
6. 妥当なら enforce へ切り替える。
7. 運用 docs に Cloudflare と CSP の責務差分を追記する。

## 受け入れ条件の下書き
- 本番レスポンスに CSP ヘッダが付与される。
- `unsafe-inline` を必須としない構成になっている、または残す理由が明文化されている。
- 主要画面で CSP 違反により操作不能な箇所がない。
- flash 通知の手動クローズと自動消去が回帰していない。
- Cloudflare と CSP の役割差分を docs で説明できる。

## 未確定
- 初回導入を `Report-Only` にするか、最初から enforce にするか。
- CSP 違反レポートの受け口を実装するか。
- `img-src` / `font-src` / `connect-src` に `data:` や外部許可元が必要か。

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
