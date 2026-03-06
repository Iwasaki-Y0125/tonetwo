require "test_helper"

module Moderation
  class SupportProhibitCheckerTest < ActiveSupport::TestCase
    setup do
      FilterTerm.delete_all
      Rails.cache.clear
    end

    test "blankはokを返す" do
      result = SupportProhibitChecker.call("")

      assert_predicate result, :ok?
      assert_not_predicate result, :support?
      assert_not_predicate result, :prohibit?
    end

    test "support語が含まれる場合はsupportを返す" do
      FilterTerm.create!(term: "しね", action: "prohibit")
      FilterTerm.create!(term: "らくにしにたい", action: "support")

      result = SupportProhibitChecker.call("らくにしにたい しね")

      assert_predicate result, :support?
      assert_not_predicate result, :ok?
      assert_not_predicate result, :prohibit?
    end

    test "prohibit語のみが含まれる場合はprohibitを返す" do
      FilterTerm.create!(term: "しね", action: "prohibit")

      result = SupportProhibitChecker.call("しね")

      assert_predicate result, :prohibit?
      assert_not_predicate result, :ok?
      assert_not_predicate result, :support?
    end

    test "ヒットしない場合はokを返す" do
      FilterTerm.create!(term: "しね", action: "prohibit")

      result = SupportProhibitChecker.call("こんにちは")

      assert_predicate result, :ok?
      assert_not_predicate result, :support?
      assert_not_predicate result, :prohibit?
    end
  end
end
