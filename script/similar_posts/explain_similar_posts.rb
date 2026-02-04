# frozen_string_literal: true

# 使い方
# make exec
# bin/rails runner script/explain_similar_posts.rb
# POST_ID=123 LIMIT=10 bin/rails runner script/explain_similar_posts.rb

require_relative "./_bench_logger"

post_id = (ENV["POST_ID"] || Post.order(Arel.sql("RANDOM()")).pick(:id)).to_i
limit   = (ENV["LIMIT"] || 10).to_i

relation = Posts::SimilarPostsQuery.call(post_id: post_id, limit: limit)
sql = relation.to_sql

explain_sql = <<~SQL
  EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT TEXT)
  #{sql}
SQL

rows = ActiveRecord::Base.connection.exec_query(explain_sql).rows.flatten
output = +""
output << "[target] post_id=#{post_id} limit=#{limit}\n"
output << "\n--- SQL ---\n#{sql}\n"
output << "\n--- EXPLAIN (ANALYZE, BUFFERS) ---\n"
output << rows.join("\n")
output << "\n"

# stdout
puts output

# file log
BenchLogger.with_log(
  prefix: "explain_similar_posts",
  meta: { post_id: post_id, limit: limit }
) do |f|
  f.write(output)
end
