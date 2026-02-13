# frozen_string_literal: true

# おすすめ表示のマッチングで情報量が低い一般語を除外する。
matching_exclusion_terms = %w[
  私
  わたし
  ワタシ
  俺
  おれ
  オレ
  僕
  ぼく
  ボク
  自分
  じぶん
  ジブン
  ここ
  ココ
  そこ
  ソコ
  あそこ
  アソコ
  こちら
  コチラ
  そちら
  ソチラ
  これ
  コレ
  それ
  ソレ
  あれ
  アレ
  どれ
  ドレ
  こと
  もの
  とき
  ため
  よう
]

# 重複排除/べき等性対応
matching_exclusion_terms.uniq.each do |term|
  record = MatchingExclusionTerm.find_or_initialize_by(term: term)
  record.save! if record.new_record?
end
