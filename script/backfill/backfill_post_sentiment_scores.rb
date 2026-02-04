# script/backfill_post_sentiment_scores.rb
# frozen_string_literal: true

# ---------- 使用コマンド例 ----------
# *試運転（更新しない）
# DRY_RUN=1 bin/rails runner script/backfill_post_sentiment_scores.rb

# *本番
# bin/rails runner script/backfill_post_sentiment_scores.rb
#------------------------------------

DRY_RUN = ENV["DRY_RUN"].present?

puts "[backfill] start DRY_RUN=#{DRY_RUN}"

analyzer = Mecab::Analyzer.new

total = Post.count
done = 0

Post.order(:id).each do |post|
  tokens = analyzer.tokens(post.body)
  score  = SENTIMENT_SCORER.score_tokens(tokens)[:mean].to_f

  post.update_columns(sentiment_score: score, updated_at: Time.current) unless DRY_RUN

  done += 1
  puts "[backfill] posts=#{done}/#{total}" if (done % 500).zero?
end

puts "[backfill] done posts=#{done}/#{total}"
