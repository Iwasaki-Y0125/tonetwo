class CreateFilterTerms < ActiveRecord::Migration[8.1]
  def change
    create_table :filter_terms do |t|
      t.string :term, null: false
      t.string :action, null: false, default: "prohibit"

      t.timestamps
    end

    add_check_constraint :filter_terms,
      "char_length(trim(both from term)) > 0",
      name: "chk_filter_terms_term_not_blank"

    add_check_constraint :filter_terms,
      "action in ('prohibit', 'support')",
      name: "chk_filter_terms_action_valid"

    add_index :filter_terms, :term, unique: true, name: "index_filter_terms_on_term"
  end
end
