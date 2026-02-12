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

  # 完全一致でフィルタリングした結果をaction別に返す。正規化してからDBの全件を走査するため、件数が多い場合は注意。
  class << self
    # キャッシュ化した語彙をaction別に正しく取得するためのメソッド。
    # 更新のたびにキャッシュが無効になるように、updated_atの最大値をキーに含める。
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

    def invalidate_terms_cache!
      Rails.cache.delete(normalized_terms_cache_key)
    end

    def normalize_for_match(text)
      text.to_s.unicode_normalize(:nfkc).downcase.strip
    end

    # 表記ゆれは語彙側で吸収し、判定は完全一致のみを行う。
    def matching(text)
      candidates = normalized_match_candidates(text)
      return none if candidates.empty?

      matched_ids = all.filter_map do |filter_term|
        normalized_term = normalize_for_match(filter_term.term)
        filter_term.id if normalized_term.present? && candidates.include?(normalized_term)
      end

      where(id: matched_ids)
    end

    private

    def normalized_match_candidates(text)
      normalized_text = normalize_for_match(text)
      return [] if normalized_text.blank?

      normalized_text.split(TOKEN_SPLIT_PATTERN).reject(&:blank?).uniq
    end

    def normalized_terms_cache_key
      latest = maximum(:updated_at)&.utc&.iso8601(6) || "none"
      "filter_terms:normalized_terms_by_action:#{TERMS_CACHE_VERSION}:#{count}:#{latest}"
    end
  end
end
