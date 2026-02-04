# frozen_string_literal: true

module Mecab
  class NounExtractor
    def initialize(analyzer: Mecab::Analyzer.new)
      @analyzer = analyzer
    end

    # text -> 名詞（表層形）配列を抽出
    def call(text)
      nouns = []

      @analyzer.tokens(text).each do |t|
        # 品詞が名詞ではなければ除外
        next unless t[:pos] == "名詞"

        surface = t[:surface]
        # ひらがな/カタカナ/漢字が1文字も無いなら除外（絵文字・顔文字・記号対策）
        next unless surface.match?(/[ぁ-んァ-ヶ一-龠]/)
        nouns << surface
      end
      nouns
    end
  end
end
