# frozen_string_literal: true

require "bundler/setup"
require_relative "../../config/environment"
require_relative "mecab_samples"

# 動作確認 ==============================
# $ make exec
# $ ruby script/mecab/mecab_test_tokens_cases.rb > tmp/mecab/mecab_tokens_cases.log
# ======================================

# MeCabの動作確認用スクリプト（複数ケース版）

cases = MecabSamples::SAMPLES

analyzer = Mecab::Analyzer.new

cases.each do |t|
  puts "\n---\n#{t}"
  # pp は pretty print で、配列やHashを 見やすく整形して表示するメソッド
  pp analyzer.tokens(t)
end
