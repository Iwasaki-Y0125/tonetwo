# frozen_string_literal: true

require "optparse"
require "securerandom"

abort "[seed] RAILS_ENV=production を明示して実行してください" unless ENV["RAILS_ENV"] == "production"

require_relative "../../config/environment"

module Seeds
  class MarkdownPostsImporter
    DEFAULT_INPUT_PATH = Rails.root.join("db/seeds/post.md").to_s
    DEFAULT_USERS = 1
    POSITIVE_LABEL = "pos"
    NEGATIVE_LABEL = "neg"
    SAMPLE_PREFIX = "[#運営サンプル] "

    def initialize(input_path:, users_count:)
      @input_path = input_path
      @users_count = users_count
      @now = Time.current
      @analyzer = Mecab::Analyzer.new
      @noun_extractor = Mecab::NounExtractor.new(analyzer: @analyzer)
    end

    def run!
      posts = parse_posts(@input_path)
      validate_posts!(posts)

      users = upsert_seed_users!(@users_count)
      user_ids = users.map(&:id)

      created = 0
      reused = 0

      posts.each_with_index do |body, idx|
        body = body.start_with?(SAMPLE_PREFIX) ? body : "#{SAMPLE_PREFIX}#{body}"
        user_id = user_ids[idx % user_ids.length]
        post = Post.find_by(user_id: user_id, body: body)

        if post
          reused += 1
        else
          post_id = Post.insert_all!(
            [ { user_id: user_id, body: body, created_at: @now + idx.seconds, updated_at: @now + idx.seconds } ],
            returning: %w[id]
          ).rows.first.first
          post = Post.find(post_id)
          created += 1
        end

        analyze_and_persist!(post)
      end

      puts "[seed] input_posts=#{posts.size}"
      puts "[seed] users=#{users.size}"
      puts "[seed] created_posts=#{created}"
      puts "[seed] reused_posts=#{reused}"
    end

    private

    def parse_posts(path)
      abort "[seed] input file not found: #{path}" unless File.exist?(path)

      source = File.read(path, encoding: "UTF-8")
      source
        .each_line
        .filter_map do |line|
          match = line.match(/^\s*\d+\.\s+(.+?)\s*$/)
          match && match[1]
        end
    end

    def validate_posts!(posts)
      raise "[seed] posts is empty" if posts.empty?

      too_long = posts.each_with_index.filter_map { |body, idx| [ idx + 1, body.length ] if body.length > 140 }
      return if too_long.empty?

      details = too_long.map { |row_no, len| "line=#{row_no} length=#{len}" }.join(", ")
      raise "[seed] post length exceeds 140: #{details}"
    end

    def upsert_seed_users!(count)
      raise "[seed] users must be >= 1" if count < 1

      rows = (1..count).map do |i|
        {
          email_address: "mdseed-#{i.to_s.rjust(3, '0')}@example.invalid",
          # seedユーザーは再現可能な固定パスワードを使わず、推測困難な値を毎回生成する。
          password_digest: BCrypt::Password.create(SecureRandom.urlsafe_base64(48)),
          terms_accepted_at: @now,
          privacy_accepted_at: @now,
          terms_version: User.current_terms_version,
          privacy_version: User.current_privacy_version,
          created_at: @now,
          updated_at: @now
        }
      end
      User.upsert_all(rows, unique_by: :index_users_on_email_address)

      User.where(email_address: rows.map { |r| r[:email_address] }).order(:email_address)
    end

    def analyze_and_persist!(post)
      text = post.body.to_s
      tokens = @analyzer.tokens(text)
      nouns = @noun_extractor.call(text).map(&:to_s).map(&:strip).reject(&:empty?).uniq
      result = SENTIMENT_SCORER.score_tokens(tokens)

      score = result.fetch(:mean).to_f
      label = score >= 0 ? POSITIVE_LABEL : NEGATIVE_LABEL

      # support/prohibit 検証に影響させず解析結果だけ確定する。
      post.update_columns(sentiment_score: score, sentiment_label: label, updated_at: Time.current)
      Posts::TermsUpserter.call(post_id: post.id, terms: nouns)
    end
  end
end

options = {
  input: Seeds::MarkdownPostsImporter::DEFAULT_INPUT_PATH,
  users: Seeds::MarkdownPostsImporter::DEFAULT_USERS
}

OptionParser.new do |opts|
  opts.banner = "Usage: ruby script/seeds/import_posts_from_markdown.rb [options]"
  opts.on("-i", "--input PATH", "Input markdown path (default: db/seeds/post.md)") { |v| options[:input] = v }
  opts.on("-u", "--users N", Integer, "Number of seed users (default: 1)") { |v| options[:users] = v }
end.parse!

Seeds::MarkdownPostsImporter.new(input_path: options[:input], users_count: options[:users]).run!
