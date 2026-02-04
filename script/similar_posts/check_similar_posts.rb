# frozen_string_literal: true

# 使い方:
# DEBUG=1 TEXT="アマプラ見た" bin/rails runner script/check_similar_posts.rb

# 入力:
#   TEXT  : 投稿本文（最大140文字）
#   LIMIT : 類似投稿の表示件数（省略時10）
#   DEBUG : 1 のとき詳細ログ（tokens/nouns/hits）を出す

MAX_LEN = 140
DEFAULT_SIMILAR_POSTS_LIMIT = 10
DEFAULT_TEXT = "今日は映画を観た。カレー食べたい。仕事が忙しい。".freeze

text  = (ENV["TEXT"] || DEFAULT_TEXT).to_s
limit = (ENV["LIMIT"] || DEFAULT_SIMILAR_POSTS_LIMIT).to_i
debug = ENV["DEBUG"] == "1"

raise "TEXT is too long (max #{MAX_LEN})" if text.length > MAX_LEN

# -------------------------
# 1) 投稿作成 => 解析前の状態で保存
# -------------------------
user = User.first || User.create!(email: "dev@example.com")
post = Post.create!(user_id: user.id, body: text)

puts "[created] post_id=#{post.id} user_id=#{user.id} body=#{post.body.inspect}"

# -------------------------
# 2) 解析＆保存（サービスクラスに委譲）
# -------------------------
begin
  r = Posts::AnalyzePost.call(post_id: post.id)

  if debug
    tokens = r[:tokens] || []
    nouns  = r[:nouns]  || []
    result = r[:sentiment] || {}
    score  = r[:score].to_f

    puts "[tokens] size=#{tokens.size}"
    puts "[nouns] count=#{nouns.size}"
    puts "  nouns=#{nouns.join(', ')}"

    counts = result[:counts] || {}
    puts "[sentiment] mean=#{score} total=#{result[:total]} matched=#{counts[:matched]} "\
          "pos=#{counts[:pos]} neg=#{counts[:neg]} neu=#{counts[:neu]}"

    puts "-- HITS (top 10)"
    (result[:hits] || []).first(10).each do |h|
      puts "  [i=#{h[:i]}] type=#{h[:type]} phrase=#{h[:phrase]} "\
            "raw=#{h[:raw]} applied=#{h[:applied]} negated=#{h[:negated]}"
    end

    puts "-- HITS (last 5)"
    (result[:hits] || []).last(5).each do |h|
      puts "  [i=#{h[:i]}] type=#{h[:type]} phrase=#{h[:phrase]} "\
            "raw=#{h[:raw]} applied=#{h[:applied]} negated=#{h[:negated]}"
    end
  end

  puts "[saved] score=#{Post.find(post.id).sentiment_score} post_terms=#{PostTerm.where(post_id: post.id).count}"
rescue => e
  puts "[analysis] ERROR: #{e.class}: #{e.message}"
  puts "[analysis] post remains: post_id=#{post.id} sentiment_score=#{post.sentiment_score}"
end

# -------------------------
# 3) 類似投稿検索 => レコメンド表示
# -------------------------
relation = Posts::SimilarPostsQuery.call(post_id: post.id, limit: limit).load
puts "\n[similar_posts] count=#{relation.size}"

relation.each_with_index do |p, i|
  overlap = p.attributes["overlap"]
  puts format(
    "  #%02d id=%s overlap=%s score=%s created_at=%s body=%s",
    i + 1, p.id, overlap, p.sentiment_score, p.created_at, p.body.inspect
  )
end
