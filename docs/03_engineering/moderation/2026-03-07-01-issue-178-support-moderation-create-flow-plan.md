# Issue #178 実装メモ: support導線判定とcreate責務の整理

## 目的
- `Post` / `ChatMessage` の support / prohibit 判定重複を減らす。
- validation 副作用に依存した support 判定を段階的に整理する。
- 最終的に controller が support 判定結果の解釈を持ちすぎない構成へ寄せる。

## 現在の結論
- 第1段階として、support / prohibit / ok の判定だけを [support_prohibit_checker.rb](../../../app/services/moderation/support_prohibit_checker.rb) に共通化した。
- [post.rb](../../../app/models/post.rb) と [chat_message.rb](../../../app/models/chat_message.rb) は、この checker の戻り値を使って validation エラーを積む形へ置き換えた。
- chat 送信フローの service 化は試したが、読みづらさが増したため採用しなかった。現在は controller に戻している。
- `support_required?` と controller 側の redirect 判定はまだ残している。create フロー全体の責務整理は未完了。

## ローカル根拠
- 依存:
  - [Gemfile.lock](../../../Gemfile.lock) では Rails は `8.1.2`
- 実装:
  - [support_prohibit_checker.rb](../../../app/services/moderation/support_prohibit_checker.rb)
  - [post.rb](../../../app/models/post.rb)
  - [chat_message.rb](../../../app/models/chat_message.rb)
  - [filter_term.rb](../../../app/models/filter_term.rb)
  - [posts_controller.rb](../../../app/controllers/posts_controller.rb)
  - [chats_controller.rb](../../../app/controllers/chats_controller.rb)
  - [messages_controller.rb](../../../app/controllers/chats/messages_controller.rb)
- テスト:
  - [support_prohibit_checker_test.rb](../../../test/services/moderation/support_prohibit_checker_test.rb)
  - [post_test.rb](../../../test/models/post_test.rb)
  - [posts_flow_test.rb](../../../test/integration/posts_flow_test.rb)
  - [chats_flow_test.rb](../../../test/integration/chats_flow_test.rb)

## 実装済み
### 1. 共通判定オブジェクトの追加
- [support_prohibit_checker.rb](../../../app/services/moderation/support_prohibit_checker.rb) を追加した。
- `Moderation::SupportProhibitChecker.call(text)` は、内部クラス `Result` を返す。
- 外部に公開する API は `ok?` / `support?` / `prohibit?` のみで、`status` は公開しない。

### 2. model の重複判定を置換
- [post.rb](../../../app/models/post.rb)
- [chat_message.rb](../../../app/models/chat_message.rb)
- 両方の `reject_filtered_terms` が checker を呼び、以下の順で分岐する。
  - `support?`
  - `prohibit?`
  - `ok?`
- support 時は従来どおり `@support_required = true` と `errors.add(:base, :invalid)` を設定する。
- prohibit 時は従来どおり本文エラーを積む。

### 3. 既存 UI フローは維持
- [posts_controller.rb](../../../app/controllers/posts_controller.rb)
- [chats_controller.rb](../../../app/controllers/chats_controller.rb)
- [messages_controller.rb](../../../app/controllers/chats/messages_controller.rb)
- これらの controller はまだ `support_required?` を見て `support_page_path` へ遷移している。
- 今回は挙動を変えず、判定重複だけを先に除去した。

### 4. chat create は service 化せず controller に残した
- [chats_controller.rb](../../../app/controllers/chats_controller.rb)
- [messages_controller.rb](../../../app/controllers/chats/messages_controller.rb)
- `Chats::DeliverMessage` のような共通 service も試したが、controller と service の両方を読まないと処理順が追えず、現時点ではかえって複雑だった。
- 現在は以下の形で止めている。
  - 初回送信: [chatroom.rb](../../../app/models/chatroom.rb) の `start_with_message!` を使う
  - 既存チャット送信: [chat_message.rb](../../../app/models/chat_message.rb) の `create_in_room!` を使う
  - support redirect 判定: 各 controller の rescue 節で `support_required?` を見る

## ここまで整理済み
1. support / prohibit 判定重複は [support_prohibit_checker.rb](../../../app/services/moderation/support_prohibit_checker.rb) に寄せた。
2. 投稿とチャットメッセージの model 側判定分岐は、`support?` / `prohibit?` / `ok?` の同じ読み順にそろえた。
3. chat controller は無理に service 化せず、処理順が追いやすい形へ戻した。

## ここから先は未着手
1. `support_required?` は依然として validation 副作用に依存している。
2. controller が support 判定結果の解釈を持っている。
3. `PostsController#create` / `ChatsController#create` / `Chats::MessagesController#create` の create フロー責務はまだ分散している。
4. `Post#prohibit_hit?` は残っており、結果オブジェクトへの寄せ先は未整理。

## 次にやるなら
### 1. 投稿 create の責務整理
- [posts_controller.rb](../../../app/controllers/posts_controller.rb) から support 判定解釈を外す。
- ただし、投稿だけのために早い段階で service を足すかは再判断が必要。

### 2. validation 副作用の撤去
- `support_required?` を controller から見なくても済む形に変えられる見通しが立ってから着手する。
- chat 側は無理に共通 service に寄せず、まずは判定の受け渡し方法だけを整理する方が安全。

## 動作確認
- 実施済みコマンド:
  - `docker compose --env-file .env.test -f docker-compose.dev.yml -f docker-compose.test.yml run --rm --workdir /app -e HOME=/tmp --user $(id -u):$(id -g) -e RAILS_ENV=test web bash -lc 'bin/rails db:drop db:create db:test:prepare && bin/rails test test/services/moderation/support_prohibit_checker_test.rb test/models/post_test.rb test/integration/posts_flow_test.rb test/integration/chats_flow_test.rb'`
- 実施済み結果:
  - 32 tests, 0 failures
- 追加で複数回実施した確認:
  - `test/services/moderation/support_prohibit_checker_test.rb`
  - `test/models/post_test.rb`
  - `test/integration/posts_flow_test.rb`
  - `test/integration/chats_flow_test.rb`

## 参考
- 関連 docs:
  - [README](../../../README.md)
  - [テスト方針（Minitest運用）](../testing/2026-02-08-01-testing-policy-minitest.md)
  - [Issue #24 実装記録: 投稿からチャット開始（room作成）](../chat/2026-02-19-01-post-to-chatroom-implementation-plan.md)
  - [FilterTerms運用手順（MVP）](../../04_operations/moderation/2026-02-12-01-filter-terms-mvp-ops.md)
- 公式一次ソース:
  - [Rails Guides: Active Record Validations](https://guides.rubyonrails.org/active_record_validations.html)
  - [Rails Guides: Testing Rails Applications](https://guides.rubyonrails.org/testing.html)
