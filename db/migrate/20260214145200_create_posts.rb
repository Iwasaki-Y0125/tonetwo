class CreatePosts < ActiveRecord::Migration[8.1]
  def change
    create_table :posts do |t|
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false
      t.float :sentiment_score
      t.string :sentiment_label

      t.timestamps
    end

    add_check_constraint :posts,
      "char_length(trim(both from body)) > 0",
      name: "chk_posts_body_not_blank"

    add_check_constraint :posts,
      "char_length(body) <= 140",
      name: "chk_posts_body_max_140"

    add_check_constraint :posts,
      "sentiment_label IS NULL OR sentiment_label IN ('pos', 'neg')",
      name: "chk_posts_sentiment_label_valid"

    add_index :posts, %i[user_id created_at], name: "index_posts_on_user_id_and_created_at"
  end
end
