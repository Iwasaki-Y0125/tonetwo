# app/services/posts/analyze_post.rb
module Posts
  class AnalyzePost
    def self.call(post_id:)
      # 1) 投稿の取得
      post = Post.find(post_id)
      text = post.body.to_s

      # 2) 形態素解析
      analyzer = Mecab::Analyzer.new
      tokens = analyzer.tokens(text)

      # 3) 名詞抽出
      nouns = Mecab::NounExtractor.new(analyzer: analyzer).call(text)
      nouns = nouns.map(&:to_s).map(&:strip).reject(&:empty?).uniq

      # 4) ポジネガ分析
      result = SENTIMENT_SCORER.score_tokens(tokens)
      score = result[:mean].to_f

      # 5) 解析結果の保存
      Post.transaction do
        post.update!(sentiment_score: score)
        Posts::TermsUpserter.call(post_id: post.id, terms: nouns)
      end

      { post: post, score: score, nouns: nouns, tokens: tokens, sentiment: result }
    end
  end
end
