# Issue 194: Kamal proxy と Thruster の構成比較と採用方針

## 目的

- このリポジトリにおける `Kamal proxy` / `Thruster` の採否を比較し、採用方針を決定する。
- 不採用とした依存・設定を安全に整理する。

## 対象 Issue

- Repo: `Iwasaki-Y0125/tonetwo`
- Issue: `#194`
- Title: `[deploy] Kamal proxy と Thruster の構成比較と採用方針の決定`

## 背景

- 調査開始時点では `thruster` Gem と Kamal 設定が repo に存在していたが、採用要否は未整理だった。
- 本番起動は `bundle exec puma -C config/puma.rb` で、現行本番に Kamal / Thruster が入っているかを切り分けて確認した。
- 現行構成は生成AIベースで組まれた履歴があり、`Kamal proxy` と `Thruster` のどちらを採用するのが妥当か未精査。
- Rails 8 では Thruster が標準寄りに案内されているため、このアプリでも採用すべきかを根拠ベースで判断したい。

## このドキュメントで決めること

- 現在の本番配信経路を、設定ファイル単位で説明できる状態にする。
- `Render + Puma` を基準に、Kamal / Thruster の追加価値を整理する。
- このアプリの要件に照らして、採用方針を 1 つに決める。
- 不採用側の依存・設定をどう扱うかを決める。
- 必要なら別 Issue / 実装タスクに分割できる粒度まで落とす。

## 参照対象

### ローカル一次情報

- [Gemfile](../../../Gemfile)
- [Gemfile.lock](../../../Gemfile.lock)
- [Dockerfile](../../../Dockerfile)
- [docker-compose.dev.yml](../../../docker-compose.dev.yml)
- [bin/docker-entrypoint](../../../bin/docker-entrypoint)
- [config/puma.rb](../../../config/puma.rb)

### 公式一次情報

- Rails 8 / Thruster の公式ドキュメント
- Kamal の公式ドキュメント

## 調査手順

1. ローカル設定を確認する。
2. Rails 8 / Thruster / Kamal の公式一次情報を確認する。
3. 現在構成と候補構成の責務分担を比較表にする。
4. このアプリに必要な機能と不要な重複を整理する。
5. 採用方針と、依存・設定の整理方針を結論としてまとめる。

## 調査メモ

### 1. 現在構成の整理

#### 確認観点

- 本番プロセス起動点
- リバースプロキシの配置場所
- TLS 終端の位置
- 静的ファイル配信の責務
- 圧縮・キャッシュ・HTTP/2 の担当
- ヘルスチェックや `/up` の通り方

#### 確認結果

- 結論: 現行本番は `Cloudflare -> Render Web Service -> Puma -> Rails`。調査時点でも Kamal / Thruster は本番経路で未使用だったため、削除した。

#### 補足事項

- [Dockerfile](../../../Dockerfile) の本番起動コマンドは `bundle exec puma -C config/puma.rb`。
- [bin/docker-entrypoint](../../../bin/docker-entrypoint) は `puma` 起動時に `./bin/rails db:prepare` を実行してから本体へ `exec` する。
- [config/puma.rb](../../../config/puma.rb) では Puma が `PORT` 既定値 `3000` を listen する。
- Render 本番設定では `Dockerfile Path = ./Dockerfile`、`Docker Command` は空欄で、Dockerfile の `CMD` / `ENTRYPOINT` がそのまま使われている。
- Render の起動ログでも `Puma starting in cluster mode...` が確認できている。
- 調査時点では `thruster` は [Gemfile](../../../Gemfile) と `bin/thrust` に存在したが、本番起動経路へ組み込む記述は見当たらなかった。
- 調査時点では Kamal の `proxy:` 設定と `bin/kamal`、`.kamal/` が存在したが、現行 Render 本番の起動経路やログには Kamal 利用の痕跡は見当たらなかった。

#### 暫定の責務分担

```text
Client
  -> Cloudflare
  -> Render Web Service
  -> Puma (:3000)
  -> Rails
```

- `Cloudflare`: 公開DNS（名前解決） / エッジ TLS / CDN / WAF の候補
- `Render Web Service`: 現行本番の origin
- `Puma`: Rails アプリ本体の HTTP サーバ
- `Thruster`: 調査時点ではインストール済みだったが、この経路には入っていなかった
- `Kamal proxy`: 調査時点では repo に設定があったが、現行本番経路には入っていなかった

### 2. 公式標準構成の整理

#### Rails 8 / Thruster

- 調査時点のローカル依存は `rails 8.1.2`、`thruster 0.1.19`。
- Rails 8 系では、Thruster は Puma の前に置く軽量 proxy として案内されている。
- 役割は主に `HTTP/2`、TLS、静的ファイル配信、アセット圧縮、基本的なキャッシュ、`X-Sendfile` 加速。
- つまり Thruster は、単一コンテナ構成で Puma の前に置く Web サーバ相当の位置づけ。

#### Kamal proxy

- 調査時点のローカル依存は `kamal 2.10.1`。
- Kamal proxy は、Kamal のデプロイ時に前段でリクエストを受ける proxy。
- 役割は主に host 受付、アプリコンテナへの転送、`/up` ヘルスチェック、HTTPS、HTTP -> HTTPS リダイレクト。
- つまり Kamal proxy は、配信最適化よりも「安全に切り替えるためのデプロイ入口」の位置づけ。

### 3. 構成比較

比較対象は `Render + Puma` 維持と `Render + Thruster + Puma` の 2 案に絞る。`Kamal proxy + Puma` は現行 Render 運用では採用理由が薄く、不採用候補として別管理に回す。

| 観点 | Render + Puma | Render + Thruster + Puma | このアプリでの論点 |
| --- | --- | --- | --- |
| TLS | ○ | ○ | Cloudflare が前段にいるため、origin 側 TLS の優先度は相対的に低い。 |
| HTTP/2 | × | ○ | Cloudflare が前段で HTTP/2 を受けられるなら優先度は低い。 |
| 圧縮 | × | ○ | Cloudflare と役割が重複しやすい。 |
| キャッシュ | △ | ○ | Cloudflare で `cf-cache-status: HIT` を確認しており、origin 側でどこまで持つかが論点。 |
| 静的ファイル配信 | △ | ○ | Rails 側で `public_file_server.headers` を設定済み。専用前段が必要かを判断する。 |
| X-Sendfile / X-Accel 相当 | × | ○ | 現状の repo では `send_file` / `send_data` 利用は見当たらず、優先度は低い。 |
| 監視・運用負荷 | ○ | △ | 現行は Render + Puma で動作しており、追加レイヤーは保守対象を増やす。 |
| Cloudflare との重複 | ○ | × | Cloudflare 前提なら Thruster の価値がどこまで残るかが論点。 |

### 4. このアプリの要件整理

| 要件 | 必須/任意 | 根拠 | 備考 |
| --- | --- | --- | --- |
| TLS | 必須 | [config/environments/production.rb](../../../config/environments/production.rb) で `config.assume_ssl = true` と `config.force_ssl = true` を設定 | ただし終端位置は Cloudflare / origin のどちらでもよい。 |
| HTTP/2 | 任意 | repo 上で HTTP/2 必須機能は見当たらない | あると望ましいが、採用判断の決定打ではない。 |
| 圧縮 | 任意 | 静的アセット配信はあるが、Cloudflare 前段で補完可能 | origin 側で必須とはまだ言えない。 |
| キャッシュ | 必須 | [config/environments/production.rb](../../../config/environments/production.rb) で `public, max-age=1.year` を設定。Cloudflare 側でも HIT を確認 | 静的アセットのキャッシュは必要。実装主体は Cloudflare 優勢。 |
| 静的ファイル配信 | 必須 | Rails は fingerprinted assets を配信する。Active Storage も [config/storage.yml](../../../config/storage.yml) で local | ただし高機能な専用前段が必須とは限らない。 |
| X-Sendfile | 任意 | repo 上で `send_file` / `send_data` の利用は未確認 | 現時点では採用理由として弱い。 |
| 運用コスト | - | 現行は Render Web Service 1 本で運用中 | 運用対象を不必要に増やさないこと。 |

## 結論

### 採用方針

- 現行は `Render + Puma` を維持し、`kamal` / `Kamal proxy` / `thruster` は削除する。

### 理由

- 現行本番は `Cloudflare -> Render Web Service -> Puma -> Rails` で動作しており、`kamal` / `Kamal proxy` / `thruster` は本番経路で未使用。
- Cloudflare と役割が重複する部分が多く、運用対象を増やす理由が薄い。

## 不採用側の整理方針

- `kamal` gem、`config/deploy.yml`、`.kamal/`、`bin/kamal` を削除した。
- `thruster` gem と `bin/thrust` を削除した。

## 作業内容

- `kamal` gem を削除した。
- `thruster` gem を削除した。
- `Gemfile.lock` を更新した。
- `bin/kamal` と `bin/thrust` を削除した。
- `config/deploy.yml` と `.kamal/` を削除した。
- 関連 docs に「MVP後に Basic認証を削除済み」の追記を入れた。
- Render + Puma の現行起動経路は維持する。

## 次アクション

- [x] 現在の本番配信経路を整理する
- [x] Rails 8 / Thruster の公式一次情報を確認する
- [x] `Render + Puma` と `Render + Thruster + Puma` の責務差分を比較する
- [x] このアプリの要件に照らして利点・欠点を整理する
- [x] 採用方針を 1 つに決め、理由を明文化する
- [x] 不採用側の設定・依存をどう扱うか決める
- [x] 必要な変更はこの Issue のスコープで完了したため、別 Issue / 実装タスクへの分割は不要と判断する

## 受け入れ条件

- [x] 現在構成と候補構成の差分が、設定ファイル単位で説明できる
- [x] 採用方針が「Rails 8 の一般論」ではなく、このリポジトリの現状構成を根拠に決まっている
- [x] `thruster` を残す / 外す場合の影響範囲が明文化されている
- [x] 次にやる実装作業があれば、別 Issue に切り出せる粒度まで整理されている
