# Issue #146 実装メモ: チャット欄の内部スクロール化と初期表示の最下部寄せ

## 目的
- メッセージ増加時にページ全体が伸びる状態を避ける。
- チャット画面の初期表示を最下部（最新メッセージ）に寄せる。
- 送信後リダイレクト時も最下部表示を維持する。

## 実装変更
1. チャット画面レイアウト
- `app/views/chats/show.html.erb`
  - メッセージ領域を `max-h-[50vh] overflow-y-auto` に変更（内部スクロール化）。
  - 送信フォームをスクロール領域の外へ分離し、常時表示を維持。
- `app/views/chats/new.html.erb`
  - `show` と同じ表示構成に統一（内部スクロール領域 + フォーム外出し）。

2. スクロール追従（Stimulus）
- `app/javascript/controllers/chat_scroll_controller.js` を追加。
  - `connect` 時に最下部へ移動。
  - `turbo:load` 発火時（送信後リダイレクト含む）にも最下部へ移動。
  - `requestAnimationFrame` 後に再実行し、描画タイミング差によるズレを吸収。
  - `disconnect` で `turbo:load` 購読解除と `requestAnimationFrame` の予約解除を実施。

3. View接続
- `app/views/chats/show.html.erb`
  - `data-controller="compose-focus chat-scroll"` を追加。
  - メッセージ領域に `data-chat-scroll-target="messages"` を追加。
- `app/views/chats/new.html.erb`
  - `show` と同様に `chat-scroll` / `messages` target を追加。

4. 見た目調整
- `app/views/chats/_message_bubble.html.erb`
  - バブル左右余白（`px-4`）を調整。

5. サイドバー表示条件
- `app/views/layouts/application.html.erb`
  - 右側投稿フォームサイドバーは `timeline` / `similar_timeline` のときのみ表示するよう変更。
- `app/views/shared/_site_header.html.erb`
  - 途中で入れた表示制御は撤回し、ヘッダーナビは元仕様へ復帰。

## テスト
- 追加:
  - `test/integration/chats_flow_test.rb`
    - `chat-scroll` 接続用のDOM属性/クラス（`data-controller`, `data-chat-scroll-target`, `max-h-[50vh]`, `overflow-y-auto`）を検証。
- 追記:
  - 並列実行時のrate limit干渉対策として、以下でテスト単位の `REMOTE_ADDR` 分離を追加。
    - `test/controllers/sign_ups_controller_test.rb`
    - `test/controllers/sessions_controller_test.rb`
    - `test/controllers/posts_controller_test.rb`
    - `test/integration/rack_attack_throttle_test.rb`

## systemテストの扱い
- `test/system/chat_scroll_test.rb` は一度作成したが、実行環境（ChromeDriver依存ライブラリ不足）により本ブランチでは削除。
- systemテスト基盤整備と主要導線E2E追加は別Issueで対応:
  - `#153 [test] Systemテスト基盤を整備し、重要導線のE2Eを追加する`
