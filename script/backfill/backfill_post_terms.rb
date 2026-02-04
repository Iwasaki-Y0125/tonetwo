# script/backfill_post_terms.rb
# frozen_string_literal: true

# ---------- 使用コマンド例 ----------
# make exec

# *試運転
# DRY_RUN=1 BATCH=500 bin/rails runner script/backfill_post_terms.rb

# *本番
# BATCH=500 bin/rails runner script/backfill_post_terms.rb

# *途中から再開するとき
# FROM_ID=10001 BATCH=500 bin/rails runner script/backfill_post_terms.rb

#------------------------------------

# Set : 集合を作る標準ライブラリ。要素間の順序がない。重複も存在しない。
# 集合は配列よりも重複削除の処理が早い。.to_aで最終的に配列に戻して使うことが多い。
require "set"

BATCH = ENV.fetch("BATCH", "500").to_i
FROM_ID = ENV["FROM_ID"]&.to_i
TO_ID   = ENV["TO_ID"]&.to_i
DRY_RUN = ENV["DRY_RUN"].present?

puts "[backfill] start BATCH=#{BATCH} FROM_ID=#{FROM_ID.inspect} TO_ID=#{TO_ID.inspect} DRY_RUN=#{DRY_RUN}"

extractor = Mecab::NounExtractor.new

scope = Post.order(:id)
scope = scope.where("id >= ?", FROM_ID) if FROM_ID
scope = scope.where("id <= ?", TO_ID) if TO_ID

total = scope.count
done = 0

scope.in_batches(of: BATCH) do |rel|
  rows = rel.pluck(:id, :body) # [[post_id, body], ...]
  now = Time.current

  # 1) 名詞抽出（postごと / バッチ全体）
  noun_by_post = {}
  all_terms = Set.new

  rows.each do |post_id, body|
    nouns = extractor.call(body).uniq
    noun_by_post[post_id] = nouns
    nouns.each { |t| all_terms << t }
  end

  terms = all_terms.to_a

  # 2) termsテーブルに未登録のtermsをupsert（ON CONFLICT DO NOTHING）
  term_id_map = {}
  if terms.any?
    existing_terms = Term.where(term: terms).pluck(:term, :id).to_h
    new_terms = terms - existing_terms.keys

    unless DRY_RUN
      if new_terms.any?
        Term.insert_all(
          new_terms.map { |t| { term: t, created_at: now, updated_at: now } },
          unique_by: :index_terms_on_term
        )
      end
    end

    # insert後に取り直して idマップを完成させる ( "映画" -> 1 )
    term_id_map = Term.where(term: terms).pluck(:term, :id).to_h
  end

  # 3) post_termsテーブルへinsert（ON CONFLICT DO NOTHING）
  join_rows = []
  # noun_by_post 例: 1 => ["映画", "猫"]
  noun_by_post.each do |post_id, nouns|
    nouns.each do |t|
      term_id = term_id_map[t]
      raise "Missing term_id: term=#{t.inspect} post_id=#{post_id}" unless term_id
      join_rows << { post_id: post_id, term_id: term_id, created_at: now, updated_at: now }
    end
  end

  unless DRY_RUN
    if join_rows.any?
      PostTerm.insert_all(join_rows, unique_by: :index_post_terms_on_post_id_and_term_id)
    end
  end

  done += rows.size
  puts "[backfill] posts=#{done}/#{total} batch_terms=#{terms.size} insert_post_terms=#{join_rows.size}"
end

puts "[backfill] done"
