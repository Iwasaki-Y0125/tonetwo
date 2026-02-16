# おすすめTL仕様メモ

## MVP仕様
- クエリ名は `SimilarTimelineQuery` とする。
- 呼び出し元は `TimelineController#similar`。
- おすすめ投稿の対象期間は自分/相手両方とも直近7日（処理の重さを考慮）
- `visibility / reply_mode / share_scope / moderation_state` 条件は使わない（MVP未実装）
- 候補条件は「1語以上一致 + sentiment_label一致」
- 最終並びは `created_at DESC, id DESC`（新しい投稿が上、同時刻であればidが新しいほう）
- termの一致語数は、おすすめTLへの仕様変更のため、現時点では保持しない。

## seed 空時の表示文言
ケース別に表示文言を分ける。

```text
<!-- 直近7日投稿なし -->
ここにはあなたの直近の投稿をもとに
ほかユーザーの投稿表示がされます。

※直近の投稿がありません。

<!-- 解析中: sentiment_label / post_terms 未確定の一時状態 -->
ここにはあなたの直近の投稿をもとに
ほかユーザーの投稿が表示されます。

※おすすめを解析中です。反映までしばらくお待ちください。

<!-- 解析済みだが seed なし -->
ここにはあなたの直近の投稿をもとに
ほかユーザーの投稿が表示されます。

※投稿数が少ないため、おすすめを作成できません。
```

## ActiveRecord案（現行スキーマ準拠）
```ruby
# similar TL（1語以上一致 + sentiment_label一致、新着順）
window_from = 7.days.ago

# recent_posts（自分の直近投稿）
recent_posts = Post
  .select(:id, :sentiment_label)
  .where(user_id: me_id)
  .where("posts.created_at >= ?", window_from)
  .where.not(sentiment_label: nil)
  .order(created_at: :desc, id: :desc)
  .limit(10)

# seedに中間テーブルを結合し、sentiment_label込みで集合を作る
seed = PostTerm
  # recent_posts（自分の直近投稿）に紐づく post_terms を結合して取る
  .joins("INNER JOIN (#{recent_posts.to_sql}) recent_posts ON recent_posts.id = post_terms.post_id")
  # (term_id, sentiment_label) の seed 集合を作る
  .select("DISTINCT post_terms.term_id, recent_posts.sentiment_label AS sentiment_label")

# seedと一致する中間テーブルと結合し、その中からsentiment_labelが一致、7日以内、自分を含めない投稿を新着順で取得
candidates = Post
  .joins(:post_terms)
  .joins("INNER JOIN (#{seed.to_sql}) seed ON seed.term_id = post_terms.term_id")
  .where("posts.sentiment_label = seed.sentiment_label")
  .where.not(user_id: me_id)
  .where("posts.created_at >= ?", window_from)
  .select("DISTINCT posts.id, posts.created_at")
  .order(created_at: :desc, id: :desc)

# 候補IDのRelationを作る（重複投稿を除外）
candidate_ids = candidates.select(:id).distinct

# Post本体をIDで取り直し、TL順でページネータへ渡す
scope = Post.where(id: candidate_ids).order(created_at: :desc, id: :desc)

result = Posts::CursorPaginator.call(
  scope: scope,
  before_created_at: params[:before_created_at],
  before_id: params[:before_id],
  per_page: 20
)
```

### 補足（ARとSQLの関係）
- ARで書いても、最終的にはSQLに変換されてDBで実行される。
- 性能は「生成されるSQL」が同じならほぼ同じ。
- 実装時は `to_sql` と `EXPLAIN (ANALYZE, BUFFERS)` で確認する。

## 補足
- seedが空なら候補も0件になるため、上記のケース別案内文を出す。
- `post_terms` に `sentiment_label` は持たせない（将来の再解析時の不整合回避）。
- `analyzing` 状態のときは `timeline_feed` を5秒間隔で再取得し、自動で表示更新する。
