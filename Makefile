.PHONY: ch dev dev-restart dev-build dev-build-nocache down clean ps logs logs-web logs-db exec rails-c bundle-install npm npm-root css-build css license-report g-migr db-migrate db-prepare db-reset g-con g-model test importmap-audit rubocop rubocop-a help

.DEFAULT_GOAL := help

help: ## ターゲット一覧を表示
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z0-9][a-zA-Z0-9_-]*:.*## / {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# constants
# 共通: 環境変数 + 非root実行
OPTS      := -e HOME=/tmp --user $(shell id -u):$(shell id -g)

# root 実行用（user 指定なし）
OPTS_ROOT := -e HOME=/tmp

# exec 用: /app を起点にする（Gemfile迷子防止）
EXEC_OPTS      := -w /app $(OPTS)
EXEC_OPTS_ROOT := -w /app $(OPTS_ROOT)

# run 用: workdir は --workdir を使う（docker compose run の正式オプション）
RUN_OPTS  := --workdir /app $(OPTS)

DEV    := docker compose --env-file .env.dev -f docker-compose.dev.yml
RAILS  := bin/rails
BUNDLE := bundle exec

# Makeショートカット使い方
# ターミナルで下記のように 'make ???' のように使う
# $ make dev
# $ make down

# *初回の Rails new (初回だけコメントアウト外すかコピペで実行。初回以降実行するとRails newに上書きされるので注意)
# dev-new:
# 	docker compose -f docker-compose.dev.yml run --rm --no-deps --user "$(id -u):$(id -g)" web rails new . --force --database=postgresql

# ====================
# 権限
# ====================

ch:
	sudo chown -R $${USER}:$${USER} .

# ====================
# 起動系
# ====================

# 開発 - 起動
dev: ## 開発 - 起動
	$(DEV) up

# 開発 - 再起動
dev-restart: ## 開発 - 再起動
	$(DEV) restart web

# 開発 - ビルド
dev-build: ## 開発 - ビルド
	$(DEV) up --build

# 開発 - 再ビルド（キャッシュ不使用）
# イメージとキャッシュを消して再ビルド→再起動
# 再ビルドは時間がかかるので、基本的に*Dockerを書き換えた場合のみ*行うこと
dev-build-nocache: ## 開発 - 再ビルド（キャッシュ不使用）
	$(DEV) build --no-cache web
	$(DEV) up


# ====================
# 停止・掃除
# ====================

# 開発環境停止
down: ## 開発環境停止
	$(DEV) down

# コンテナとボリューム（DB/Gemなど)だけ消える
# キャッシュとイメージは消えないので、*Dodckerを書き換えた場合は、dev-build-nocacheを使うこと*
clean: ## キャッシュ削除（コンテナ/ボリューム）
	$(DEV) down -v


# ====================
# 状態確認・ログ
# ====================

# 実行中のコンテナ一覧
ps: ## 実行中のコンテナ一覧
	$(DEV) ps

# ログ確認
logs: ## ログ確認
	$(DEV) logs -f

# webのみのログ確認
logs-web: ## webのみのログ確認
	$(DEV) logs -f web

# dbのみのログ確認
logs-db: ## dbのみのログ確認
	$(DEV) logs -f db

# *ランタイムにNode.jsが存在しないか確認のコマンドメモ
# docker compose --env-file .env.prod.local -f docker-compose.localprod.yml exec web sh
# node -v
# sh: node: not found　と出れば成功

# ====================
# bash / railsコンソール起動
# ====================

# bash起動
exec: ## bash起動
	$(DEV) exec $(EXEC_OPTS) web bash

# railsコンソール起動
rails-c: ## railsコンソール起動
	$(DEV) exec $(EXEC_OPTS) web $(RAILS) c

# Gemインストール
bundle-install: ## Gemインストール
	$(DEV) exec $(EXEC_OPTS) web sh -lc 'bundle install'

# ====================
# npm
# ====================

# make npm p="tailwindcss postcss autoprefixer daisyui"
npm: ## npmパッケージインストール
	$(DEV) exec $(EXEC_OPTS) web npm install -D $(p)

npm-root: ## rootでnpmインストール（初回の権限修正用）
	$(DEV) exec -u root $(EXEC_OPTS_ROOT) web npm install -D $(p)
	$(DEV) exec -u root $(EXEC_OPTS_ROOT) web chown -R 1000:1000 /app/node_modules /app/package.json /app/package-lock.json

# CSSビルド
css-build: ## CSSビルド
	$(DEV) exec $(EXEC_OPTS) web npm run build:css

# CSSウォッチ
css: ## CSSウォッチ
	$(DEV) exec $(EXEC_OPTS) web npm run watch:css

# ライセンスレポート発行
license-report: ## ライセンスレポート発行
	$(DEV) exec $(EXEC_OPTS) web $(BUNDLE) ruby script/licenses/gems_md_report.rb > docs/licenses/gems.md

# ====================
# DB操作(開発用)
# ====================

# マイグレーション
db-migrate: ## マイグレーション
	$(DEV) exec $(EXEC_OPTS) web $(RAILS) db:migrate

# マイグレーションファイル生成
# make g-migr G="AddIndexToPosts"
g-migr: ## マイグレーションファイル生成
	$(DEV) run --rm $(RUN_OPTS) web $(RAILS) g migration $(G)

# 初回マイグレーション
db-prepare: ## 初回マイグレーション
	$(DEV) exec $(EXEC_OPTS) web $(RAILS) db:prepare

# DB全消し（開発専用）
db-reset: ## DB全消し（開発専用）
	$(DEV) exec $(EXEC_OPTS) web $(RAILS) db:drop db:create db:migrate

# ====================
# 生成
# ====================

# コントローラ生成
# make g-con G="Posts index show"
g-con: ## コントローラ生成
	$(DEV) run --rm $(RUN_OPTS) web $(RAILS) g controller $(G)

# モデル生成
# make g-model G="Post title:string body:text"
g-model: ## モデル生成
	$(DEV) run --rm $(RUN_OPTS) web $(RAILS) g model $(G)


# ====================
# テスト
# ====================

# Minitest一括実行（db:test:prepare + test + test:system）
test: ## Minitest一括実行
	$(DEV) exec $(EXEC_OPTS) web bash -lc 'bin/rails db:test:prepare && bin/rails test && bin/rails test:system'

# importmap脆弱性監査
importmap-audit: ## importmap監査
	$(DEV) exec $(EXEC_OPTS) web bin/importmap audit

# Rubocop実行
rubocop: ## Rubocop実行
	$(DEV) exec $(EXEC_OPTS) web $(BUNDLE) rubocop

# Rubocop自動修正
rubocop-a: ## Rubocop自動修正
	$(DEV) exec $(EXEC_OPTS) web $(BUNDLE) rubocop -a
