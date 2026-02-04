# script/bench_noun_extractor.rb

# 使い方:
# docker compose --env-file .env.dev -f docker-compose.dev.yml \
#   exec -e HOME=/tmp --user 1000:1000 web \
#   bin/rails runner script/bench_noun_extractor.rb


require "json"
require_relative "mecab_samples"

analyzer = Mecab::Analyzer.new
extractor = Mecab::NounExtractor.new(analyzer: analyzer)

# 動作確認
text = MecabSamples::SAMPLES.first
warn "[check] sample=#{text.inspect}"
warn "[check] nouns=#{extractor.call(text).inspect}"

# 名詞抽出器のベンチマークスクリプト
def run_once(extractor, text)
  extractor.call(text)
end

SAMPLES = MecabSamples::SAMPLES

# ベンチマーク設定
WARMUP = 30
N_PER_SAMPLE = 300

# ミリ秒に変換
def ms(t) = t * 1000.0

times = []

# 予備実行
WARMUP.times do |i|
  run_once(extractor, SAMPLES[i % SAMPLES.size])
end

# 本計測
SAMPLES.each do |text|
  N_PER_SAMPLE.times do
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    run_once(extractor, text)
    t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    times << (t1 - t0)
  end
end

# 結果集計
sorted = times.sort
n = sorted.size
min = sorted.first
max = sorted.last
avg = sorted.sum / n
median = sorted[n / 2]
p95 = sorted[(n * 0.95).floor]
p99 = sorted[(n * 0.99).floor]

# 結果出力
puts({
  n: n,
  min_ms: ms(min).round(3),
  max_ms: ms(max).round(3),
  avg_ms: ms(avg).round(3),
  median_ms: ms(median).round(3),
  p95_ms: ms(p95).round(3),
  p99_ms: ms(p99).round(3)
}.to_json)
