class MatchingExclusionTerm < ApplicationRecord
  # 正規化して、不要な差分登録を防ぐ。
  normalizes :term, with: ->(value) { value&.strip }

  validates :term,
            presence: { message: "を入力してください" },
            uniqueness: { message: "はすでに存在します" }
end
