# Issue #145 実装メモ: チャット一覧の新着/返信待ちバッジ

## 目的
- ユーザー単位で未読状態を保持し、チャット一覧に反映する。
- 返信済みチャットを「返信待ち」として可視化し、一覧上で状態遷移を分かるようにする。

## ローカル根拠（実装時）
- `Gemfile.lock`
  - `rails (8.1.2)`
  - `turbo-rails (2.0.23)`
  - `stimulus-rails (1.3.4)`
- 既存チャット実装
  - `app/models/chatroom.rb`
  - `app/models/chat_message.rb`
  - `app/controllers/chats_controller.rb`
  - `app/views/chats/_chatroom_summary_row.html.erb`
  - `test/integration/chats_flow_test.rb`

## 一次ソース（公式）
- Active Record Migrations  
  https://guides.rubyonrails.org/active_record_migrations.html
- Active Record Associations  
  https://guides.rubyonrails.org/association_basics.html
- Testing Rails Applications  
  https://guides.rubyonrails.org/testing.html

## 確定仕様
- `chatrooms.last_sender_id` と `chatrooms.has_unread` で状態を管理する。
- 表示判定は排他とする。
  - `current_user.id == last_sender_id` の場合: `返信待ち`
  - `current_user.id != last_sender_id && has_unread == true` の場合: `新着`
  - 上記以外: バッジなし
- `GET /chats/:id` は読み取り専用にする。
- 既読更新は `PATCH /chats/:id/read` で行う。
  - `current_user.id != last_sender_id && has_unread == true` のとき `has_unread = false`
- `GET` で状態更新しない理由
  - 他サイト経由の意図しない `GET` 誘発で既読化される経路を避けるため。
- 不正アクセス調査ログの扱い
  - `chat_access_denied` ログには調査目的で `user_id` と `chat_id` を保持する。

## 実装変更
### 1. DB
- `db/migrate/20260221235000_add_message_state_to_chatrooms.rb`
  - `last_sender_id`（`users` へのFK）を追加
  - `has_unread`（`boolean`, `null: false`, `default: false`）を追加
- `db/schema.rb`
  - 上記のカラム/インデックス/FKを反映

### 2. Model
- `app/models/chatroom.rb`
  - `belongs_to :last_sender, class_name: "User", optional: true` を追加
- `app/models/chat_message.rb`
  - `create_in_room!` 内で、メッセージ作成後に
    - `last_sender = 送信者`
    - `has_unread = true`
    を同時更新

### 3. Controller
- `app/controllers/chats_controller.rb`
  - `show` では既読更新しない（読み取り専用）。
  - `read` アクションを追加し、受信側未読時のみ `has_unread` を `false` に更新。
  - 参加者以外が `read` を叩いた場合は `timeline` へリダイレクト。
  - `chat_access_denied` ログは不正アクセス調査のため、`user_id` / `chat_id` を記録する。

### 4. View
- `app/views/chats/show.html.erb`
  - 未読時のみ `PATCH /chats/:id/read` を自動送信する hidden form を追加。
- `app/javascript/controllers/chat_read_controller.js`
  - 詳細表示時に既読更新フォームを1回だけ `requestSubmit` するStimulusを追加。
- `app/views/chats/_chatroom_summary_row.html.erb`
  - `返信待ち / 新着 / なし` の排他表示を実装
  - `返信待ち` 時にカード背景を薄いグレーに変更
  - `返信待ち` バッジを濃色背景 + 白文字に調整

## テスト
- `test/integration/chats_flow_test.rb` に以下を追加
  - 受信側が詳細を開くと `新着` バッジが消える
  - 送信後に、送信者は `返信待ち`、相手側は `新着` になる
  - `PATCH /chats/:id/read` は参加者以外だと `timeline` へリダイレクト
- 実行コマンド
  - `bin/rails test test/integration/chats_flow_test.rb`
- 結果
  - `15 runs, 112 assertions, 0 failures, 0 errors`

## 補足（ローカル検証環境）
- `make damy-posts-seed` の時刻生成が未来側に寄ると、全体TLで最新投稿が先頭に出ない問題が起きる。
- ローカル専用ファイル `db/seeds/damy_posts/posts_seeder.local.rb` で時刻生成を修正し、未来時刻を作らないようにした。
  - `start_at = now - posts.seconds`
  - `ts = start_at + (posts_inserted + idx).seconds`
