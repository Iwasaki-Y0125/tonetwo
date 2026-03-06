module Moderation
  class SupportProhibitChecker
    class Result
      def initialize(status:)
        @status = status
      end

      def ok?
        @status == :ok
      end

      def support?
        @status == :support
      end

      def prohibit?
        @status == :prohibit
      end
    end

    def self.call(text)
      return Result.new(status: :ok) if text.blank?

      matched_filter_terms = FilterTerm.matching(text)
      return Result.new(status: :support) if matched_filter_terms.where(action: "support").exists?
      return Result.new(status: :prohibit) if matched_filter_terms.where(action: "prohibit").exists?

      Result.new(status: :ok)
    end
  end
end
