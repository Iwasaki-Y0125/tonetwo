# Admin認証ガードと`role` migration実装手順

## 目的
- `Admin::ApplicationController` で管理画面へのアクセスを管理者のみに制限する。
- `users` テーブルに管理者判定用の `role` を追加する。
- `role` は boolean ではなく string enum として扱う。

## 現状
- [app/controllers/admin/application_controller.rb](../../../app/controllers/admin/application_controller.rb) には `before_action :authenticate_admin` があるが、中身は未実装。
- [app/controllers/application_controller.rb](../../../app/controllers/application_controller.rb) は [app/controllers/concerns/authentication.rb](../../../app/controllers/concerns/authentication.rb) を include しており、通常画面はセッション認証を前提にしている。
- [app/models/user.rb](../../../app/models/user.rb) に `role` 定義はまだない。
- [db/schema.rb](../../../db/schema.rb) の `users` テーブルにも `role` カラムはまだない。
- [config/routes.rb](../../../config/routes.rb) の `/admin` ルートがある。

## 方針
- `users.role` を `string`, `null: false` で追加する。
- enum は Rails の string enum を使い、`admin` / `member` を定義する。
- 選定理由は、DB の値を `member` / `admin` と読める形で持ちつつ、アプリ側では `user.admin?` のように書けるようにするため。
- 既存ユーザーがいる前提で、migration 追加時から `default: "member"` を持たせる。
- 管理画面の認証ガードは「未ログイン」と「ログイン済みだが非管理者」を分けて扱う。
- controller では `user.role == "admin"` のような文字列比較を直接書かず、`User` モデルの `user.admin?` / `user.member?` を使って判定する。

## 実装順
1. `users.role` を追加する migration を作る。
2. `User` モデルに string enum を追加する。
3. `Admin::ApplicationController` に認証ガードを実装する。
4. `/admin` ルート有効化後の挙動を確認する。
5. model / request もしくは controller テストを追加する。

## Step 1. migration
1. migration ファイルを作成する。  
   コマンド:
   ```bash
   make g-migr G="AddRoleToUsers role:string"
   ```

2. 生成された migration に `role` の定義を書く。  
   記載内容:
   ```rb
   class AddRoleToUsers < ActiveRecord::Migration[8.1]
     def change
       add_column :users, :role, :string, null: false, default: "member"
       add_check_constraint :users,
                            "role IN ('member', 'admin')",
                            name: "check_users_role"
     end
   end
   ```

3. migration を適用する。  
   コマンド:
   ```bash
   make db-migrate
   ```

4. `schema.rb` を確認する。  
   確認内容:
   - `users.role` が追加されている
   - `default: "member"` になっている
   - `check_users_role` が追加されている

## Step 2. Userモデル
1. [app/models/user.rb](../../../app/models/user.rb) に `role` の enum を追加する。  
   記載内容:
   ```rb
   enum :role, {
     member: "member",
     admin: "admin"
   }, validate: true
   ```

2. `User` モデルで `user.admin?` / `user.member?` が使えることを確認する。  
   コマンド:
   ```bash
   make rails-c
   ```
   ```rb
   # User.new は未保存のインスタンスを作るだけ
   user = User.new(role: "member")
   user.member? # => true
   user.admin?  # => false

   admin = User.new(role: "admin")
   admin.admin?  # => true
   admin.member? # => false

   invalid_user = User.new(role: "foo")
   invalid_user.valid?        # => false
   invalid_user.save          # => false
   invalid_user.errors[:role] # => role のエラーが入る

   default_user = User.create!(
     email_address: "default-role-check@example.com",
     password: "abc123def456",
     password_confirmation: "abc123def456",
     terms_agreed: "1"
   )
   default_user.role    # => "member"
   default_user.member? # => true
   ```

## Step 3. `Admin::ApplicationController`
1. [app/controllers/admin/application_controller.rb](../../../app/controllers/admin/application_controller.rb) で `Authentication` concern を使えるようにする。  
   記載内容:
   ```rb
   include Authentication
   ```

2. `authenticate_admin` を実装する。  
   記載内容:
   ```rb
   def authenticate_admin
     return request_authentication unless resume_session

      redirect_to root_path unless Current.session.user.admin?
   end
   ```
   方針:
   - 非管理者アクセス時は flash を出さない
   - セキュリティのため、権限不足の理由など詳しい情報は返さない

3. `authenticate_admin` の動きを確認する。  
   手順:
   1. テスト用ユーザーを用意する。  
      コマンド:
      ```bash
      make rails-c
      ```
      ```rb
      User.find_or_create_by!(email_address: "member-check@example.com") do |user|
        user.password = "abc123def456"
        user.password_confirmation = "abc123def456"
        user.terms_agreed = "1"
        user.role = "member"
      end

      User.find_or_create_by!(email_address: "admin-check@example.com") do |user|
        user.password = "abc123def456"
        user.password_confirmation = "abc123def456"
        user.terms_agreed = "1"
        user.role = "admin"
      end
      ```
   2. ブラウザで `/admin` にアクセスする。
   3. 未ログイン状態で `/admin` にアクセスし、ログイン画面へリダイレクトされることを確認する。
   4. `member-check@example.com` でログインして `/admin` にアクセスし、`root_path` へリダイレクトされることを確認する。
   5. `admin-check@example.com` でログインして `/admin` にアクセスし、管理画面に入れることを確認する。

## Step 4. テスト
1. integration test を追加する。  
   記載内容:
   - [test/integration/admin_auth_flow_test.rb](../../../test/integration/admin_auth_flow_test.rb)
   - 未ログインで `/admin` にアクセスするとログイン画面へリダイレクトされること
   - `role=member` で `/admin` にアクセスすると `root_path` へリダイレクトされること
   - `role=admin` で `/admin` にアクセスすると管理画面を表示できること

2. 追加した test を実行する。  
   コマンド:
   ```bash
   docker compose --env-file .env.test -f docker-compose.dev.yml -f docker-compose.test.yml run --rm --workdir /app -e HOME=/tmp --user $(id -u):$(id -g) -e RAILS_ENV=test web bash -lc 'bin/rails db:drop db:create db:test:prepare && bin/rails test test/integration/admin_auth_flow_test.rb'
   ```

3. 実行結果を確認する。  
   確認内容:
   - 3件の test が通ること
   - failure / error が 0 件であること

## 参考
- ローカル一次情報
  - [app/controllers/admin/application_controller.rb](../../../app/controllers/admin/application_controller.rb)
  - [app/controllers/application_controller.rb](../../../app/controllers/application_controller.rb)
  - [app/controllers/concerns/authentication.rb](../../../app/controllers/concerns/authentication.rb)
  - [app/models/user.rb](../../../app/models/user.rb)
  - [config/routes.rb](../../../config/routes.rb)
  - [db/schema.rb](../../../db/schema.rb)
  - [Makefile](../../../Makefile)
  - [docker-compose.dev.yml](../../../docker-compose.dev.yml)
- 関連docs
  - [docs/03_engineering/admin/2026-03-18-01-config-routes-admin-scope.md](./2026-03-18-01-config-routes-admin-scope.md)
  - [docs/03_engineering/admin/2026-03-17-02-administrate-add-admin-resource-runbook.md](./2026-03-17-02-administrate-add-admin-resource-runbook.md)
  - [docs/03_engineering/auth/2026-01-14-01-rails8-auth-implementation-steps.md](../auth/2026-01-14-01-rails8-auth-implementation-steps.md)
