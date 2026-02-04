# frozen_string_literal: true

module Posts
  class TermsUpserter
    def self.call(post_id:, terms:)
      terms = Array(terms).map(&:to_s).map(&:strip).reject(&:empty?).uniq
      return if terms.empty?

      now = Time.current

      # terms upsert
      Term.insert_all(
        terms.map { |t| { term: t, created_at: now, updated_at: now } },
        unique_by: :index_terms_on_term
      )
      term_ids = Term.where(term: terms).pluck(:id).uniq

      # post_terms upsert
      PostTerm.insert_all(
        term_ids.map { |tid| { post_id: post_id, term_id: tid, created_at: now, updated_at: now } },
        unique_by: :index_post_terms_on_post_id_and_term_id
      )
    end
  end
end
