require "test_helper"

class Posts::AnalyzePostTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
  end

  teardown do
    clear_enqueued_jobs
    clear_performed_jobs
    ActiveJob::Base.queue_adapter = :async
  end

  test "解析結果をsentimentとtermsに保存する" do
    post = Post.create!(user: users(:one), body: "今日はプログラミングが楽しい")

    analyzer = Class.new do
      def tokens(_text)
        [
          { surface: "今日", base: "今日", pos: "名詞" },
          { surface: "楽しい", base: "楽しい", pos: "形容詞" }
        ]
      end
    end.new
    noun_extractor = Struct.new(:nouns) do
      def call(_text)
        nouns
      end
    end.new([ "今日", "プログラミング" ])
    sentiment_scorer = Struct.new(:result) do
      def score_tokens(_tokens)
        result
      end
    end.new({ mean: -0.25 })

    with_singleton_method_stub(Mecab::Analyzer, :new, analyzer) do
      with_singleton_method_stub(Mecab::NounExtractor, :new, noun_extractor) do
        with_replaced_constant(:SENTIMENT_SCORER, sentiment_scorer) do
          result = Posts::AnalyzePost.call(post_id: post.id)

          post.reload
          assert_in_delta(-0.25, post.sentiment_score, 0.0001)
          assert_equal "neg", post.sentiment_label
          assert_equal "neg", result[:label]
          assert_equal 2, post.post_terms.count
        end
      end
    end
  end

  private

  def with_replaced_constant(name, value)
    original = Object.const_get(name)
    Object.send(:remove_const, name)
    Object.const_set(name, value)
    yield
  ensure
    Object.send(:remove_const, name)
    Object.const_set(name, original)
  end

  def with_singleton_method_stub(klass, method_name, replacement)
    original_method = klass.method(method_name)
    klass.define_singleton_method(method_name) { |*_, **_| replacement }
    yield
  ensure
    klass.define_singleton_method(method_name, original_method)
  end
end
