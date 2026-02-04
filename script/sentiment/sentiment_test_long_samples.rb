# frozen_string_literal: true

# 長文サンプルの動作確認 ==========================
# $ make exec
# ターミナルで確認:
#   $ bin/rails runner script/sentiment/sentiment_test_long_samples.rb
#
# 結果をログに吐く:
#   $ bin/rails runner script/sentiment/sentiment_test_long_samples.rb > tmp/sentiment/sentiment_long_samples.log
# ===================================================

# rails runner 経由でも ruby 直実行でも動くようにしておく
unless defined?(Rails)
  require_relative "../../config/environment"
end

require_relative "../mecab/mecab_samples"

analyzer = Mecab::Analyzer.new
samples = MecabSamples::SAMPLES

def short_token(t)
  "#{t[:surface]}(base=#{t[:base]},pos=#{t[:pos]})"
end

def normalize_terms(tokens)
  tokens.map do |t|
    base = t[:base].to_s
    surf = t[:surface].to_s
    base.empty? || base == "*" ? surf : base
  end
end

def summarize_hits(result)
  hits = result[:hits] || []
  {
    total: result[:total],
    mean: result[:mean],
    matched: hits.length,
    pos: hits.count { |h| h[:applied].to_f > 0 },
    neg: hits.count { |h| h[:applied].to_f < 0 },
    neu: hits.count { |h| h[:applied].to_f == 0 }
  }
end

samples.each_with_index do |text, idx|
  tokens = analyzer.tokens(text)
  result = SENTIMENT_SCORER.score_tokens(tokens)

  puts "=================================================="
  puts "CASE: #{idx + 1}/#{samples.length}"
  puts "TEXT: #{text}"
  puts

  token_str = tokens.map { |t| short_token(t) }
  if token_str.length <= 30
    puts "TOKENS: " + token_str.join(" | ")
  else
    puts "TOKENS(head): " + token_str.first(15).join(" | ")
    puts "TOKENS(tail): " + token_str.last(15).join(" | ")
    puts "TOKENS(count): #{token_str.length}"
  end

  norm_terms = normalize_terms(tokens)
  if norm_terms.length <= 30
    puts "NORM_TERMS: " + norm_terms.join(" | ")
  else
    puts "NORM_TERMS(count): #{norm_terms.length}"
  end

  sum = summarize_hits(result)
  puts
  puts "SCORE: total=#{sum[:total]} mean=#{sum[:mean]} matched=#{sum[:matched]} "\
       "pos=#{sum[:pos]} neg=#{sum[:neg]} neu=#{sum[:neu]}"

  puts "-- HITS (top 10)"
  (result[:hits] || []).first(10).each do |h|
    puts "  [i=#{h[:i]}] type=#{h[:type]} phrase=#{h[:phrase]} "\
         "raw=#{h[:raw]} applied=#{h[:applied]} negated=#{h[:negated]}"
  end

  puts "-- HITS (last 5)"
  (result[:hits] || []).last(5).each do |h|
    puts "  [i=#{h[:i]}] type=#{h[:type]} phrase=#{h[:phrase]} "\
         "raw=#{h[:raw]} applied=#{h[:applied]} negated=#{h[:negated]}"
  end
end
