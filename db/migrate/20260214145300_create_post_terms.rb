class CreatePostTerms < ActiveRecord::Migration[8.1]
  def change
    create_table :post_terms do |t|
      t.references :post, null: false, foreign_key: true
      t.references :term, null: false, foreign_key: true

      t.timestamps
    end

    add_index :post_terms,
      %i[post_id term_id],
      unique: true,
      name: "index_post_terms_on_post_id_and_term_id"

    add_index :post_terms,
      %i[term_id post_id],
      name: "index_post_terms_on_term_id_and_post_id"
  end
end
