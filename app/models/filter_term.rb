class FilterTerm < ApplicationRecord
  TOKEN_SPLIT_PATTERN = /[\p{Space}\p{Punct}\p{Symbol}]+/u
  TERMS_CACHE_VERSION = "v1"

  enum :action, {
    prohibit: "prohibit",
    support: "support"
  }, validate: true

  # termの前後の空白を除去して正規化する。DBの正規化条件と同等にする。
  normalizes :term, with: ->(value) { value&.strip }

  validates :term, presence: true, uniqueness: true
  validates :action, presence: true

  # 完全一致でフィルタリングした結果をaction別に返す。
  class << self
    # キャッシュ化した語彙をaction別に正しく取得するためのメソッド。
    def cached_normalized_terms_by_action(expires_in: 5.minutes)
      Rails.cache.fetch(normalized_terms_cache_key, expires_in: expires_in) do
        grouped_terms = {}

        # DBの全件を走査して正規化する。正規化後に空になる語彙は無視する。
        pluck(:term, :action).each do |term, action|
          normalized_term = normalize_for_match(term)
          next if normalized_term.blank?

          grouped_terms[action] ||= []
          grouped_terms[action] << normalized_term
        end

        actions.keys.each do |action|
          grouped_terms[action] ||= []
          grouped_terms[action] = grouped_terms[action].uniq.freeze
        end

        grouped_terms.freeze
      end
    end

    # 管理画面更新直後などで即時反映したいときに使う。
    def invalidate_terms_cache!
      Rails.cache.delete(normalized_terms_cache_key)
    end

    # 全角半角や大文字小文字の揺れを吸収して比較を安定化する。
    def normalize_for_match(text)
      text.to_s.unicode_normalize(:nfkc).downcase.strip
    end

    # support語がヒットした場合は support のみ返して判定を確定する。
    # supportがない場合のみ prohibit を判定する。
    def matching(text)
      candidates = normalized_match_candidates(text)
      return none if candidates.empty?

      support_ids = matched_ids_for_action(candidates, "support")
      return where(id: support_ids) if support_ids.any?

      matched_ids = matched_ids_for_action(candidates, "prohibit")
      where(id: matched_ids)
    end

    private

    # 与えられた正規化済み候補集合に含まれる語彙のIDを返す。
    def matched_ids_for_action(candidates, action)
      where(action: action).pluck(:id, :term).filter_map do |id, term|
        normalized_term = normalize_for_match(term)
        id if normalized_term.present? && candidates.include?(normalized_term)
      end
    end

    # 入力文をトークン化し、完全一致判定用の候補集合を作る。
    def normalized_match_candidates(text)
      normalized_text = normalize_for_match(text)
      return [] if normalized_text.blank?

      normalized_text.split(TOKEN_SPLIT_PATTERN).reject(&:blank?).uniq
    end

    # 語彙更新で自動的にキャッシュを切り替える。
    def normalized_terms_cache_key
      latest = maximum(:updated_at)&.utc&.iso8601(6) || "none"
      "filter_terms:normalized_terms_by_action:#{TERMS_CACHE_VERSION}:#{count}:#{latest}"
    end
  end
end
