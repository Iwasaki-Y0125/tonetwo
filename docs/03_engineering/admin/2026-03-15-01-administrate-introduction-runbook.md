# Administrate 導入メモ

## 目的
- Issue `#41` の着手前に、導入手順と実装論点を簡潔に整理する。

## 前提
- 技術スタックは [README.md](../../../README.md) を参照。
- 採用判断は [2026-03-13-01-admin-gem-comparison.md](./2026-03-13-01-admin-gem-comparison.md) を参照。
- 認証は [app/controllers/concerns/authentication.rb](../../../app/controllers/concerns/authentication.rb) の `Session` ベース。
- ユーザー認証の主体は [app/models/user.rb](../../../app/models/user.rb) の `has_secure_password`。

## 実装方針
- `/admin` 配下に `Administrate` を導入する。
- 認証は既存セッションを流用する。
- 管理者判定は `users` に明示的なフラグを持たせる案を第一候補とする。
- 初回の管理対象は `users`、`posts`、`filter_terms` を想定する。

## 手順
1. `Gemfile` に `gem "administrate"` を追加する。
2. `make bundle-install` で `Gemfile.lock` を更新する。
3. `rails generate administrate:install` を Docker 経由で実行する。
   - 生成物の詳細は [2026-03-17-01-administrate-install-generated-files.md](./2026-03-17-01-administrate-install-generated-files.md) を参照。
4. `config/routes.rb` の `/admin` 公開対象を必要最小限に絞る。
5. `Admin::ApplicationController` に認証ガードを実装する。
6. 管理者フラグ用 migration を追加する。
7. dashboard の表示項目を整理する。
8. `/admin` と対象一覧画面を確認する。

## 実装時の論点
- 管理者権限
  - `users.admin:boolean` で始めるか。
- 初回対象
  - `users`
  - `posts`
  - `filter_terms`
- 後続 Issue に回すもの
  - 通報審査画面
  - `sentiment backfill` 実行 action
  - 強制退会や投稿非表示などの運用 action

## 動作確認
- 未ログインで `/admin` に入るとログイン画面へ遷移すること
- 非管理者は `/admin` に入れないこと
- 管理者だけが `/admin` に入れること
- 少なくとも1つの管理対象モデルで一覧画面が出ること

## コマンド例
```bash
make dev
make bundle-install
docker compose --env-file .env.dev -f docker-compose.dev.yml exec -w /app -e HOME=/tmp --user $(id -u):$(id -g) web bundle exec rails generate administrate:install
make db-migrate
make test
```

## 参考
- ローカル一次情報
  - [README.md](../../../README.md)
  - [Gemfile](../../../Gemfile)
  - [Gemfile.lock](../../../Gemfile.lock)
  - [Makefile](../../../Makefile)
  - [docker-compose.dev.yml](../../../docker-compose.dev.yml)
  - [app/controllers/concerns/authentication.rb](../../../app/controllers/concerns/authentication.rb)
  - [app/models/user.rb](../../../app/models/user.rb)
  - [app/models/filter_term.rb](../../../app/models/filter_term.rb)
  - [2026-03-13-01-admin-gem-comparison.md](./2026-03-13-01-admin-gem-comparison.md)
- 公式一次ソース
  - Administrate README: <https://github.com/thoughtbot/administrate>
  - Administrate Getting Started: <https://administrate-demo.herokuapp.com/getting_started>
  - Administrate Authentication: <https://administrate-demo.herokuapp.com/authentication>
  - Administrate Authorization: <https://administrate-demo.herokuapp.com/authorization>
