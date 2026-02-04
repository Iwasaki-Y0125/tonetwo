# frozen_string_literal: true

# 動作確認 ==============================
# $ make exec
# ターミナルで確認:
#   $ bin/rails runner script/sentiment/sentiment_test_score_cases.rb
#
# 結果をログに吐く:
#   $ bin/rails runner script/sentiment/sentiment_test_score_cases.rb > tmp/sentiment/sentiment_score_cases.log
# ======================================

# rails runner 経由でも ruby 直実行でも動くようにしておく
unless defined?(Rails)
  require_relative "../../config/environment"
end

# Mecab::Analyzer と SENTIMENT_SCORER が存在する前提
analyzer = Mecab::Analyzer.new

samples = [
  "最高！",
  "最高じゃない",
  "嫌いじゃない",
  "良いと思う",
  "良くない",
  "うれしい",
  "うれしくない",
  "まずい",
  "おいしくない",
  "これは微妙…",
  "最悪",
  "最悪ではない",
  "楽しい",
  "楽しくない",
  "買い得です",
  "鼻持ちならない",
  "仕事つらい",
  "仕事つらくない",
  "すごく良かった",
  "全然良くない"
]

def short_token(t)
  "#{t[:surface]}(base=#{t[:base]},pos=#{t[:pos]})"
end

samples.each do |text|
  tokens = analyzer.tokens(text)
  result = SENTIMENT_SCORER.score_tokens(tokens)

  norm_terms = tokens.map do |t|
    base = t[:base].to_s
    surf = t[:surface].to_s
    base.empty? || base == "*" ? surf : base
  end

  puts "=================================================="
  puts "TEXT: #{text}"
  puts "TOKENS: " + tokens.map { |t| short_token(t) }.join(" | ")
  puts "NORM_TERMS: " + norm_terms.join(" | ")
  puts "USER.PN: \t" + norm_terms.join(" ")

  puts "SCORE: total=#{result[:total]} mean=#{result[:mean]} "\
       "matched=#{result.dig(:counts, :matched)} "\
       "pos=#{result.dig(:counts, :pos)} neg=#{result.dig(:counts, :neg)} neu=#{result.dig(:counts, :neu)}"

  puts "-- HITS"
  result[:hits].each do |h|
    puts "  [i=#{h[:i]}] type=#{h[:type]} phrase=#{h[:phrase]} "\
         "raw=#{h[:raw]} applied=#{h[:applied]} negated=#{h[:negated]}"
  end
end
