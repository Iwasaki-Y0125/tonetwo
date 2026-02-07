# Render Deploy トラブルシュート記録（2026-02-07）

本ドキュメントは、今回のデプロイで実際に詰まった点だけを簡潔に記録する。  
機密情報は含めない。

## 1. `secret_key_base` 未設定で起動失敗

- 症状
  - `ArgumentError: Missing secret_key_base for 'production' environment`
- 原因
  - Render 環境変数 `SECRET_KEY_BASE` 未設定
- 対処
  - Render Web Service の Environment に `SECRET_KEY_BASE` を設定
- 補足
  - `RAILS_MASTER_KEY` は現時点の本番運用では未使用。`credentials.yml.enc` を本番で利用する場合は必須。
  - 本番の機密情報は Render Environment Variables で管理する
    1. ローテーションがしやすい
    2. 環境ごとの差し替えがしやすい
    3. PaaS 運用で一般的な管理方法に合わせられる
  - 今後、`credentials.yml.enc` を使う場合は `RAILS_MASTER_KEY` の運用が別途必要

## 2. DB 接続先がローカルソケットになり接続失敗

- 症状
  - `connection to server on socket ... .s.PGSQL.5432 failed`
- 原因
  - `production` で `DATABASE_URL` を明示参照しておらず、接続解決が意図とズレた
- 対処
  - `config/database.yml` の `production.primary` を `url: <%= ENV["DATABASE_URL"] %>` に統一

## 3. Solid Cache テーブル未作成

- 症状
  - `PG::UndefinedTable: relation "solid_cache_entries" does not exist`
- 原因
  - `cache` DB は作成済みでも `solid_cache_entries` が未作成
- 対処
  1. Render Postgres に `tone_two_production_cache` を作成
  2. `solid_cache_entries` テーブルとインデックスを作成
  3. `\d solid_cache_entries` で確認

## 4. `tailwind.css` 欠落で 500

- 症状
  - `Propshaft::MissingAssetError: The asset 'tailwind.css' was not found in the load path`
- 原因
  - `.dockerignore` で `app/assets/builds/*` を除外しているため、コンテナ内に `tailwind.css` が存在しない
- 対処
  - `Dockerfile` の build ステージで `npm run build:css` を実行してから `assets:precompile`

## 再発防止チェック（デプロイ前）

1. `SECRET_KEY_BASE` が設定済みか
2. `DATABASE_URL` が正しいか（Internal URL / DB名）
3. `tone_two_production_cache` と `solid_cache_entries` が存在するか
4. Build Logs に `npm run build:css` が出ているか
5. デプロイ後 `/up` が 200 か
