# frozen_string_literal: true

module Sentiment
  module Lexicon
    # pn.csv.m3.120408.trim:
    # word \t (p|n|e|noise) \t category
    # 2列目は原則 p/n/e。ノイズも混ざる。
    class Pn
      LABEL_MAP = { "p" => 1, "n" => -1, "e" => 0 }.freeze

      def initialize(path)
        @path = path
        @dict = nil
      end

      # 単語のスコアを返す
      def score(word)
        dict[word]
      end

      # @dict があればそれを返す。なければ load_dict で読み込んでセットして返す
      def dict
        @dict ||= load_dict
      end

      private

      def load_dict
        raise "pn lexicon not found: #{@path}" unless File.exist?(@path)

        h = {}
        File.foreach(@path, encoding: "UTF-8") do |line|
          line = line.strip
          next if line.empty?

          # タブ区切りで最大3つに分割
          # word：1列目（単語）
          # label：2列目（p/n/e）
          # _category：3列目（分類）※使わない
          word, label, _category = line.split("\t", 3)
          next if word.nil? || label.nil?

          label = label.strip
          next unless LABEL_MAP.key?(label) # p/n/e以外はスキップ

          h[word] = LABEL_MAP[label]
        end
        h
      end
    end
  end
end
