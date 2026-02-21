class AddMessageStateToChatrooms < ActiveRecord::Migration[8.1]
  def change
    # 直近の送信者を保持して「返信待ち」判定に使う
    add_reference :chatrooms, :last_sender, foreign_key: { to_table: :users }

    # 受信側に未読があるかどうかを保持する
    add_column :chatrooms, :has_unread, :boolean, null: false, default: false
  end
end
