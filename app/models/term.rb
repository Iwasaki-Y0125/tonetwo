class Term < ApplicationRecord
  # 抽出語は表記揺れを避けるため前後空白を除去して保存する。
  normalizes :term, with: ->(value) { value&.strip }

  has_many :post_terms, dependent: :delete_all

  validates :term, presence: true, uniqueness: true
end
