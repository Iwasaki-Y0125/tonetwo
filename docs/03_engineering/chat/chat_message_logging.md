# チャット本文をログに出さない方針（通信の秘密・漏えいリスク低減）

## 目的
チャット本文（メッセージ内容）が、アプリログ・エラートラッキング・外部ログ基盤に出力されて「第三者が知り得る状態」になるのを防ぐ。

- 通信は **TLS（HTTPS / WSS）** を前提とする
- 本文はDBに保存し得るが、**通常運用でログに残さない**（閲覧は通報対応など必要時に限定する）

## 想定スタック
- Rails（ActionDispatch / ActiveSupport）
- Render（アプリが標準出力したログが表示される）
- 監視：Sentry等（導入する場合）

---

## MVPまでにやること（必須）

### 1. Railsのリクエストログから本文系パラメータをマスクする
Railsは `Parameters: {...}` をログ出力することがあるため、本文が混ざる可能性のあるキーを `config.filter_parameters` に追加する。

`config/initializers/filter_parameter_logging.rb`

```rb
Rails.application.config.filter_parameters += [
  :message, :content, :text, :body, :raw, :payload,
  :token, :access_token, :refresh_token
]
```
- 期待結果：ログ上では該当キーが "[FILTERED]" になる

2. 自前ログ（Rails.logger）で本文を出さない

自分で Rails.logger.info(params) などを書くと、フィルタをすり抜けたり、意図せず本文が出ることがある。
方針：本文をログに出さない。必要ならメタ情報のみ。

例（安全寄り：本文はログに含めない）：
```rb
Rails.logger.info(
  event: "message_create",
  user_id: current_user.id,
  room_id: params[:room_id],
  message_length: params.dig(:message, :content).to_s.length
)
```
※どうしてもパラメータ全体をログに出したい場合は ActiveSupport::ParameterFilter を通す（ただしMVPでは推奨しない）：
```rb
filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
safe_params = filter.filter(params.to_unsafe_h)
Rails.logger.info(event: "message_create", params: safe_params)
```
3. raw body をログに出すコードを禁止
以下は フィルタをすり抜ける ので禁止：
- request.raw_post をログ出力
- request.body.read をログ出力
- 例外通知に raw body を添付

4. 本番ログレベルを debug にしない
本番は info 以上を基本にし、デバッグログを常用しない（本文漏えいの事故率が上がる）。

## 本リリースまでにやること（推奨）
1. エラートラッキング（Sentry等）側でも同等にフィルタ
Railsの filter_parameters と同じ発想で、Sentryに送るイベントから本文系キーをマスクする。
- 目的：例外発生時に request/params がSaaSへ送信されるのを防ぐ
- 実施：Sentryの「Filtering」設定で message/content/body/text 等をマスク

2. 「本文を見られる人」を絞り、監査できるようにする
- 通報対応など 必要なときだけ 本文を閲覧できる権限設計
- 管理画面で本文閲覧したら 監査ログ（誰が・いつ・何を） を残す
- 委託先や運用担当が増えたときの統制に効く

3. DB/バックアップの保護（保存時の安全）
- DBの暗号化（プロバイダ側の at-rest 暗号化 + 鍵管理の確認）
- バックアップ（dump、PITR、オフサイト）も同等に保護
- バックアップ格納先へのアクセス制御（最小権限、監査）

4. ドキュメント（規約/ポリシー）に取り扱いを明記
- 「通報対応等の必要時に限り、内容にアクセスする可能性がある」旨
- ログ/監査/アクセス制限の方針


## 確認ポイント（動作検証）
- チャット送信時のログに本文が出ていない
- 例外発生時（バリデーションエラー/500など）にも本文が出ていない
- 外部（Sentry等）に送信されるイベントに本文が含まれない

参考（一次ソース）

- Rails Guides: Configuring Rails Applications（filter_parameters）
https://guides.rubyonrails.org/configuring.html

- ActiveSupport::ParameterFilter（API）
https://api.rubyonrails.org/v7.1/classes/ActiveSupport/ParameterFilter.html

- ActionDispatch::Http::FilterParameters（API）
https://api.rubyonrails.org/classes/ActionDispatch/Http/FilterParameters.html

- Sentry（Rails）Filtering（導入する場合）
https://docs.sentry.io/platforms/ruby/guides/rails/configuration/filtering/
