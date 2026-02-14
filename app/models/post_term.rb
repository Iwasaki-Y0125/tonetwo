class PostTerm < ApplicationRecord
  belongs_to :post
  belongs_to :term

  validates :post_id, uniqueness: { scope: :term_id }
end
