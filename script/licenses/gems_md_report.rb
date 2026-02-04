# frozen_string_literal: true

require "bundler"

# Usage:
#   bundle exec ruby script/licenses/gems_md_report.rb > docs/licenses/gems.md
#
# Notes:
# - This file is auto-generated from Bundler specs in the build environment.
# - If you update gems, regenerate this file.

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

specs = Bundler.load.specs.sort_by(&:name)

puts "# RubyGems licenses (generated)\n\n"
puts "This file is auto-generated from Bundler specs in the build environment."
puts "If you update gems, regenerate this file.\n\n"
puts "- Generated at: #{Time.now}\n"
puts "- Source: Bundler specs in this environment\n\n"

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
