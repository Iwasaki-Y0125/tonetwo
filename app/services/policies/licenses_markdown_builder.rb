# todoリファクタしてない。後日やる。

module Policies
  module LicensesMarkdownBuilder
    # コンテナに同梱した辞書系ライセンス/メタデータの参照先
    NEOLOGD_COMMIT_PATH = Pathname("/usr/local/share/mecab-third-party/metadata/neologd_commit.txt")
    NEOLOGD_TAG_PATH = Pathname("/usr/local/share/mecab-third-party/metadata/neologd_tag.txt")
    NEOLOGD_LICENSE_PATH = Pathname("/usr/local/share/mecab-third-party/licenses/neologd-license.txt")
    NEOLOGD_NOTICE_PATH = Pathname("/usr/local/share/mecab-third-party/licenses/neologd-notice.txt")
    MECAB_IPADIC_COPYRIGHT_PATH = Pathname("/usr/local/share/mecab-third-party/licenses/mecab-ipadic-copyright.txt")
    MECAB_IPADIC_UTF8_COPYRIGHT_PATH = Pathname("/usr/local/share/mecab-third-party/licenses/mecab-ipadic-utf8-copyright.txt")
    MECAB_COPYRIGHT_PATH = Pathname("/usr/share/doc/mecab/copyright")

    module_function

    # RubyGemsは一覧＋リンクを基本とし、Apache系のみLICENSE/NOTICE本文を補足表示する。
    def build_apache_rubygems_markdown
      sections = apache_rubygem_specs.map do |spec|
        license_text = read_optional_text(gem_license_path(spec.name))
        notice_text = read_optional_text(gem_notice_path(spec.name))

        # Apache系は本文/NOTICEを明示しておく（一覧＋リンク方針の補足）
        <<~MARKDOWN
          ### #{spec.name} #{spec.version}
          - Homepage: #{spec.homepage.presence || "(homepage未設定)"}
          - License: #{spec.licenses.join(", ")}

          #### LICENSE
          ```text
          #{license_text.presence || "(LICENSE 本文を取得できませんでした)"}
          ```

          #### NOTICE
          ```text
          #{notice_text.presence || "(NOTICE ファイルなし)"}
          ```
        MARKDOWN
      end

      <<~MARKDOWN
        ## RubyGems（Apache系）LICENSE / NOTICE

        #{sections.join("\n")}
      MARKDOWN
    end

    # 実行環境に同梱した辞書メタデータ・ライセンス本文を画面表示用にまとめる。
    def build_runtime_licenses_markdown
      commit = read_optional_text(NEOLOGD_COMMIT_PATH)
      tag = read_optional_text(NEOLOGD_TAG_PATH)
      neologd_license = read_optional_text(NEOLOGD_LICENSE_PATH)
      neologd_notice = read_optional_text(NEOLOGD_NOTICE_PATH)
      ipadic = read_optional_text(MECAB_IPADIC_COPYRIGHT_PATH)
      ipadic_utf8 = read_optional_text(MECAB_IPADIC_UTF8_COPYRIGHT_PATH)
      mecab = read_optional_text(MECAB_COPYRIGHT_PATH)
      natto = read_optional_text(natto_license_path)

      <<~MARKDOWN
        ### MeCab ライセンス本文（Debian パッケージ同梱）
        ```text
        #{mecab.presence || "(ライセンス本文を取得できませんでした)"}
        ```

        ### natto ライセンス本文（gem 同梱）
        ```text
        #{natto.presence || "(ライセンス本文を取得できませんでした)"}
        ```

        ### mecab-ipadic ライセンス本文（Debian パッケージ同梱）

        #### mecab-ipadic
        ```text
        #{ipadic.presence || "(ライセンス本文を取得できませんでした)"}
        ```

        #### mecab-ipadic-utf8
        ```text
        #{ipadic_utf8.presence || "(ライセンス本文を取得できませんでした)"}
        ```

        ### mecab-ipadic-NEologd
        - Tag: #{tag.presence || "(タグなし: HEAD 取得)"}
        - Commit: #{commit.presence || "(未取得)"}

        #### LICENSE
        ```text
        #{neologd_license.presence || "(LICENSE 本文を取得できませんでした)"}
        ```

        #### NOTICE
        ```text
        #{neologd_notice.presence || "(NOTICE 本文を取得できませんでした)"}
        ```
      MARKDOWN
    end

    # ファイルが無い環境でも画面生成を止めないため、nilを返してフォールバック文言に寄せる。
    def read_optional_text(path)
      return nil if path.blank? || !path.file?

      File.read(path, encoding: "UTF-8").strip
    rescue Errno::ENOENT
      nil
    end

    def natto_license_path
      spec = Gem.loaded_specs["natto"]
      return nil unless spec

      %w[LICENSE LICENSE.txt COPYING].each do |filename|
        path = Pathname(spec.full_gem_path).join(filename)
        return path if path.file?
      end

      nil
    end

    def gem_notice_path(gem_name)
      spec = Gem.loaded_specs[gem_name]
      return nil unless spec

      %w[NOTICE NOTICE.txt NOTICE.md].each do |filename|
        path = Pathname(spec.full_gem_path).join(filename)
        return path if path.file?
      end

      nil
    end

    def gem_license_path(gem_name)
      spec = Gem.loaded_specs[gem_name]
      return nil unless spec

      # gemごとに命名が揺れるため、実運用で見つかった別名も拾う。
      %w[
        APACHE-LICENSE
        MIT-LICENSE
        LICENSE
        LICENSE.txt
        LICENSE.md
        LICENCE
        LICENCE.txt
        COPYING
        COPYING.txt
      ].each do |filename|
        path = Pathname(spec.full_gem_path).join(filename)
        return path if path.file?
      end

      nil
    end

    def apache_rubygem_specs
      Gem.loaded_specs.values
        .select { |spec| apache_license?(spec) }
        .sort_by(&:name)
    end

    def apache_license?(spec)
      # "Apache-2.0" と "Apache 2.0" の両方を同一扱いにする。
      licenses = if spec.respond_to?(:licenses) && spec.licenses.present?
        spec.licenses
      elsif spec.respond_to?(:license) && spec.license.present?
        [ spec.license ]
      else
        []
      end

      licenses.map(&:to_s).any? { |license| license.match?(/apache/i) }
    end
  end
end
