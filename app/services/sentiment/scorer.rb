# frozen_string_literal: true

module Sentiment
  class Scorer
    DEFAULT_TARGET_POS = %w[名詞 形容詞 動詞 副詞].freeze

    # 否定の基本形 (否定検出は tokens 全体を見る)
    NEGATION_BASES = %w[
      ない ぬ ず ん
      ません ないです ないだ
      ないだろ ないだろう ないでしょう
      まい
    ].freeze

    def initialize(
      pn_lexicon:,
      wago_lexicon:,
      target_pos: DEFAULT_TARGET_POS,
      negation_window: 3    # 否定が何語後までに来たら反転するか
    )
      raise ArgumentError, "pn_lexicon is required" unless pn_lexicon
      raise ArgumentError, "wago_lexicon is required" unless wago_lexicon

      @pn = pn_lexicon
      @wago = wago_lexicon
      @target_pos = target_pos
      @negation_window = negation_window
    end

    #  tokens: [{ surface:, base:, pos: }, ...]
    def score_tokens(tokens)
      raise ArgumentError, "tokens must be an Array" unless tokens.is_a?(Array)
      raise ArgumentError, "wago_lexicon must respond to score_terms" unless @wago.respond_to?(:score_terms)


      # スコア対象(名詞 形容詞 動詞 副詞)だけインデックスで抽出
      # 目的：探索の開始位置を絞って無駄を減らす
      target_idx = []
      tokens.each_with_index do |t, i|
        next unless @target_pos.include?(t[:pos])
        target_idx << i
      end

      # 正規化済みの語（base優先、なければsurface）
      # 目的：辞書フレーズを再現するために全トークンを正規化して配列に格納
      norm_terms = tokens.map { |t| base_or_surface(t[:base], t[:surface]) }

      # 各トークンが「どのhit（開始index）に含まれているか」
      # 目的：フレーズの重複マッチ防止＆否定反転をフレーズ単位で適用するため
      covered_by_hit = Array.new(tokens.length)

      # フレーズごとの分析結果を格納するハッシュ
      # hits: { start_i(Integer) => { type:, i:, phrase:, span:, raw:, applied:, negated: }, ... }
      hits = {}

      # 3) wago: 用言編（n-gram: 1〜最大5語）
      max_terms = @wago.respond_to?(:max_terms) ? @wago.max_terms : 5

      target_idx.each do |i|
        # すでにpn or 先行フレーズに含まれていたらスキップ
        next if covered_by_hit[i]

        matched = nil

        # 最長一致（max_terms = 5）
        max_terms.downto(1) do |len|
          # 語彙の長さぶんのn-gramは作れない場合スキップ
          next if i + len > norm_terms.length

          # 既存ヒットと重なるn-gramは採用しない（重複カウント防止）
          # 補足) .compact => 配列からnilを取り除いた配列を返す(nilのみでも.any?はtrueになる)
          next if covered_by_hit.slice(i, len).compact.any?

          # 正規化したフレーズでwago辞書でスコアリング
          terms = norm_terms.slice(i, len)
          s = @wago.score_terms(terms)
          next if s.nil?

          matched = [ terms, s, len ]

          # より短い候補は試さずループを抜ける
          break
        end

        # 辞書に当たってないならループを抜ける
        next unless matched

        # 多重代入（termなどを取り出す)
        terms, s, len = matched
        # 辞書キーと同じ形（空白区切り）にする
        phrase = terms.join(" ")

        # 分析結果を格納する
        hits[i] = build_hit(type: :wago, i: i, phrase: phrase, score: s, span: len)
        # covered_by_hitにインデックスでマーキングする
        (i...(i + len)).each { |k| covered_by_hit[k] = i }
      end

      # 3) pn：名詞編
      target_idx.each do |i|
        # wagoフレーズに含まれている単語は二重カウントしない
        next if covered_by_hit[i]

        key = norm_terms[i]
        s = @pn.score(key)
        next if s.nil?

        hits[i] = build_hit(type: :pn, i: i, phrase: key, score: s, span: 1)
        covered_by_hit[i] = i
      end

      # 4) 否定反転：全トークンから否定語の位置を拾って、直前のヒット1個を反転
      apply_negation!(hits, tokens, covered_by_hit)

      # 5) 集計 ( スコア / 合計 / 平均値 )
      hit_values = hits.values
      scores = hit_values.map { |h| h[:applied].to_f }

      polarity_scores = scores.reject { |x| x == 0.0 }  # 0(中立)を除外

      total = polarity_scores.sum
      mean = polarity_scores.empty? ? 0.0 : (total / polarity_scores.length)

      {
        total: total,
        mean: mean,
        counts: {
          matched: scores.length,
          pos: scores.count { |x| x > 0 },
          neg: scores.count { |x| x < 0 },
          neu: scores.count { |x| x == 0 }
        },
        hits: hit_values.sort_by { |h| h[:i] }
      }
    end

    private

    # 評価語
    def build_hit(type:, i:, phrase:, score:, span: 1)
      {
        type:    type,     # 辞書タイプ(:pn or :wago)
        i:       i,        # 開始トークンインデックス
        phrase:  phrase,   # 該当フレーズ（空白区切り）
        span:    span,     # マッチ語数（1〜5）
        raw:     score,    # 元のスコア
        applied: score,    # 否定反転後のスコア
        negated: false     # 否定反転済みフラグ
      }
    end

    # 正規化(base優先、なければsurfaceを使う)
    def base_or_surface(base, surface)
      base_str = base.to_s
      return surface.to_s if base_str.empty? || base_str == "*"
      base_str
    end

    # 否定語かどうかチェック
    def negation_token?(t)
      base = t[:base].to_s
      surf = t[:surface].to_s
      pos  = t[:pos].to_s

      NEGATION_BASES.include?(base) || NEGATION_BASES.include?(surf)

      # 「ん」は助動詞のときだけ否定扱い
      (base == "ん" || surf == "ん") && pos == "助動詞"
    end

    # 否定反転処理（フレーズ対応）
    # 1. 文章の中で否定語（ない/ず/ません…）が出てくる場所を探す
    # 2. 否定語の3語前までで「ヒットに属しているトークン」を探す。
    # 3. そのヒットのappliedを反転、negatedにフラグを立てる
    # 4. ただし否定語自体が「ヒットしたフレーズ内」に含まれる場合はスキップ
    #
    # hits: { start_i => { ... } }
    # tokens: [{ surface:, base:, pos: }, ...]
    # covered_by_hit: token_index -> hit_start_index

    def apply_negation!(hits, tokens, covered_by_hit)
      # ヒットがなければ終了
      return if hits.empty?

      tokens.each_with_index do |t, neg_i|
        # 否定語がなければ終了
        next unless negation_token?(t)

        # 否定語が「ヒットしたフレーズ内」なら、辞書側で意味づけ済みのため反転しない
        next if covered_by_hit[neg_i]

        # 否定語が見つかったら、直前〜negation_window(=3)語前まで繰り返す
        # d = 1 のとき：直前の語
        # d = 2 のとき：一つ飛んで前の語
        1.upto(@negation_window) do |d|
          candidate_i = neg_i - d
          # 文頭を超えるので打ち切り
          break if candidate_i < 0

          # 評価語のcovered_by_hitのインデックス番号を取得
          hit_start = covered_by_hit[candidate_i]
          # 評価語が取得できなければ次の候補へ
          next if hit_start.nil?

          # 評価語の本体を取り出す
          h = hits[hit_start]
          # covered_by_hit と hits がズレた時の保険
          next unless h

          # 二重反転防止
          next if h[:negated]

          # 否定反転処理
          h[:applied] *= -1
          h[:negated] = true

          # 一番近い語で反転出来たら即離脱
          break
        end
      end
    end
  end
end
