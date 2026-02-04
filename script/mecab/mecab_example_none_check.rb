# *マジックコメント(コメントだけどコードの一部として解釈される)
# frozen_string_literal: true

# 以下、↑のコメントの説明
# ファイル内の文字列リテラル（コードに直書きした文字列）を変更不可にするための指示子
# Rubyのパフォーマンス最適化の一環として導入された機能
# 主な利点:
# - <<,!などでうっかり破壊的変更を防ぐ目的で使われる
# - 文字列オブジェクトの無駄な生成を防ぎ、パフォーマンスの向上やメモリ使用量の削減に寄与する
# サービスクラスやユーティリティクラスなど、頻繁に文字列操作が行われるファイルで特に有効

require "bundler/setup"
require "natto"


text = "2025年がもう終わるとかまじでビビる:;(∩´﹏`∩);: https://example.com #年末"
nm = Natto::MeCab.new
puts "-" * 60

puts "INPUT: #{text}"

puts "-" * 60
# ===============================================
# MeCabの動作確認用スクリプト
puts nm.parse(text)

puts "-" * 60
# ===============================================
# 表層形と品詞のみ抽出
puts "表層形\t品詞"
nm.parse(text) do |n|
  next if n.is_eos?
  parts   = n.feature.split(",")
  pos     = parts[0]
  puts "#{n.surface}\t#{pos}"
end

puts "-" * 60
# ===============================================
# 品詞が名詞のものだけ抽出
nouns = []
nm.parse(text) do |n|
  next if n.is_eos?
  parts   = n.feature.split(",")
  pos     = parts[0]
  nouns << n.surface if pos == "名詞"
end
p nouns
# 出力結果
# ["2025", "年", "まじ", ":;(∩´﹏`∩);:", "https", "://", "example", ".", "com", "#", "年末"]

puts "-" * 60
# ===============================================
# urlを除去
def strip_url(text)
  text.gsub(%r{(?:https?://|www\.)\S+}, "")
end
strip_url_text = strip_urls(text)

nouns = []

nm.parse(strip_url_text) do |n|
  next if n.is_eos?
  parts = n.feature.split(",")
  pos   = parts[0]
  # 除外項目
  # 品詞が名詞ではなければスキップ
  next if pos != "名詞"
  # ひらがな/カタカナ/漢字が1文字も無いなら落とす（絵文字・顔文字・記号対策）
  next unless n.surface.match?(/[ぁ-んァ-ヶ一-龠]/)
  # 数字だけはスキップ
  next if n.surface.match?(/\A\d+\z/)
  nouns << n.surface
end
p text
# 出力結果
# "2025年がもう終わるとかまじでビビる:;(∩´﹏`∩);: https://example.com #年末"
p strip_urls_text
# 出力結果
# "2025年がもう終わるとかまじでビビる:;(∩´﹏`∩);:  #年末"
p nouns
# 出力結果
# ["年", "まじ", "年末"]
