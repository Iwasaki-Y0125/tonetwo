# frozen_string_literal: true

module Posts
  class CursorPaginator
    # posts: 今回表示する1ページ分
    # has_next: 次ページがあるか
    # last_post: 次ページカーソル生成の基準になる末尾投稿
    Result = Struct.new(:posts, :has_next, :last_post, keyword_init: true)

    def self.call(scope:, before_created_at:, before_id:, per_page:)
      # 次のページの取得に必要なカーソル時刻とIDをリクエストから取得する。
      cursor_time = parse_cursor_time(before_created_at)
      cursor_id = before_id.to_i if before_id.present?

      if cursor_time.present? && cursor_id.present?
        scope = scope.where(
          "posts.created_at < ? OR (posts.created_at = ? AND posts.id < ?)",
          cursor_time, # カーソル時刻より古い投稿
          cursor_time, # 同時刻投稿を対象に含める比較用
          cursor_id    # 同時刻内ではIDが小さい(=より古い側)投稿
        )
      end

      # 1件多く取得して「次ページあり」を判定し、表示はper_page件に絞る。
      records = scope.limit(per_page + 1).to_a
      posts = records.first(per_page)
      has_next = records.size > per_page

      Result.new(posts: posts, has_next: has_next, last_post: posts.last)
    end

    # before_created_at はURLパラメータ（文字列）なので、そのまま where に使う前に Time へ変換が必要
    def self.parse_cursor_time(value)
      return nil if value.blank?

      Time.zone.parse(value)
    rescue ArgumentError
      nil
    end
    private_class_method :parse_cursor_time
  end
end
