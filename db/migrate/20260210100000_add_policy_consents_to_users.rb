class AddPolicyConsentsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :terms_accepted_at, :datetime, null: false
    add_column :users, :terms_version, :string, null: false
    add_column :users, :privacy_accepted_at, :datetime, null: false
    add_column :users, :privacy_version, :string, null: false

    # 空文字を防ぐためのチェック制約を追加
    add_check_constraint :users,
                         "char_length(trim(terms_version)) > 0",
                         name: "chk_users_terms_version_not_blank"
    add_check_constraint :users,
                         "char_length(trim(privacy_version)) > 0",
                         name: "chk_users_privacy_version_not_blank"
  end
end
