require "test_helper"

class FilterTermTest < ActiveSupport::TestCase
  setup do
    FilterTerm.delete_all
    Rails.cache.clear
  end

  test "normalize_for_matchは前後空白除去とNFKC正規化を行う" do
    normalized = FilterTerm.normalize_for_match("  ＯＤ  ")

    assert_equal "od", normalized
  end

  test "matchingは正規化後の完全一致でヒットする" do
    prohibit_term = FilterTerm.create!(term: "しね", action: "prohibit")
    support_term = FilterTerm.create!(term: "らくにしにたい", action: "support")

    matched = FilterTerm.matching("らくにしにたい しね")

    assert_includes matched, prohibit_term
    assert_includes matched, support_term
  end

  test "matchingはヒットがない場合は空になる" do
    FilterTerm.create!(term: "死ね", action: "prohibit")

    assert_empty FilterTerm.matching("こんにちは")
  end

  test "matchingは部分一致のみの語をヒットさせない" do
    FilterTerm.create!(term: "しね", action: "prohibit")

    assert_empty FilterTerm.matching("だしね")
  end

  test "cached_normalized_terms_by_actionはキャッシュ化した語彙をaction別に正しく取得できる" do
    FilterTerm.create!(term: "しね", action: "prohibit")
    FilterTerm.create!(term: "ら く に し に た い", action: "support")

    terms_by_action = FilterTerm.cached_normalized_terms_by_action

    assert_includes terms_by_action.fetch("prohibit"), "しね"
    assert_includes terms_by_action.fetch("support"), "ら く に し に た い"
  end
end
