require "test_helper"

class Posts::AnalyzePostJobTest < ActiveJob::TestCase
  test "performはAnalyzePostを呼び出す" do
    called_post_id = nil

    analyzer = lambda do |post_id:|
      called_post_id = post_id
    end

    original_method = Posts::AnalyzePost.method(:call)
    Posts::AnalyzePost.define_singleton_method(:call, analyzer)
    begin
      Posts::AnalyzePostJob.perform_now(post_id: 123)
    ensure
      Posts::AnalyzePost.define_singleton_method(:call, original_method)
    end

    assert_equal 123, called_post_id
  end
end
