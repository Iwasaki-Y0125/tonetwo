# ダミーポスト投入とbackfill実行手順

## 目的
- おすすめ検証用に大量のダミーポストを投入し、本文からの解析（感情スコア/ラベル、名詞抽出）が期待どおり動くか確認する。

## 前提
- 開発コンテナが起動していること。
  - `make dev`
- `db/seeds/damy_posts` は検証用seedディレクトリ名として現状この名称を使用する。

## 個別実行コマンド
1. ダミーポストを投入する
- `make damy-posts-seed`
- 主な上書きパラメータ:
  - `USERS`（デフォルト: `200`）
  - `POSTS`（デフォルト: `3000`）
  - `POST_BATCH`（デフォルト: `1000`）
  - `MIN_TERMS`（デフォルト: `2`）
  - `MAX_TERMS`（デフォルト: `5`）
  - `LIMIT_TERMS`（未指定時は制限なし）
- 例:
  - `make damy-posts-seed USERS=50 POSTS=1000 POST_BATCH=200 MIN_TERMS=2 MAX_TERMS=4 LIMIT_TERMS=120`

2. 感情スコアとラベルをbackfillする
- `make backfill-post-sentiment`
- 主な上書きパラメータ:
  - `BATCH`（デフォルト: `500`）
  - `FROM_ID` / `TO_ID`（未指定時は全件）
  - `DRY_RUN=1` で更新なし試運転
- 例:
  - `make backfill-post-sentiment DRY_RUN=1 BATCH=500 FROM_ID=10001 TO_ID=12000`

3. terms/post_termsをbackfillする
- `make backfill-post-terms`
- 主な上書きパラメータ:
  - `BATCH`（デフォルト: `500`）
  - `FROM_ID` / `TO_ID`（未指定時は全件）
  - `DRY_RUN=1` で更新なし試運転
- 例:
  - `make backfill-post-terms BATCH=500 FROM_ID=10001 TO_ID=12000`

## 一括実行コマンド
- ダミーポスト投入 -> 感情backfill -> terms backfill を順番に実行:
  - `make damy-posts-all`

- 一括実行時に渡せる主なパラメータ:
  - seed系: `USERS`, `POSTS`, `POST_BATCH`, `MIN_TERMS`, `MAX_TERMS`, `LIMIT_TERMS`
  - backfill系: `BATCH`, `FROM_ID`, `TO_ID`, `DRY_RUN`
- 例:
  - `make damy-posts-all USERS=30 POSTS=600 POST_BATCH=200 BATCH=300 FROM_ID=1`

## 確認例
- 解析対象投稿件数:
  - `bin/rails runner "puts Post.count"`
- 感情ラベル未設定件数:
  - `bin/rails runner "puts Post.where(sentiment_label: nil).count"`
- 中間テーブル件数:
  - `bin/rails runner "puts PostTerm.count"`

## 参照
- `db/seeds/damy_posts/posts_seeder.local.rb`
- `db/seeds/damy_posts/body_builder.local.rb`
- `script/backfill/backfill_post_sentiment_scores.rb`
- `script/backfill/backfill_post_terms.rb`
- `Makefile`
