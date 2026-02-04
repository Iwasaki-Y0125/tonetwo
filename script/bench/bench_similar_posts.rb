# frozen_string_literal: true

# 使い方
# make exec
# N=300 LIMIT=10 bin/rails runner script/bench_similar_posts.rb

require "benchmark"
require_relative "./_bench_logger"

N     = (ENV["N"] || 200).to_i        # 試行回数
LIMIT = (ENV["LIMIT"] || 10).to_i
WARM  = (ENV["WARM"] || 20).to_i      # ウォームアップ回数

def ms(sec) = (sec * 1000.0)

ids = Post.order(Arel.sql("RANDOM()")).limit(N + WARM).pluck(:id)

# warmup
ids.first(WARM).each do |post_id|
  Posts::SimilarPostsQuery.call(post_id: post_id, limit: LIMIT).load
end

times = []
ids.drop(WARM).each do |post_id|
  t = Benchmark.realtime do
    Posts::SimilarPostsQuery.call(post_id: post_id, limit: LIMIT).load
  end
  times << ms(t)
end

times.sort!
avg = times.sum / times.size
p50 = times[(times.size * 0.50).floor]
p95 = times[(times.size * 0.95).floor]
p99 = times[(times.size * 0.99).floor]

puts "[bench_similar_posts] N=#{times.size} limit=#{LIMIT}"
puts format("  avg=%.2fms p50=%.2fms p95=%.2fms p99=%.2fms max=%.2fms",
            avg, p50, p95, p99, times.last)

BenchLogger.with_log(
  prefix: "bench_similar_posts",
  meta: { n: times.size, limit: LIMIT, warm: WARM }
) do |f|
  f.puts "[bench_similar_posts] N=#{times.size} limit=#{LIMIT}"
  f.puts format("  avg=%.2fms p50=%.2fms p95=%.2fms p99=%.2fms max=%.2fms",
                avg, p50, p95, p99, times.last)
end
