# frozen_string_literal: true

require "bundler"

def licenses_of(spec)
  arr =
    if spec.respond_to?(:licenses) && spec.licenses&.any?
      spec.licenses
    elsif spec.respond_to?(:license) && spec.license
      [ spec.license ]
    else
      []
    end

  arr.map(&:to_s).reject(&:empty?).uniq
end

# 本番配布物に含まれる依存（default group）のみを対象にする。
specs = Bundler.definition.specs_for([ :default ]).sort_by(&:name)

puts "# RubyGems ライセンス一覧\n\n"
puts "各gemのライセンス本文および著作権表示は、ホームページ列のリンク先リポジトリにてご確認いただけます。\n\n"
puts "最終更新日時: #{Time.now}\n\n"

puts "| Gem | Version | License | Homepage |"
puts "|---|---:|---|---|"

specs.each do |spec|
  lic = licenses_of(spec)
  lic = [ "(unknown)" ] if lic.empty?

  name = spec.name
  ver  = spec.version.to_s
  hp   = spec.homepage.to_s

  puts "| #{name} | #{ver} | #{lic.join(", ")} | #{hp} |"
end
