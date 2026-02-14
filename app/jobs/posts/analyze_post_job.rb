module Posts
  class AnalyzePostJob < ApplicationJob
    queue_as :default

    # 解析系の一時失敗（辞書読み込み/外部要因など）は再試行して救済する。
    retry_on StandardError, wait: 30.seconds, attempts: 5
    discard_on ActiveRecord::RecordNotFound

    def perform(post_id:)
      Posts::AnalyzePost.call(post_id: post_id)
    end
  end
end
