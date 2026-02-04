# Rails標準でマジックリンク認証を実装するための知識をざっくりまとめ(2026-01-13時点)

### **技術検証後、認識相違があれば適宜修正すること**

## 目的
- 外部Gemへの依存を最小化し、Rails標準機能で「マジックリンク（パスワードレス）認証」を実装できるようにする
- 実装のブラックボックス化を避け、挙動を自分で追える構成にする

---

## 前提
- **入口**: メールに届くマジックリンクで本人確認
- **継続**: ログイン状態はアプリ側のセッション（DBセッション）で維持
- **トークンはDBに保存しない**（署名付きトークンを採用）
- **リンクの使い回しを防ぐ**（User側のnonce等で失効させる）

---

## 用語
- **マジックリンク**: メールに届いたURLを踏むだけでログインできる方式（パスワード入力なし）
- **トークン**: URLに埋め込む一時的な文字列（改ざん検知・期限管理が必要）
- **nonce**: 「使い回し防止」のための値。成功時に更新して、過去リンクを無効化する
- **セッション**: ログイン状態を維持する仕組み（Cookie / DBセッションなど）

---

## Rails標準で使う主要機能（何が何を担当するか）
### 1) ActiveRecord::TokenFor（トークン生成・検証）
- Userモデルで「目的ごとのトークン」を生成できる
- `expires_in` で期限を付けられる
- 署名付きで改ざんに強い（※秘密鍵に依存）
- `find_by_token_for` で検証しつつユーザーを取得できる（失敗時は `nil`）

### 2) Action Mailer（メール送信）
- ログイン用URLを含むメールを送る
- `default_url_options` や host/protocol が正しくないとURLが壊れる

### 3) Rails 8 認証ジェネレータ（セッション管理の“型”）
- `bin/rails generate authentication` が作る session 管理を継続ログインに使う
- 今回は「パスワードでログイン」部分は使わず、マジックリンクを入口にする

---

## 認証フロー
1. ユーザーがメールアドレスを入力して送信
2. アプリがログイン用リンクをメール送信（セキュリティのため存在確認画面なし）
3. ユーザーがリンクをクリック
4. トークンを検証してユーザー特定
5. セッションを開始（ログイン状態になる）
6. nonce を更新して「このリンクを使い捨て化」
7. 期限切れ/不正トークンならエラー画面へ

---

## データ設計（最小）
### users
- `email` : string（ユニーク）
- `magic_link_nonce` : integer（default 0 / null false）
  - トークン生成ロジックに混ぜる
  - ログイン成功時にインクリメントして使い回し無効化

### sessions
- Rails 8 認証ジェネレータが作るDBセッションテーブルを利用
  - ログイン中の識別をここで持つ（Userと紐づく）

---

## “使い回し防止”の考え方（nonce）
- トークン生成時に `magic_link_nonce` を混ぜる（署名対象に含める）
- ログイン成功時に `magic_link_nonce` を更新（例: +1）
- すると **同じトークンを再利用しても一致しなくなる**（=過去リンクは失効）

注意:
- 二重クリックや並行アクセスがあり得るため、更新はロック（`with_lock`）で安全にする

---

## ルーティング設計
- `/magic_login/new` : メール入力フォーム
- `POST /magic_login` : メール送信
- `GET /magic_login/:token` : トークン検証→ログイン

---

## コントローラ設計
### MagicLoginsController
- `create`
  - email正規化（trim/downcase）
  - ユーザー作成方式を決める（find_or_create / 既存のみ）
  - トークン生成 → メール送信
  - 「送信しました」画面へ（ユーザー存在は匂わせない）

- `show`
  - トークン検証 → user取得
  - 取得できない場合は「無効/期限切れ」へ
  - 取得できたら（ロックして）
    - nonce更新
    - セッション開始
  - ログイン後のページへ

---

## ActionMailerの注意点
- URL生成には host が必要
  - `default_url_options` / `config.x.app_host` などで環境ごとに定義する
- 開発環境では確認用に `letter_opener_web` 等を使うと楽（本番依存ではない）

---

## セキュリティ上の注意点
- トークンに期限（例: 15分）を必ず付ける
- メール送信のレスポンスは常に同じ（ユーザー存在の有無を漏らさない）
- ログイン成功時に nonce 更新でリンクを使い捨てにする
- レート制限（将来）
  - 同一IPや同一メールへの過剰送信を抑止（Rack::Attack等）

---

## UX上の注意点
- マジックリンクは「メール往復」が必ず入る
  - 対策: ログイン保持を適切に長めにする(セキュリティに問題ない範囲の検討)
- 認証メールが届かない場合の説明を丁寧に
  - 迷惑メール、ドメイン拒否、送信遅延などを案内する

---

## テスト観点
- トークン検証が通るとログインできる
- 期限切れトークンは弾かれる
- 使い回し（nonce更新後の同一トークン）は弾かれる
- 存在しないメールでも「送信しました」的に見える（情報漏えいしない）
- メールが送信される（ActionMailerのdeliveries確認）

---

## 実装手順
1. `bin/rails generate authentication` を実行して session 管理の土台を作る
2. users に `magic_link_nonce` を追加（migration）
3. Userモデルに TokenFor を定義（purpose + expires_in + nonce）
4. ルーティング追加（new/create/show）
5. MagicLoginsController 作成
6. Mailer 作成（loginリンク送信）
7. 画面（new/送信完了/エラー）を用意
8. テスト追加（期限・使い回し・メール送信）
9. 本番メール設定（ENV/host/protocol）を整える

---

## 参考
- Rails Security Guide
  - https://guides.rubyonrails.org/security.html
- Rails Guides: Sign Up and Settings(generates_token_for)
  - https://guides.rubyonrails.org/sign_up_and_settings.html#new-email-confirmation
- ActiveRecord::generates_token_for
  - https://api.rubyonrails.org/classes/ActiveRecord/TokenFor/ClassMethods.html
