# frozen_string_literal: true

module Sentiment
  module Lexicon
    # pn.csv.m3.120408.trim:
    # word \t (p|n|e|noise) \t category
    # 2列目は原則 p/n/e。ノイズも混ざる。
    class Pn
      LABEL_MAP = { "p" => 1, "n" => -1, "e" => 0 }.freeze

      def initialize(path)
        @paths = Array(path)
        @dictionary = nil
      end

      # 単語のスコアを返す
      def score(word)
        dictionary[word]
      end

      # @dictionary があればそれを返す。なければ load_dictionary で読み込んでセットして返す
      def dictionary
        @dictionary ||= load_dictionary
      end

      private

      def load_dictionary
        dictionary = {}
        @paths.each do |path|
          File.foreach(path, encoding: "UTF-8") do |line|
            line = line.strip
            # 空行はスキップ
            next if line.empty?

            # タブ区切りで最大3つに分割
            # word：1列目（単語）
            # label：2列目（p/n/e）
            # _category：3列目（分類）※使わない
            word, label, _category = line.split("\t", 3)
            next if word.nil? || label.nil?

            label = label.strip
            next unless LABEL_MAP.key?(label) # p/n/e以外はスキップ

            # 同じ単語が複数回出てきたら、先のほうを優先する（上書きしない）
            dictionary[word] ||= LABEL_MAP[label]
          end
        end
        dictionary
      end
    end
  end
end
