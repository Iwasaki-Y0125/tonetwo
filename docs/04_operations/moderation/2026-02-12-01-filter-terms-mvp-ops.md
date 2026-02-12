# FilterTerms運用手順（MVP）

## 目的
- MVP時点での禁止語（`filter_terms`）運用手順を固定し、登録・更新・本番反映で迷わない状態にする。

## 結論
- ローカルでは `db/seeds/filter_terms.local.rb` を更新して検証する。
- 本番反映は `script/seeds/export_filter_terms_sql.rb` で生成したSQLを使って実施する。
- 投稿判定は現時点で未接続のため、まずは語彙データの整備と反映手順を優先する。

## 変更点
- `db/seeds/filter_terms.local.rb` をローカル専用語彙ファイルとして運用する。
- SQL生成ツール `script/seeds/export_filter_terms_sql.rb` を使い、冪等SQL（`ON CONFLICT`）で投入する。
- `filter_terms.action` は `prohibit` / `support` の2値で運用する。

## 手順
1. ローカル語彙を更新する  
- 編集対象: `db/seeds/filter_terms.local.rb`
- 方針:
  - `support_terms`: 危機介入につなげる語
  - `prohibit_terms`: 投稿禁止語
  - `death_threat_terms`: 脅迫・暴力系の表記ゆれ

2. ローカル反映（開発環境）  
- `bin/rails db:seed`

3. 本番投入用SQLを生成する  
- 標準出力:
  - `ruby script/seeds/export_filter_terms_sql.rb`
- ファイル出力:
  - `ruby script/seeds/export_filter_terms_sql.rb -o /tmp/filter_terms.sql`

4. 本番DBへSQLを適用する  
- 生成した `/tmp/filter_terms.sql` を本番DB接続で実行する。
- SQLは `INSERT ... ON CONFLICT (term) DO UPDATE` のため再実行可能。

5. 反映確認  
- 件数確認:
  - `SELECT action, COUNT(*) FROM filter_terms GROUP BY action;`
- サンプル確認:
  - `SELECT term, action FROM filter_terms ORDER BY updated_at DESC LIMIT 20;`

## 運用ルール（MVP）
- `db/seeds/filter_terms.local.rb` は `.gitignore` 対象のため、機微語彙をGitに載せない。
- 本番語彙はSQL生成物で管理し、必要に応じて都度投入する。
- 語彙更新時は誤検知/漏検知を確認し、次回更新で調整する。

## 動作確認
- SQL生成スクリプト構文:
  - `ruby -c script/seeds/export_filter_terms_sql.rb`
- SQL生成（先頭確認）:
  - `ruby script/seeds/export_filter_terms_sql.rb | head -n 40`

## 参考
- `db/seeds/filter_terms.local.rb`
- `script/seeds/export_filter_terms_sql.rb`
- `app/models/filter_term.rb`
- `db/migrate/20260212090000_create_filter_terms.rb`
