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
- `rails generate administrate:install` は初回の土台作成として必須だが、生成物はそのまま使わず公開対象に合わせて刈り込む。
- 認証は既存セッションを流用する。
- 管理者判定は `users` に明示的なフラグを持たせる案を第一候補とする。
- 初回の管理対象は `filter_terms`、`matching_exclusion_terms` とする。
- 通報対応は将来の `*_abuse_reports` 起点で扱う。

## 手順
1. `Gemfile` に `gem "administrate"` を追加する。
2. `make bundle-install` で `Gemfile.lock` を更新する。
3. `rails generate administrate:install` を Docker 経由で実行する。
   - 生成物の詳細は [2026-03-17-01-administrate-install-generated-files.md](./2026-03-17-01-administrate-install-generated-files.md) を参照。
4. `config/routes.rb` の `/admin` 公開対象を必要最小限に絞る。
   - 実装の詳細は [2026-03-18-01-config-routes-admin-scope.md](./2026-03-18-01-config-routes-admin-scope.md) を参照。
   - 合わせて、不要な routes / controller / dashboard を刈り込む
5. `Admin::ApplicationController` の認証ガード実装と、管理者フラグ用 migration 追加を進める。
   - 実装の詳細は [2026-03-20-01-admin-auth-guard-and-role-migration-plan.md](./2026-03-20-01-admin-auth-guard-and-role-migration-plan.md) を参照。

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
