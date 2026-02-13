# MatchingExclusionTerms運用方針（MVP）

## 目的
- おすすめ表示のマッチングで情報量が低い一般語を除外し、ノイズ一致を減らす。

## 要件（確定）
- テーブル: `matching_exclusion_terms`
- カラム: `term` のみ（`enabled` は持たない/使わない語はシンプルに削除する）
- 制約:
  - `term` は `NOT NULL`
  - `term` は trim 後に空文字不可（CHECK制約）
  - `term` は UNIQUE
- 無効化方法:
  - 使わなくなった語は「削除」で対応する。

## 現在の実装
- モデル:
  - `app/models/matching_exclusion_term.rb`
  - `normalizes :term` で前後空白のみ除去
  - `validates :term, presence: true, uniqueness: true`
- マッチング参照:
  - `app/services/posts/similar_posts_query.rb`
  - `MatchingExclusionTerm.select(:term)` を使い、存在語をそのまま除外
- DB定義:
  - `db/migrate/20260213093000_create_matching_exclusion_terms.rb`
  - `db/schema.rb`

## 運用方針（MVP）
- シードは公開管理とする（Git管理）。
  - ファイル: `db/seeds/matching_exclusion_terms.rb`
- 追加・更新は seed 編集で対応し、管理画面実装後に管理画面運用へ移行する。
- 表記ゆれ対応は seed 側で持つ。
  - 例: 漢字/ひらがな/カタカナを必要に応じて並記
- 時系列語（`今日` など）は文脈差に効くため、現時点の除外語から外す。

## 反映手順
1. 語彙を更新する
- 編集対象: `db/seeds/matching_exclusion_terms.rb`

2. 開発環境へ投入する
- `make db-seed`
- または `bin/rails db:seed`

3. DBを作り直して投入する
- `make db-reset-seed`

4. 反映確認
- 件数確認:
  - `bin/rails runner "puts MatchingExclusionTerm.count"`
- サンプル確認:
  - `bin/rails runner "puts MatchingExclusionTerm.order(:term).limit(30).pluck(:term)"`

## 注意点
- 現在の除外一致は「完全一致」。
- 形態素解析の名詞抽出は表層形ベースのため、必要な揺れは seed に追加する。

## 参考
- `db/seeds/matching_exclusion_terms.rb`
- `db/seeds.rb`
- `app/models/matching_exclusion_term.rb`
- `app/services/posts/similar_posts_query.rb`
- `db/migrate/20260213093000_create_matching_exclusion_terms.rb`
- `Makefile`
