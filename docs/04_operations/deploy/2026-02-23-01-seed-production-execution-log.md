# 本番 seed 投入実行ログ（2026-02-23）

## 目的
MVP公開前の初期データ投入として、以下を production DB に反映する。

- `filter_terms`
- `matching_exclusion_terms`
- 通常投稿データ（運営サンプル）

## 実行概要
- 実行日: 2026-02-23 (JST)
- 対象環境: production

## 実施内容
### 1. 業務テーブル初期化
`schema_migrations` / `ar_internal_metadata` / `solid_*` は保持し、業務テーブルのみ初期化した。

初期化後の主要件数:

- `users: 0`
- `posts: 0`
- `filter_terms: 0`
- `chatrooms: 0`
- `chat_messages: 0`
- `terms: 0`
- `post_terms: 0`
- `sessions: 0`
- `matching_exclusion_terms: 0`

### 2. `filter_terms` 投入
`/tmp/filter_terms.sql` を `psql -f` で適用。

結果:

- `INSERT 0 403`
- `prohibit: 297`
- `support: 106`

確認SQL:

```sql
SELECT action, COUNT(*) FROM filter_terms GROUP BY action ORDER BY action;
```

### 3. `matching_exclusion_terms` 投入
`RAILS_ENV=production bin/rails db:seed` を実行（production では shared seed のみ読み込み）。

確認結果:

- `seed_unique_count=35`
- `db_count=35`
- `missing=[]`
- `extra=[]`

### 4. 通常投稿データ投入
運営サンプル投稿を投入し、表示・投稿・おすすめ導線を動作確認した。

補足:

- 投稿データの seed 資産は悪用リスク低減のため削除
