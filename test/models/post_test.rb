require "test_helper"

class PostTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    FilterTerm.delete_all
  end

  teardown do
    clear_enqueued_jobs
    ActiveJob::Base.queue_adapter = :async
  end

  test "bodyは必須" do
    post = Post.new(user: users(:one), body: nil)

    assert_not post.valid?
    assert_includes post.errors[:body], "を入力してください"
  end

  test "bodyは140文字以内で有効" do
    post = Post.new(user: users(:one), body: "あ" * 140)

    assert post.valid?
  end

  test "bodyが141文字だと無効" do
    post = Post.new(user: users(:one), body: "あ" * 141)

    assert_not post.valid?
    assert_includes post.errors[:body], "は140文字以内で入力してください"
  end

  test "sentiment_labelはposとnegのみ有効" do
    post = Post.new(user: users(:one), body: "テスト投稿", sentiment_label: "neutral")

    assert_not post.valid?
    assert_includes post.errors[:sentiment_label], "は不正な値です"
  end

  test "投稿作成時に解析ジョブをenqueueする" do
    assert_enqueued_with(job: Posts::AnalyzePostJob) do
      Post.create!(user: users(:one), body: "解析対象の投稿です")
    end
  end

  test "prohibit語が含まれる場合は保存できない" do
    FilterTerm.create!(term: "しね", action: "prohibit")
    post = Post.new(user: users(:one), body: "しね")

    assert_not post.valid?
    assert post.prohibit_hit?
    assert_includes post.errors[:body], "不適切なワードを含むため投稿できません"
  end

  test "support語が含まれる場合はsupport_requiredになる" do
    FilterTerm.create!(term: "らくにしにたい", action: "support")
    post = Post.new(user: users(:one), body: "らくにしにたい")

    assert_not post.valid?
    assert post.support_required?
    assert_includes post.errors[:base], "サポートページへ移動します"
  end
end
