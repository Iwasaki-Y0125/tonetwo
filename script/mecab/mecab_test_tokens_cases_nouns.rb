# frozen_string_literal: true

require "bundler/setup"
require_relative "../../config/environment"
require_relative "mecab_samples"

# 動作確認 ==============================
# $ make exec
# $ ruby script/mecab/mecab_test_tokens_cases_nouns.rb > tmp/mecab/mecab_test_tokens_cases_nouns.log
# ======================================

# MeCabの動作確認用スクリプト（複数ケース版）

cases = MecabSamples::SAMPLES


analyzer = Mecab::Analyzer.new
extractor = Mecab::NounExtractor.new(analyzer: analyzer)

cases.each do |t|
  puts "\n---\n#{t}"
  # pp は pretty print で、配列やHashを 見やすく整形して表示するメソッド
  nouns = extractor.call(t)
  pp nouns
end
