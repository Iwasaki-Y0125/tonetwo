# Custom Domain / DNS クイック整理（Render + Cloudflare）

このメモは、`www.tonetwo.net` の Custom Domain 設定時に混乱しやすい用語だけを短く整理する。

## 1. 用語

- ルートドメイン（裸ドメイン）: `tonetwo.net`
- サブドメイン: `www.tonetwo.net`
- `@`: DNSで「ルートドメイン（`tonetwo.net` そのもの）」を表す記号
- `CNAME`: ドメイン名を別のドメイン名へ向けるレコード
- `A`: ドメイン名をIPアドレスへ向けるレコード

## 2. なぜレコードが2つ必要か

- 利用者は `www.tonetwo.net` と `tonetwo.net` のどちらでもアクセスするため、両方の導線が必要。
- そのため DNS 設定は `www` 用と `@` 用の2件を作る。

## 3. Render 画面で控える値

- `www` 側の CNAME ターゲット: `tonetwo.onrender.com`
- `@` 側で A を使う場合のターゲット: Render 画面に表示されたIP（例: `216.24.57.1`）

注意:
- `@` に CNAME を置けるかどうかは DNS プロバイダー仕様に依存する。
- 使う値は必ず「その時点の Render 画面表示値」を優先する。

## 4. Cloudflare 登録時の実務メモ

- 初回切り分けは `DNS only`（灰色雲）で登録する。
- 反映には時間がかかることがある（数分〜最大24時間程度）。
- 登録後、Render 側の検証（`確認する`）が通ることを確認する。

## 5. これは機密情報か

- 以下は機密情報ではない: ドメイン名、DNS レコード（CNAME/A）、公開ホスト名（`*.onrender.com`）
- 以下は機密情報: `SECRET_KEY_BASE`、DBパスワード付き接続文字列、APIキー、トークン
