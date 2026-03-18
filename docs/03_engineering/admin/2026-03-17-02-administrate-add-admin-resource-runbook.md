# Administrate 管理対象追加メモ

## 目的
- 後からテーブルやモデルを追加したときに、Administrate の管理対象を増やす手順を整理する。

## 前提
- 初回導入の generator 実行は完了している。
- このリポジトリでは `administrate 1.0.0` を利用している。
- generator 実行は Docker 経由を優先する。

## 結論
- 後から管理対象を増やすときは、通常 `rails generate administrate:install` は再実行しない。
- 対象モデルごとに `rails generate administrate:dashboard ModelName` を実行する。
- 必要に応じて `config/routes.rb` の `namespace :admin` に `resources` を追加する。
- 初回整理で削除した dashboard / controller も、この手順で必要時に再生成する。

## 前提になるもの
- migration で対応テーブルが作成済みであること
- 対応する Active Record モデルが存在すること

## 手順
1. migration を追加してテーブルを作成する。
2. model を追加する。
3. Docker 経由で `rails generate administrate:dashboard ModelName` を実行する。
4. `config/routes.rb` に管理画面の route が追加されているか確認する。
5. 生成された `app/dashboards/*_dashboard.rb` で表示項目を調整する。
6. 生成された `app/controllers/admin/*_controller.rb` に必要な制御があれば追加する。
7. `/admin/<resources>` にアクセスして一覧画面を確認する。

## コマンド例
```bash
docker compose --env-file .env.dev -f docker-compose.dev.yml exec -w /app -e HOME=/tmp --user $(id -u):$(id -g) web bundle exec rails generate administrate:dashboard Order
```

## 生成されるもの
- `app/dashboards/order_dashboard.rb`
- `app/controllers/admin/orders_controller.rb`

## 補足
- テーブルだけ増えても、model が無ければ generator の対象にならない。
- route だけ追加したい場合は `administrate:routes` を使える。
- namespaced model やテーブル未作成モデルは generator で除外されることがある。

## 動作確認
- `config/routes.rb` に対象の `resources` があること
- `app/dashboards/*_dashboard.rb` が生成されていること
- `app/controllers/admin/*_controller.rb` が生成されていること
- `/admin/<resources>` の一覧画面が表示できること

## 参考
- ローカル一次情報
  - [Gemfile](../../../Gemfile)
  - [Gemfile.lock](../../../Gemfile.lock)
  - [Makefile](../../../Makefile)
  - [docker-compose.dev.yml](../../../docker-compose.dev.yml)
- 公式一次ソース
  - Dashboard generator: <https://github.com/thoughtbot/administrate/blob/v1.0.0/lib/generators/administrate/dashboard/dashboard_generator.rb>
  - Routes generator: <https://github.com/thoughtbot/administrate/blob/v1.0.0/lib/generators/administrate/routes/routes_generator.rb>
