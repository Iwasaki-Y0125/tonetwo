class CreateTerms < ActiveRecord::Migration[8.1]
  def change
    create_table :terms do |t|
      t.string :term, null: false

      t.timestamps
    end

    add_check_constraint :terms,
      "char_length(trim(both from term)) > 0",
      name: "chk_terms_term_not_blank"

    add_index :terms, :term, unique: true, name: "index_terms_on_term"
  end
end
