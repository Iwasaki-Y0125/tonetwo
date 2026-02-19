class CreateChatMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :chat_messages do |t|
      t.references :chatroom, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false

      t.timestamps
    end

    # bodyは空白のみの投稿を許可しない
    add_check_constraint :chat_messages,
      "char_length(trim(both from body)) > 0",
      name: "chk_chat_messages_body_not_blank"

    # bodyは140文字以内
    add_check_constraint :chat_messages,
      "char_length(body) <= 140",
      name: "chk_chat_messages_body_max_140"

    # チャットルーム内のメッセージを作成順に効率的に取得できるようにするための複合インデックス
    add_index :chat_messages, %i[chatroom_id created_at id], name: "index_chat_messages_on_chatroom_created_at_id"
  end
end
