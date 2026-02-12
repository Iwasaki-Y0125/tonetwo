class ChangeFilterTermActionRejectToProhibit < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE filter_terms
      SET action = 'prohibit'
      WHERE action = 'reject'
    SQL

    remove_check_constraint :filter_terms, name: "chk_filter_terms_action_valid"
    change_column_default :filter_terms, :action, from: "reject", to: "prohibit"
    add_check_constraint :filter_terms,
      "action in ('prohibit', 'support')",
      name: "chk_filter_terms_action_valid"
  end

  def down
    execute <<~SQL.squish
      UPDATE filter_terms
      SET action = 'reject'
      WHERE action = 'prohibit'
    SQL

    remove_check_constraint :filter_terms, name: "chk_filter_terms_action_valid"
    change_column_default :filter_terms, :action, from: "prohibit", to: "reject"
    add_check_constraint :filter_terms,
      "action in ('reject', 'support')",
      name: "chk_filter_terms_action_valid"
  end
end
