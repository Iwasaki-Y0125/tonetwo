## 1. 認証周り：メール確認・メール変更

### 1.1 方式
- トークンテーブルは作らず、Railsの ActiveRecord::TokenFor（generates_token_for） を利用する方針
- `email_verified_at` は「確認済み状態」を永続化するために必要
  - トークンの失効は「リンクの有効性」であり、確認済みかどうかは別の概念

### 1.2 メールアドレス変更
- `users` に `pending_email_address` を持つ（変更先の一時保存）
- UI案:
  - 現在メール + パスワード + 変更先メールを入力
  - 認証が通れば pending に保存し、変更先に確認メール送信
  - リンク踏むまで `email_address` は変えない
  - リンク踏んだら `email_address = pending_email_address`、pending を NULL、`email_verified_at` 更新
- パスワード入力を求める理由
  - 変更先にタイポがあるとログイン不能になる事故を減らすため
