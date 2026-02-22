require "digest"

# todoリファクタしてない。後日やる。

module Policies
  module PolicyDocuments
    PolicyFile = Data.define(:name, :title, :path)
    GEMS_LICENSES_PATH = Rails.root.join("docs/80_licenses/gems.md")

    POLICY_FILES = {
      terms: PolicyFile.new(
        name: :terms,
        title: "利用規約",
        path: Rails.root.join("app/views/pages/policies/terms.md")
      ),
      privacy: PolicyFile.new(
        name: :privacy,
        title: "プライバシーポリシー",
        path: Rails.root.join("app/views/pages/policies/privacy.md")
      ),
      licenses: PolicyFile.new(
        name: :licenses,
        title: "サードパーティーライセンス",
        path: Rails.root.join("docs/80_licenses/third_party_notices.md")
      )
    }.freeze

    module_function

    # 指定したポリシー文書を読み込んで内容をハッシュで返す。
    def fetch!(name)
      policy = POLICY_FILES.fetch(name.to_sym)
      markdown = File.read(policy.path, encoding: "UTF-8")
      markdown = compose_licenses_markdown(markdown) if policy.name == :licenses

      {
        name: policy.name,
        title: policy.title,
        markdown: markdown,
        version: version_for(markdown),
        updated_at: File.mtime(policy.path)
      }
    rescue Errno::ENOENT => e
      raise KeyError, "Policy file is missing: #{e.message}"
    end

    # ライセンス表記のMarkdownに、RubyGemsのApache系gemのLICENSE/NOTICE本文と実行環境同梱のライセンス情報を追記して返す。
    def compose_licenses_markdown(base_markdown)
      gems_markdown = File.read(GEMS_LICENSES_PATH, encoding: "UTF-8")
      apache_gems_markdown = LicensesMarkdownBuilder.build_apache_rubygems_markdown
      runtime_markdown = LicensesMarkdownBuilder.build_runtime_licenses_markdown
      "#{base_markdown}\n\n---\n\n#{gems_markdown}\n\n---\n\n#{apache_gems_markdown}\n\n---\n\n#{runtime_markdown}"
    end

    # 規約本文の内容ハッシュを版として保存する。
    def terms_version
      fetch!(:terms)[:version]
    end

    # 規約本文の内容ハッシュを版として保存する。
    def privacy_version
      fetch!(:privacy)[:version]
    end

    # Markdownテキストの内容を正規化してハッシュ化し、Ver.として扱う。
    def version_for(markdown)
      normalized = markdown.to_s.gsub(/\r\n?/, "\n")
      "sha256-#{Digest::SHA256.hexdigest(normalized).first(12)}"
    end
  end
end
