# frozen_string_literal: true

module Sentiment
  module Lexicon
    # wago.121808.pn:
    #   データ形式（タブ区切り）
    #   | ラベル | \t | 表現（単語 / フレーズ）|
    #
    #   例:
    #     ネガ（評価）\t良い ない
    #     ポジ（経験）\t気持ち 良い
    #     ポジ（評価）\tちょうど 良い
    #     ポジ（評価）\t物わかり が 良い
    #
    # 「最大5語までのフレーズ」採用：
    # - 表現（単語/フレーズ）を空白で分解して、最大5語まで辞書化する
    # - 6語以上の表現は、形態素解析で分割や表記ゆれが起きて一致しにくいため対象外とする
    #   （辞書の語数分布的にも6語以上は0.3%でコスパが悪い）

    class Wago
      LABEL_MAP = {
        "ポジ（評価）" => 1,
        "ポジ（経験）" => 1,
        "ネガ（評価）" => -1,
        "ネガ（経験）" => -1
      }.freeze

      attr_reader :max_terms

      def initialize(path, max_terms: 5)
        @paths = Array(path)
        @max_terms = max_terms
        @dict_by_len = nil
      end

      # terms: ["物わかり", "が", "良い"] のように配列で渡す
      # return: 1 / -1 / nil（辞書にない or 対象外）
      def score_terms(terms)
        # 例外処理(型ちがい、空欄)
        unless terms.is_a?(Array)
          raise ArgumentError, "Wago#score_terms: terms must be an Array, got: #{terms.class}"
        end
        raise ArgumentError, "Wago#score_terms: terms must not be empty" if terms.empty?

        # 6語以上は「辞書対象外」なのでスルー（= マッチング対象外）
        return nil if terms.length > @max_terms

        key = terms.join(" ")
        dict_by_len[terms.length][key]
      end

      # 遅延ロード(初期化の軽量化・テストケースの軽量化のため)
      # score_termsが呼ばれた時のみ辞書生成する分岐
      def dict_by_len
        @dict_by_len ||= load_dict
      end

      private

      def load_dict
        paths = @paths.select { |p| File.exist?(p) }
        raise "Wago#load_dict: wago lexicon not found: #{@paths.join(', ')}" if paths.empty?

        h = Hash.new { |hh, k| hh[k] = {} }
        # hh は「Hash of Hashes（ハッシュの中にハッシュ）」での通称的な引数
        # { |hh, k| ... } の...は 「入ってないキーを読んだ瞬間に呼ばれる処理」
        # hh[k] = {} とは「 h[3] = {} 」を作る
        # 結果として h = {
        #                 1 => { "良い" => 1 , "悪い" => -1, "嬉しい" => 1 },
        #                 2 => { "良い ない" => -1, "悪い ない" => 1, ...},
        #                 3 => { "物わかり が 良い" => 1, "感じ が 悪い" => -1, ...}
        #               }
        # のようにハッシュの中にハッシュを格納できる

        paths.each do |path|
          # File.foreach :ファイルを一行ずつ読み込んで繰り返し処理する
          File.foreach(path, encoding: "UTF-8") do |line|
            # 改行、前後空白などを削除
            line = line.strip
            next if line.empty?

            # wagoは「ラベル \t 表現」
            label, expr_str = line.split("\t", 2)
            next if label.nil? || expr_str.nil?

            # スコア読み込み
            score = LABEL_MAP[label]
            next if score.nil?

            # 表現を空白で分解（wago側の空白はトークン境界として扱う）
            expr = expr_str.strip.split(/\s+/)
            next if expr.empty?

            # 6語以上は除外
            next if expr.length > @max_terms

            key = expr.join(" ")
            # ||=でファイルの先頭側を優先する（先勝ち）
            h[expr.length][key] ||= score
          end
        end

        h
      end
    end
  end
end
