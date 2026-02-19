class CreateChatrooms < ActiveRecord::Migration[8.1]
  def change
    create_table :chatrooms do |t|
      t.references :post, null: false, foreign_key: true
      t.references :reply_user, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    # 同一ユーザーが同一投稿に対して複数のチャットルームを作成できないようにする
    add_index :chatrooms, %i[post_id reply_user_id], unique: true, name: "index_chatrooms_on_post_id_and_reply_user_id"
  end
end
