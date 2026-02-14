require "test_helper"

class MatchingExclusionTermTest < ActiveSupport::TestCase
  setup do
    MatchingExclusionTerm.delete_all
  end

  test "termの前後空白を除去して保存する" do
    record = MatchingExclusionTerm.create!(term: "  今日  ")

    assert_equal "今日", record.term
  end

  test "termが空文字のときは無効" do
    record = MatchingExclusionTerm.new(term: "   ")

    assert_not record.valid?
    assert_includes record.errors[:term], "を入力してください"
  end

  test "termは一意である" do
    MatchingExclusionTerm.create!(term: "ここ")
    duplicate = MatchingExclusionTerm.new(term: "ここ")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:term], "はすでに存在します"
  end
end
