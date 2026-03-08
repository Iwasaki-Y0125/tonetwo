require "test_helper"
require "tempfile"

class Sentiment::Lexicon::WagoTest < Minitest::Test
  def test_user_dictionary_overrides_base_dictionary
    user_dictionary = Tempfile.new("user_wago")
    base_dictionary = Tempfile.new("base_wago")

    user_dictionary.write("ネガ（評価）\t良い ない\n")
    user_dictionary.flush
    base_dictionary.write("ポジ（評価）\t良い ない\nポジ（評価）\t気持ち 良い\n")
    base_dictionary.flush

    lexicon = Sentiment::Lexicon::Wago.new([ user_dictionary.path, base_dictionary.path ], max_terms: 5)

    assert_equal(-1, lexicon.score_terms(%w[良い ない]))
    assert_equal(1, lexicon.score_terms(%w[気持ち 良い]))
  ensure
    user_dictionary&.close!
    base_dictionary&.close!
  end
end
