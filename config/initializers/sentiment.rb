# config/initializers/sentiment.rb
# config/initializers => Railsが起動するときに1回だけ実行される

require Rails.root.join("app/services/sentiment/lexicon/pn").to_s
require Rails.root.join("app/services/sentiment/lexicon/wago").to_s
require Rails.root.join("app/services/sentiment/scorer").to_s

# lexicon（レキシコン） = 単語リスト / 辞書

# ポジネガ辞書ディレクトリの指定
sentiment_lex_dir = ENV.fetch("SENTIMENT_LEX_DIR", "/opt/sentiment_lex")

# ビルド時にコンテナに配布(File.join)
pn_path   = File.join(sentiment_lex_dir, "pn.csv.m3.120408.trim")
wago_path = File.join(sentiment_lex_dir, "wago.121808.pn")

# レポジトリ内で管理(Rails.)
wago_user_path = Rails.root.join("sentiment_userdic/user_wago.tsv").to_s
pn_user_path = Rails.root.join("sentiment_userdic/user_pn.tsv").to_s

# パスが落ちていないかのチェック
raise "missing pn user dictionary: #{pn_user_path}" unless File.exist?(pn_user_path)
raise "missing pn base dictionary: #{pn_path}" unless File.exist?(pn_path)
raise "missing wago user dictionary: #{wago_user_path}" unless File.exist?(wago_user_path)
raise "missing wago base dictionary: #{wago_path}" unless File.exist?(wago_path)

# 辞書オブジェクトを作る
# app/services/sentiment/lexicon/pn.rb
# app/services/sentiment/lexicon/wago.rb
PN_LEX   = Sentiment::Lexicon::Pn.new([ pn_user_path, pn_path ])
WAGO_LEX = Sentiment::Lexicon::Wago.new([ wago_user_path, wago_path ], max_terms: 5)

# スコアラーを作る
# app/services/sentiment/scorer.rb
SENTIMENT_SCORER = Sentiment::Scorer.new(
  pn_lexicon: PN_LEX,
  wago_lexicon: WAGO_LEX,
  negation_window: 3
)
