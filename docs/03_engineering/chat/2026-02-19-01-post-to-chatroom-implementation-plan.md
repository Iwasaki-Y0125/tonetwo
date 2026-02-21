# Issue #24 実装記録: 投稿からチャット開始（room作成）

## 目的
- 投稿カードから 1on1 チャットへ遷移できる導線を提供する。
- 同一の `post_id + reply_user_id` でチャットルームが重複しないようにする。
- 作成後/再利用後にチャット詳細へ遷移できるようにする。

## ローカル根拠（実装後）
- `config/routes.rb`
  - `resource :chat, only: %i[new create], controller: "chats"`（`posts` ネスト）
  - `resources :chats, only: %i[index show]`
  - `resources :messages, only: %i[create], module: :chats`
- `db/schema.rb`
  - `chatrooms(post_id, reply_user_id)` テーブルとユニークインデックス
  - `chat_messages(chatroom_id, user_id, body)` テーブルと140字制約
- `app/controllers/chats_controller.rb`
  - 下書き画面（`new`）表示と送信時作成（`create`）
- `app/controllers/chats/messages_controller.rb`
  - 既存チャットへのメッセージ送信（`create`）
- `config/initializers/filter_parameter_logging.rb`
  - `:chat_message`, `:body` をマスク対象に追加（本文ログ抑止）
- `config/initializers/rack_attack.rb`
  - `POST /posts/:post_id/chat` と `POST /chats/:chat_id/messages` のIP単位レート制限を追加

## 一次ソース（公式）
- Rails Routing from the Outside In  
  https://guides.rubyonrails.org/routing.html
- Active Record Associations  
  https://guides.rubyonrails.org/association_basics.html
- Active Record Validations（uniqueness と DB ユニーク制約の併用）  
  https://guides.rubyonrails.org/active_record_validations.html

## 確定仕様
1. チャット開始導線
   - 全体TL/おすすめTLで、他人投稿カードをクリックすると `GET /posts/:post_id/chat/new` へ遷移する。
   - 自分投稿は従来どおり `my/posts/:id` を維持する。
2. チャットルーム作成タイミング
   - 画面遷移時にはDB保存しない。
   - 初回メッセージ送信時（`POST /posts/:post_id/chat`）に `chatroom` + `chat_message` を保存する。
3. 重複防止
   - `chatrooms(post_id, reply_user_id)` のユニークインデックスで重複作成を防止。
   - `find_or_create_by!` + `RecordNotUnique` rescue で競合時も既存roomを再利用。
4. 権限制御
   - `owner_user_id` は持たず、`chatroom.post.user_id` と `reply_user_id` で参加者判定。
   - 参加者以外アクセスはモデルで `RecordNotFound` とし、コントローラで捕捉して `timeline` へリダイレクトする。
5. UI
   - チャット画面: 右=自分、左=相手。
   - 送信フォーム: 投稿フォームの文字数制限UI（140字）を流用。
6. 投稿失敗時の入力復元（データ最小化）
   - UX維持のため本文をflashで1リクエストのみ保持し、保持上限は140文字とする。
7. セキュリティ/プライバシー（今回追加）
   - チャット本文パラメータは `filter_parameters` でマスクする。
   - チャット初回送信/既存チャット送信は Rack::Attack でIP単位レート制限する。

## 実装済み変更
- migration
  - `db/migrate/20260219160000_create_chatrooms.rb`
  - `db/migrate/20260219160100_create_chat_messages.rb`
- model
  - `app/models/chatroom.rb`
  - `app/models/chat_message.rb`
- route
  - `config/routes.rb`
- initializer
  - `config/initializers/filter_parameter_logging.rb`
  - `config/initializers/rack_attack.rb`
- controller
  - `app/controllers/chats_controller.rb`
  - `app/controllers/chats/messages_controller.rb`
  - `app/controllers/posts_controller.rb`
- view
  - `app/views/chats/index.html.erb`
  - `app/views/chats/new.html.erb`
  - `app/views/chats/show.html.erb`
  - `app/views/timeline/_post_rows.html.erb`
  - `app/views/my/posts/show.html.erb`
- test
  - `test/integration/chats_flow_test.rb`
  - 既存の `timeline_flow` / `my_posts_flow` も更新

## 完了条件に対する結果
- [x] 投稿からチャット開始できる。
- [x] 同一投稿×同一相手でroomが重複しない。
- [x] 作成後（再利用時含む）にチャット詳細へ遷移できる。

## 追記（Issue #144: 連投不可と交互送信制御）
- `app/models/chatroom.rb`
  - `sendable_by?(user)` を追加し、直前メッセージ送信者と現在ユーザーが同一なら送信不可と判定する。
  - `start_with_message!` は「room確保 + 初回メッセージ作成」をトランザクションで扱い、メッセージ作成は `ChatMessage.create_in_room!` に委譲する。
- `app/models/chat_message.rb`
  - `create_in_room!(chatroom:, user:, body:)` を追加し、`chatroom.with_lock` による直列化付きで保存する。
  - `validate :prevent_consecutive_send` を追加し、`chatroom.sendable_by?(user)` が `false` の場合は保存不可にした。
  - これにより `POST /posts/:post_id/chat` と `POST /chats/:chat_id/messages` の両経路を同一ロジックで防御する。
- `app/controllers/chats_controller.rb` / `app/controllers/chats/messages_controller.rb`
  - 非参加者アクセス時（`RecordNotFound`）は `timeline` へリダイレクトする。
- `app/views/chats/show.html.erb` / `app/views/chats/_composer_form.html.erb`
  - 送信不可時にフォーム上へ理由と制約説明を表示し、textarea/送信ボタン/フォーム外観を無効状態で表示するUIを追加した。
- `app/views/chats/_heading_with_help.html.erb` / `app/views/chats/index.html.erb` / `app/views/chats/show.html.erb` / `app/views/chats/new.html.erb`
  - 見出し横にヘルプマークを追加し、ホバー/フォーカス時に「荒らし防止のため交互返信方式」であることを説明するポップアップを追加した。
- `test/integration/chats_flow_test.rb`
  - 初回送信導線での連投不可、相手送信後の再送可、送信不可理由のUI表示、非参加者アクセス時のリダイレクトを検証するテストを追加した。
