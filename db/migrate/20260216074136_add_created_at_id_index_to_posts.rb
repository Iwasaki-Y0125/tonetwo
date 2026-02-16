class AddCreatedAtIdIndexToPosts < ActiveRecord::Migration[8.1]
  def change
    add_index :posts, %i[created_at id], name: "index_posts_on_created_at_and_id"
  end
end
