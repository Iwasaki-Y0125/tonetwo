class CreateMatchingExclusionTerms < ActiveRecord::Migration[8.1]
  def change
    create_table :matching_exclusion_terms do |t|
      t.string :term, null: false

      t.timestamps
    end

    add_check_constraint :matching_exclusion_terms,
      "char_length(trim(both from term)) > 0",
      name: "chk_matching_exclusion_terms_term_not_blank"

    add_index :matching_exclusion_terms,
      :term,
      unique: true,
      name: "index_matching_exclusion_terms_on_term"
  end
end
