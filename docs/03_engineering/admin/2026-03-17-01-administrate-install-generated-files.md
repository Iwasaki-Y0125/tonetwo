# Administrate install 生成物メモ

## 目的
- `rails generate administrate:install` で何が生成されるかを、現在のリポジトリ依存に合わせて整理する。

## 前提
- このリポジトリでは [Gemfile](../../../Gemfile) と [Gemfile.lock](../../../Gemfile.lock) で `administrate` を利用している。
- ローカル依存の実体は `administrate 1.0.0`。

## 結論
- `rails generate administrate:install` は、管理画面全体の土台を作る初回 generator。
- 生成される中心は次の3つ。
  - 管理画面共通コントローラー `app/controllers/admin/application_controller.rb`
  - 管理画面ルーティングの追記 `config/routes.rb`
  - 各 Active Record モデル向けの dashboard と管理画面コントローラー

## `administrate:install` で生成されるもの

### 1. `app/controllers/admin/application_controller.rb`
- `Admin::ApplicationController < Administrate::ApplicationController` が生成される。
- 管理画面の共通入口で、認証や認可の起点に使う。
- generator 初期状態では `before_action :authenticate_admin` のひな形だけが入り、実際の管理者判定ロジックはアプリ側で実装する。

### 2. `config/routes.rb` の `admin` ルーティング
- `namespace :admin do ... end` が追記される。
- ここに各管理対象リソースの `resources` が並ぶ。
- 先頭の管理対象を `root` にする設定も入る。
- 例

```ruby
namespace :admin do
  resources :users
  resources :posts
  root to: "users#index"
end
```

### 3. モデルごとの dashboard と管理画面コントローラー
- インストール時点で見つかる Active Record モデルごとに、次のようなファイルが生成される。
  - `app/dashboards/user_dashboard.rb`
  - `app/controllers/admin/users_controller.rb`
- つまり通常画面用の `UsersController` とは別に、管理画面専用の `Admin::UsersController` が作られる。

## `app/dashboards` とは何か
- Rails 標準ではなく、Administrate が使う表示設定ディレクトリ。
- 各 `*_dashboard.rb` で「そのモデルを管理画面でどう見せるか」を定義する。
- 主に次を決める。
  - `ATTRIBUTE_TYPES`
    - 各属性を `Field::String` や `Field::BelongsTo` としてどう扱うか
  - `COLLECTION_ATTRIBUTES`
    - 一覧画面に出す項目
  - `SHOW_PAGE_ATTRIBUTES`
    - 詳細画面に出す項目
  - `FORM_ATTRIBUTES`
    - 作成・編集フォームに出す項目
  - `COLLECTION_FILTERS`
    - 一覧の検索補助フィルタ

## 生成対象になるモデル
- 基本的には、インストール時点で見つかる Active Record モデルが対象。
- 新しくテーブルや model を追加した場合は、[2026-03-17-02-administrate-add-admin-resource-runbook.md](./2026-03-17-02-administrate-add-admin-resource-runbook.md) の手順で管理対象を追加する。
- ただし次は generator 側で除外される。
  - 対応テーブルがないモデル
  - namespaced model
  - 動的に生成される特殊なモデル

## 参考
- ローカル一次情報
  - [Gemfile](../../../Gemfile)
  - [Gemfile.lock](../../../Gemfile.lock)
- 公式一次ソース
  - Administrate Getting Started: <https://administrate-demo.herokuapp.com/getting_started>
  - Install generator: <https://github.com/thoughtbot/administrate/blob/v1.0.0/lib/generators/administrate/install/install_generator.rb>
  - Routes generator: <https://github.com/thoughtbot/administrate/blob/v1.0.0/lib/generators/administrate/routes/routes_generator.rb>
  - Dashboard generator: <https://github.com/thoughtbot/administrate/blob/v1.0.0/lib/generators/administrate/dashboard/dashboard_generator.rb>
