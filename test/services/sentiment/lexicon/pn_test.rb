require "test_helper"
require "tempfile"

class Sentiment::Lexicon::PnTest < Minitest::Test
  def test_user_dict_overrides_base_dict_with_neutral_score
    user_dict = Tempfile.new("user_pn")
    base_dict = Tempfile.new("base_pn")

    user_dict.write("友人\te\tgeneral\n")
    user_dict.flush
    base_dict.write("友人\tp\t名詞\n最高\tp\t名詞\n")
    base_dict.flush

    lexicon = Sentiment::Lexicon::Pn.new([ user_dict.path, base_dict.path ])

    assert_equal 0, lexicon.score("友人")
    assert_equal 1, lexicon.score("最高")
  ensure
    user_dict&.close!
    base_dict&.close!
  end
end
