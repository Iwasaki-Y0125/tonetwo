class AddRoleToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :role, :string, null: false, default: "member"
    add_check_constraint :users,
                         "role IN ('member', 'admin')",
                         name: "check_users_role"
  end
end
