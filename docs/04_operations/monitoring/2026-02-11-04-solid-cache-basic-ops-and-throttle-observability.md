# Solid Cache運用メモ（初学者向け）と現在の実装状況

## 目的
- `solid_cache_store` を初めて運用する際に、最低限どこを確認すればよいかをまとめる。
- このリポジトリで現在有効になっている `security.throttle` 集計ログの実装内容を残す。

## いまの実装（このリポジトリの事実）
- `production` は `:solid_cache_store` を使用する。
  - `config/environments/production.rb:53`
- `development` も `:solid_cache_store` を使用する。
  - `config/environments/development.rb:29`
- `test` も `:solid_cache_store` を使用する。
  - `config/environments/test.rb:23`
- `development` / `test` / `production` の DB 設定に `cache` DB があり、`db/cache_migrate` を migrations path として持つ。
  - `config/database.yml`
- `solid_cache_entries` テーブル定義は `db/cache_schema.rb` に存在する。
  - `db/cache_schema.rb:2`
- `security.throttle` は `Rails.cache` を使った閾値集計ログを有効化済み。
  - `config/initializers/security_throttle_observability.rb:13`

## まず理解すること（超要点）
- `solid_cache_store` は「DBテーブルを使うキャッシュ」。
- `memory_store` は「アプリプロセスのメモリ内キャッシュ」。
- 複数インスタンス運用では、レート制限カウントを共有できる `solid_cache_store` の方が安定しやすい。

## developmentをSolid Cacheに寄せた理由（2026-02-11）
- 「切り替え運用は忘れやすい」という実運用リスクを避けるため。
- 開発中に、`MemoryStore` では露見しにくい保存時不整合（シリアライズ/エンコード系）を早めに検知するため。
- MVP期日に近づいてから「本番だけ動かない」を防ぐため、環境差分を減らす方針にした。
- `test` でも本番近似のため `:solid_cache_store` を使い、`test.cache` DB を分離して運用する。
- 並列テスト時の干渉を避けるため、`test` の cache namespace は PID を含めて分離する。

## MVPでの運用手順（Render想定）
1. `cache` DB 設定が有効か確認する。
   - `config/database.yml` の `development.cache` / `test.cache` / `production.cache` を確認する。
2. `solid_cache_entries` テーブルが本番に存在するか確認する。
   - Render Shell か外部接続で `\dt` を実行し、`solid_cache_entries` があることを確認する。
3. ローカル開発DBにも cache schema を適用する（`db:prepare`）。
   - このリポジトリでは `make db-reset` も `db:prepare` まで実行するため、cache DB の再準備漏れを防げる。
4. テストDBにも cache schema を適用する（`RAILS_ENV=test bin/rails db:prepare`）。
5. デプロイ後、`security.throttle.summary` ログが出ることを確認する。
   - しきい値に達しないと出ないため、軽く負荷をかけるか、運用中ログで確認する。

## レート制限ログの現在仕様
- イベント: `security.throttle`
- 集計キー: `window + layer + rule`
- しきい値:
  - `WARN_THRESHOLD = 20`
  - `ERROR_THRESHOLD = 100`
- 出力形式: `security.throttle.summary ...`
- パスは個人情報過多を避けるため先頭セグメントのみ（例: `/session`）にマスクする。
  - `config/initializers/security_throttle_observability.rb:4`

## よくある勘違い
- 「レート制限用に新しい migration を追加する必要がある」
  - このリポジトリでは通常不要。`solid_cache_entries` が既にあるため。
- 「test も `solid_cache_store` にしたら並列実行で必ず干渉する」
  - `test.cache` DB分離 + namespace分離（PID）で衝突リスクを下げられる。

## トラブル時チェックリスト
1. `production` で `config.cache_store = :solid_cache_store` になっているか。
2. `solid_cache_entries` テーブルが存在するか。
3. `config/cache.yml` の `production` が `database: cache` になっているか。
4. `security_throttle_observability.rb` がロードされているか（重複登録防止フラグあり）。

## 参考（公式一次ソース）
- Rails Guides: Caching with Rails（Solid Cache）
  - https://guides.rubyonrails.org/caching_with_rails.html#solid-cache
- Solid Cache（公式リポジトリ）
  - https://github.com/rails/solid_cache
- Rails API: `ActiveSupport::Cache`
  - https://api.rubyonrails.org/classes/ActiveSupport/Cache.html
