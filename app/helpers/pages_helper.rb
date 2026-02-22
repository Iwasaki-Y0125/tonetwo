module PagesHelper
  POLICY_ALLOWED_TAGS = %w[
    h1 h2 h3 h4 h5 h6
    p ul ol li
    strong em
    a
    code pre
    blockquote
    hr
    br
    table thead tbody tr th td
  ].freeze
  POLICY_ALLOWED_ATTRIBUTES = %w[href].freeze

  # ポリシー文書のMarkdownをHTMLに変換して安全にビューに出力するヘルパークラス

  # sanitize : 危険なHTMLを除去し、安全なタグだけを残すRailsのヘルパーメソッド
  # 自前のMdしか使わなく場合でも、うっかりミスったりするのであると安心
  def render_policy_markdown(markdown)
    html = Policies::PolicyMarkdownRenderer.render(markdown)
    sanitize(html, tags: POLICY_ALLOWED_TAGS, attributes: POLICY_ALLOWED_ATTRIBUTES)
  end
end
