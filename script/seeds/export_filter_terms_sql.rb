# frozen_string_literal: true

# ツール概要:
# ローカルseed定義から `filter_terms` 用の冪等SQLを生成する。
# - 入力: `db/seeds/filter_terms.local.rb`
# - 出力: INSERT ... ON CONFLICT ... DO UPDATE のSQL
#
# 使い方:
#   # 標準出力にSQLを出す
#   ruby script/seeds/export_filter_terms_sql.rb

#   # SQLをファイルに保存する
#   ruby script/seeds/export_filter_terms_sql.rb -o /tmp/filter_terms.sql

#   # 入力seedファイルを明示してSQLをファイルに保存する
#   ruby script/seeds/export_filter_terms_sql.rb -i db/seeds/filter_terms.local.rb -o /tmp/filter_terms.sql

require "optparse"

ROOT_DIR = File.expand_path("../..", __dir__)
DEFAULT_INPUT_PATH = File.join(ROOT_DIR, "db/seeds/filter_terms.local.rb")

def parse_percent_w_array(source, variable_name)
  match = source.match(/^\s*#{Regexp.escape(variable_name)}\s*=\s*%w\[\n(?<body>.*?)^\s*\]\s*$/m)
  raise "Could not parse #{variable_name} as %w[] array" unless match

  match[:body]
    .lines
    .map(&:strip)
    .reject(&:empty?)
end

def parse_string_array(source, variable_name)
  match = source.match(/^\s*#{Regexp.escape(variable_name)}\s*=\s*\[\n(?<body>.*?)^\s*\]\s*$/m)
  raise "Could not parse #{variable_name} as string array" unless match

  match[:body]
    .scan(/"((?:\\.|[^"\\])*)"/)
    .flatten
    .map { |value| value.gsub("\\\"", "\"").gsub("\\\\", "\\") }
end

def parse_optional_percent_w_array(source, variable_name)
  parse_percent_w_array(source, variable_name)
rescue StandardError
  []
end

def parse_optional_string_array(source, variable_name)
  parse_string_array(source, variable_name)
rescue StandardError
  []
end

def escape_sql_literal(value)
  value.gsub("'", "''")
end

def build_insert_values(terms, action)
  terms.map do |term|
    "('#{escape_sql_literal(term)}', '#{action}', NOW(), NOW())"
  end
end

def build_sql(terms_by_action)
  rows = []
  rows.concat(build_insert_values(terms_by_action.fetch("support"), "support"))
  rows.concat(build_insert_values(terms_by_action.fetch("prohibit"), "prohibit"))

  <<~SQL
    BEGIN;

    INSERT INTO filter_terms (term, action, created_at, updated_at)
    VALUES
      #{rows.join(",\n  ")}
    ON CONFLICT (term)
    DO UPDATE SET
      action = EXCLUDED.action,
      updated_at = NOW();

    COMMIT;
  SQL
end

options = {
  input: DEFAULT_INPUT_PATH,
  output: nil
}

OptionParser.new do |opts|
  opts.banner = "Usage: ruby script/seeds/export_filter_terms_sql.rb [options]"
  opts.on("-i", "--input PATH", "Input seed file path (default: db/seeds/filter_terms.local.rb)") { |v| options[:input] = v }
  opts.on("-o", "--output PATH", "Output SQL file path (default: STDOUT)") { |v| options[:output] = v }
end.parse!

abort "Seed file not found: #{options[:input]}" unless File.exist?(options[:input])

source = File.read(options[:input])

support_terms = (
  parse_percent_w_array(source, "support_terms") +
  parse_optional_string_array(source, "support_phrase_terms")
).uniq

prohibit_terms = (
  parse_string_array(source, "prohibit_terms") +
  parse_optional_string_array(source, "prohibit_phrase_terms") +
  parse_optional_string_array(source, "death_threat_terms")
).uniq

sql = build_sql(
  "support" => support_terms,
  "prohibit" => prohibit_terms
)

if options[:output]
  File.write(options[:output], sql)
  puts "Wrote SQL to #{options[:output]}"
else
  puts sql
end
