# 無限スクロール実装メモ（Timeline / My Posts）

このドキュメントは、現行コードの無限スクロール実装をロジックを理解するために整理したものです。

## 対象ファイル
- `app/controllers/timeline_controller.rb`
- `app/controllers/my/posts_controller.rb`
- `app/services/posts/cursor_paginator.rb`
- `app/views/timeline/index.html.erb`
- `app/views/timeline/_feed_chunk.html.erb`
- `app/views/timeline/_next_frame.html.erb`
- `app/views/timeline/_post_rows.html.erb`
- `app/views/my/posts/index.html.erb`
- `app/views/my/posts/_feed_chunk.html.erb`
- `app/views/my/posts/_next_frame.html.erb`
- `app/views/my/posts/_post_rows.html.erb`

## 全体像
- 初回表示: サーバーが投稿を `20件 + 判定用1件` 取得してHTMLを返す。
- 次ページ判定: 21件目があれば `has_next = true`。
- 読み込みトリガー: 画面下部の `turbo_frame_tag(..., src: next_path, loading: :lazy)` がビューポートに入ると自動リクエスト。
- 続きのレスポンス: Turbo Frame リクエスト時は一覧差分（chunk）だけ返す。
- ページング方式: `before_created_at` と `before_id` を使うカーソル方式（offsetではない）。

## 1. 初回表示の流れ
1. `timeline#index` / `my/posts#index` で `load_feed!` を呼ぶ。
2. `Posts::CursorPaginator.call(...)` に `before_created_at` と `before_id` なしで渡す。
3. 新しい順（`created_at DESC, id DESC`）で最大21件を取得。
4. 先頭20件を表示用 `@posts`、21件目の有無を `@has_next` にセット。
5. `@has_next` が true のときだけ `@next_path` を生成。
6. ビューが `_post_rows` + `_next_frame` を描画。

## 2. 次ページ読み込みの流れ
1. `next_frame` 部分テンプレートが以下を出す。
   - `timeline`: `<turbo-frame id="timeline_next" ...>`
   - `my_posts`: `<turbo-frame id="my_posts_next" ...>`
2. その frame が見えると、Turbo が`src=next_path` に自動GET。
3. コントローラは `turbo_frame_request?` を検知。
4. フルHTMLではなく `feed_chunk` 部分テンプレートだけ返す。
5. Turbo は `id` (id="timeline_next" or id="my_posts_next") で置換対象を判別
6. chunk 内で `post_rows` と `next_frame` を再描画する。
7. `has_next` が false になった時点で `next_frame` が消え、そこで停止。

## 3. カーソル条件（重複・取りこぼし対策）
`Posts::CursorPaginator` のWHERE条件は次の通り。

```sql
posts.created_at < :cursor_time
OR (posts.created_at = :cursor_time AND posts.id < :cursor_id)
```

意図:
- `created_at` だけだと同時刻投稿の順序がぶれる可能性がある。
- 同時刻は「ほぼ起きない」前提にせず、連続INSERT・精度丸め・テスト投入などで実際に起きうる前提で設計する。
- `id` を第2キーにして「同時刻ならIDが小さい方が古い」と定義し、安定して次ページを切る。

## 4. `+1件取得` の意味
- `limit(per_page + 1)`（この実装では 21件）で取得。
- 表示は先頭 `per_page`（20件）だけ使う。
- 余った1件の存在だけで「次ページあり」を判定。

これで `COUNT(*)` を毎回打たずに済む。

## 5. タイムラインと自分投稿の違い
共通:
- `Posts::CursorPaginator` を使う。
- 1ページ20件。
- Turbo Frame の lazy 読み込み構造。

相違:
- `timeline` は `Post` 全体を対象。
- `my/posts` は `Current.user.posts` のみ対象。
- frame ID と部分テンプレートのパスが異なる。

## 6. URLパラメータの意味
- `before_created_at`: 現在表示ページ末尾投稿の `created_at`（ISO8601）
- `before_id`: 現在表示ページ末尾投稿の `id`

次ページURL生成時に「今回の末尾」を渡すことで、その投稿より古い範囲だけを取る。

※ ISO8601: 日時を文字列で表す国際標準形式。例: `2026-02-16T16:30:45.123456+09:00`

## 7. つまずきやすい点
- `turbo_frame_request?` の分岐を壊すと、lazy読込時にページ全体HTMLを返して崩れる。
- 並び順（`created_at DESC, id DESC`）とカーソル条件はセット。片方だけ変えると重複/欠落が出やすい。
- `before_created_at` のパース失敗時はカーソル無効扱いになる（初回相当の挙動）。

## 8. 不正カーソル時の方針（現状）
- 方針: 不正な `before_created_at` は `nil` 扱いにして処理継続する（`500` は返さない）。
- 実装位置: `app/services/posts/cursor_paginator.rb` の `parse_cursor_time`。
- 理由:
  - カーソル値は認可・機密に直結する情報ではなく、主影響はページング表示の乱れにとどまる。
  - 入力異常で `500` にすると可用性を下げるため、フォールバック継続のメリットが大きい。
  - 攻撃価値が低く、現時点で `400` 厳格化の優先度は高くない。
- 補足: 不正入力の増加を監視したくなった段階で、警告ログ追加や `400` 化を検討する。

## 9. テストで担保していること
- lazy frame が出ること
  - `test/integration/timeline_flow_test.rb`
  - `test/integration/my_posts_flow_test.rb`
- cursor付きアクセスで「古い投稿のみ返る」こと
  - 同上ファイルの `cursor付きアクセス` テスト

## 10. インデックス追加（2026-02-16）
- 追加内容: `posts(created_at, id)` の複合インデックスを追加。
  - migration: `db/migrate/20260216074136_add_created_at_id_index_to_posts.rb`
  - index名: `index_posts_on_created_at_and_id`
- 追加理由:
  - 全体タイムラインは `created_at DESC, id DESC` で並び替え、同じキーでカーソル条件（`created_at` と `id`）を使ってページングする。
  - データ件数が増えるほど、並び替えと範囲抽出のコストが増えるため、対応する複合インデックスで負荷増を抑える。
- 想定効果:
  - 無限スクロール時の「次ページ取得クエリ」の安定化（遅延悪化の抑制）。
  - 特に全体TL（`Post` 全体対象）の読み込み性能に効く。

---
この文書は「今の実装」を説明するメモです。アルゴリズム変更時（例: おすすめTLの本実装）には更新してください。
