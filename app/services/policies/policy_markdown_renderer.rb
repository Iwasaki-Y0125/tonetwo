require "commonmarker"

module Policies
  # Md形式のポリシー文書をHTMLに変換するサービスクラス
  class PolicyMarkdownRenderer
    def self.render(markdown)
      ::Commonmarker.to_html(markdown.to_s)
    end
  end
end
