# script/backfill/backfill_post_sentiment_scores.rb
# frozen_string_literal: true

# ---------- 使用コマンド例 ----------
# *試運転（更新しない）
# DRY_RUN=1 BATCH=500 bin/rails runner script/backfill/backfill_post_sentiment_scores.rb

# *本番
# BATCH=500 bin/rails runner script/backfill/backfill_post_sentiment_scores.rb

# *途中から再開するとき
# FROM_ID=10001 BATCH=500 bin/rails runner script/backfill/backfill_post_sentiment_scores.rb
#------------------------------------

BATCH = ENV.fetch("BATCH", "500").to_i
FROM_ID = ENV["FROM_ID"].presence&.to_i
TO_ID   = ENV["TO_ID"].presence&.to_i
DRY_RUN = ENV["DRY_RUN"].present?
POSITIVE_LABEL = "pos"
NEGATIVE_LABEL = "neg"

puts "[backfill] start BATCH=#{BATCH} FROM_ID=#{FROM_ID.inspect} TO_ID=#{TO_ID.inspect} DRY_RUN=#{DRY_RUN}"

analyzer = Mecab::Analyzer.new

scope = Post.order(:id)
scope = scope.where("id >= ?", FROM_ID) if FROM_ID
scope = scope.where("id <= ?", TO_ID) if TO_ID

total = scope.count
done = 0

scope.in_batches(of: BATCH) do |rel|
  now = Time.current
  rel.pluck(:id, :body).each do |post_id, body|
    tokens = analyzer.tokens(body)
    score = SENTIMENT_SCORER.score_tokens(tokens)[:mean].to_f
    label = score >= 0 ? POSITIVE_LABEL : NEGATIVE_LABEL

    unless DRY_RUN
      Post.where(id: post_id).update_all(
        sentiment_score: score,
        sentiment_label: label,
        updated_at: now
      )
    end

    done += 1
  end
  puts "[backfill] posts=#{done}/#{total}"
end

puts "[backfill] done posts=#{done}/#{total}"
