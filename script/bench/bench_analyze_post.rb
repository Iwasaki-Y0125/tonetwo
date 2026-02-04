# frozen_string_literal: true

# 使い方
# make exec
# N=200 bin/rails runner script/bench_analyze_post.rb

require "benchmark"
require_relative "./_bench_logger"

N     = (ENV["N"] || 200).to_i
WARM  = (ENV["WARM"] || 20).to_i
TEXT  = (ENV["TEXT"] || "カレー食べたい。仕事が忙しい。").to_s

def ms(sec) = (sec * 1000.0)

user = User.first || User.create!(email: "dev@example.com")

times = []

# warmup
WARM.times do
  post = Post.create!(user_id: user.id, body: TEXT)
  Posts::AnalyzePost.call(post_id: post.id)
end

N.times do
  post = Post.create!(user_id: user.id, body: TEXT)

  t = Benchmark.realtime do
    Posts::AnalyzePost.call(post_id: post.id)
  end

  times << ms(t)
end

times.sort!
avg = times.sum / times.size
p50 = times[(times.size * 0.50).floor]
p95 = times[(times.size * 0.95).floor]
p99 = times[(times.size * 0.99).floor]

puts "[bench_analyze_post] N=#{times.size}"
puts format("  avg=%.2fms p50=%.2fms p95=%.2fms p99=%.2fms max=%.2fms",
            avg, p50, p95, p99, times.last)

BenchLogger.with_log(
  prefix: "bench_analyze_post",
  meta: { n: times.size, warm: WARM, text_len: TEXT.length }
) do |f|
  f.puts "[bench_analyze_post] N=#{times.size}"
  f.puts format("  avg=%.2fms p50=%.2fms p95=%.2fms p99=%.2fms max=%.2fms",
                avg, p50, p95, p99, times.last)
end
