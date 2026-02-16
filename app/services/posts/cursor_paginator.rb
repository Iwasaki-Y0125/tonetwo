# frozen_string_literal: true

module Posts
  class CursorPaginator
    # Result = Struct.new(...):　型定義
    # posts: 今回表示する1ページ分
    # has_next: 次ページがあるかのフラグ
    # last_post: 次ページのカーソル生成の基準になる末尾投稿
    # keyword_init: true キーワード引数で渡すためのオプション
    Result = Struct.new(:posts, :has_next, :last_post, keyword_init: true)

    def self.call(scope:, before_created_at:, before_id:, per_page:)
      # 次のページの取得に必要なカーソル時刻とIDをリクエストから取得する。
      # 初回はnil
      cursor_time = parse_cursor_time(before_created_at)
      cursor_id = before_id.to_i if before_id.present?

      # カーソルが有効な場合は、カーソルより古い投稿に絞り込む。
      # 比較が重いので、 created_at と id の複合インデックスを追加
      if cursor_time.present? && cursor_id.present?
        scope = scope.where(
          "posts.created_at < ? OR (posts.created_at = ? AND posts.id < ?)",
          # posts.created_at < cursor_time : カーソル時刻より古い投稿
          cursor_time,
          # OR (posts.created_at = cursor_time AND posts.id < cursor_id) : 同時刻内ではIDが小さい(=より古い側)投稿
          cursor_time, cursor_id
        )
      end

      # recordsはPostの実データ。スコープから20+1件取得して配列に格納。
      records = scope.limit(per_page + 1).to_a
      # postsは20件のみの実データ。（表示の1ページ分）
      posts = records.first(per_page)
      # has_nextはrecordsに21件あるか判定し、あれば次ページ有のフラグを立てる。
      has_next = records.size > per_page

      # Result.new(...): Result = Struct.newで定義した型に合わせて返り値を生成する。
      Result.new(posts: posts, has_next: has_next, last_post: posts.last)
    end

    # before_created_at はURLパラメータ（文字列）なので、そのまま where に使う前に Time へ変換が必要
    def self.parse_cursor_time(value)
      return nil if value.blank?

      Time.zone.parse(value)
    # URLパラメータが不正な日時文字列だった場合は例外
    # 例外が発生したらカーソル無効として扱い、最初のページを返すために nil を返す。
    rescue ArgumentError
      nil
    end
    private_class_method :parse_cursor_time
  end
end
