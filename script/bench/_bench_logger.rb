# frozen_string_literal: true

require "fileutils"
require "time"

module BenchLogger
  module_function

  def with_log(prefix:, meta: {})
    FileUtils.mkdir_p("log/bench")
    ts = Time.now.strftime("%Y%m%d_%H%M%S")
    path = "log/bench/#{prefix}_#{ts}.log"

    File.open(path, "w") do |f|
      f.puts "[meta] at=#{Time.now.iso8601}"
      meta.each { |k, v| f.puts "[meta] #{k}=#{v}" }
      f.puts
      yield f
    end

    puts "[saved] #{path}"
  end
end
