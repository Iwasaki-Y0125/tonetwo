# テスト方針（Minitest運用）

## 目的
- このリポジトリのテスト方針を定めて、実装時に迷わない形で固定する。

## 結論
- 現在は **Minitest** を採用する。
- テストは **request/integration test を主軸** にし、重要導線のみ system test を追加する。
- CI は既存の `bin/rails db:test:prepare test test:system` を継続する。

## Minitestを採用する理由
- Railsデフォルトであること。既存構成（Gem/CI/生成物）が Minitest 前提で、追加導入コストが最小。
- MVPフェーズでは、テスト導入の初速と保守コストを優先したい。

## テストレイヤの使い分け
- request/integration test
  - 役割: 認可・バリデーション・レスポンス・副作用を安定して検証する。
  - 特徴: 高速、壊れにくい、失敗原因の切り分けがしやすい。
- system test
  - 役割: 画面操作を含む主要導線のE2E確認。
  - 特徴: 実ユーザー操作に近いが、遅く壊れやすい。

## 機能ごとの目安
実際にテストを運用しながら適宜修正する

| 機能 | まず書くテスト | `test:system` を追加する条件 |
|---|---|---|
| ユーザー登録 | `request/integration` | 登録フォームの入力エラー表示や遷移を実画面で担保したいとき |
| ログイン/ログアウト | `request/integration` | ログイン導線全体（入力→遷移→表示）を1本で保証したいとき |
| 投稿作成 | `request/integration` | 投稿フォーム操作や表示反映まで確認したいとき |
| 投稿一覧/詳細表示 | `request/integration` | フィルタUIやタブ切替など画面操作が複雑なとき |
| リプライ/チャット送信 | `request/integration` | 画面上の送信体験（連投不可UI、表示更新）を保証したいとき |
| スタンプ返信 | `request/integration` | ボタン押下後の見た目・無効化状態まで確認したいとき |
| TL絞り込み（全体/おすすめ、ポジ/ネガ） | `request/integration` | UI操作で条件変更し、表示が切り替わる流れを保証したいとき |
| 検索 | `request/integration` | フォーム入力→結果表示の体験を担保したいとき |
| ミュートワード | `request/integration` | 設定画面操作と反映を実画面で確認したいとき |
| ブロック/通報 | `request/integration` | 通報ボタン導線や確認モーダルなどUIが重要なとき |
| 退会 | `request/integration` | 退会画面の確認フロー（確認文言・遷移）を保証したいとき |
| 管理画面（運用系） | `request/integration` | 管理者の主要導線を画面で1本だけ保証したいとき |
| メール通知（登録/返信） | `integration`（mailer/job） | 基本は `system` 不要 |
| レコメンド（名詞＋極性） | `unit` + `integration` | 基本は `system` 不要 |
| モデレーション（禁止語バリデーション） | `model` + `request/integration` | エラー表示UXを確認したいときだけ追加 |

## 運用ルール
- 新機能ごとに、まず request/integration test を追加する。
- system test は「ユーザー価値に直結する1導線」に限定して追加する。
- CI失敗時に調査しやすいこと（速度・安定性・診断性）を優先する。

## 参考（公式一次ソース）
- Rails Guides: Testing Rails Applications
  - https://guides.rubyonrails.org/testing.html
