# Rails標準認証（パスワード認証）の実装手順

## 前提
- Rails 8 の標準認証ジェネレータを利用する（bin/rails generate authentication）
- 新規ユーザー作成機能は生成されないので、自前で実装が必要。
- `users` テーブルに `password_digest` カラム`email_address` カラムがある
- Active Job が動く（`deliver_later` を使うため）
  - Active Job実装前であればpasswordコントローラーを`PasswordsMailer.reset(user).deliver_now`と一時的に`.deliver_now`にすることで確認できる。
  - gem "letter_opener_web"で確認


## Step 1. 認証ジェネレータで “セッション土台” を作る
```bash
make exec
bin/rails generate authentication
bin/rails db:migrate
```
- sessionsテーブルや、認証用の concern / controller などが生成される
- （要検証）既にusersテーブルを自前で作成している場合、ジェネレータが一部の生成をスキップすることがあるっぽい
  - 今回はusers周りでコンフリクトが出たため、生成物の一部を手動で調整した
  - その際に sessions テーブル作成の migration も作られなかった（もしくは取りこぼした）可能性がある
  - 生成ログがもう残っていないため、根本原因は特定できていない
- 対処：sessions テーブルが無い場合は、別途 migration を追加して作成する
```bash
bin/rails g migration CreateSessions user:references ip_address:string user_agent:string
```
- 参考：users未作成の素のRailsアプリで `generate authentication` を試したところ、sessionsテーブル用migrationが自動生成されることは確認できた

## Step 2. Userモデルを “標準の前提” に合わせる
`app/models/user.rb`
```rb
# app/models/user.rb
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  has_many :posts, dependent: :restrict_with_error
end
```

## Step 3. Userモデルに “パスワードリセット用トークン” を定義する
`app/models/user.rb`
```rb
class User < ApplicationRecord
  # ...既存...

  generates_token_for :password_reset, expires_in: 15.minutes do
    password_digest&.last(10)
  end

  def self.find_by_password_reset_token!(token)
    find_by_token_for!(:password_reset, token)
  end
end
```

## Step 4. ルーティング
`config/routes.rb`
```rb
# config/routes.rb
  # ...既存...
  resource :password, only: %i[new create]
  resources :passwords, only: %i[edit update], param: :token
```
## Step 5. 認証動作確認
1) テストユーザー作成
```bash
make rails-c
User.create!(
  email_address: "test@example.com",
  password: "Password1!",
  password_confirmation: "Password1!"
)
```
2) ログイン確認（正しいパスワード）
- http://localhost:3000/session/new へアクセス
- test@example.com / Password1! でログインできること（ログイン後ページへ遷移すること）

3) ログアウト確認
- ログイン状態でログアウト操作を行う
- ログイン画面に戻ること（または未ログイン扱いになること）

4) ログイン確認（誤ったパスワード）
- http://localhost:3000/session/new へアクセス
- test@example.com / WrongPassword1! でログインできず、エラーメッセージが表示されること

5) アクセス制御（認証必須の確認）
- 未ログイン状態で「ログイン必須ページ」にアクセスする
- ログイン画面へリダイレクトされること
- その後ログインすると、対象ページにアクセスできること

6) パスワードリセット
- http://localhost:3000/passwords/new へアクセス
- test@example.com を入力して送信

- letter_opener_web でメールを確認する
  - http://localhost:3000/letter_opener
  - メール本文のリンクを開けること

- パスワード更新 → 再ログイン確認
  - edit 画面で新しいパスワードを入力して送信
  - 「パスワードがリセットされました」が表示され、ログイン画面へ戻ること
  ‐ 新しいパスワードでログインできること

- 無効トークンの確認
  - メールのリンクを再度開くと「リンクが無効か、有効期限が切れています。」の表示とともにパスワードリセット画面へリダイレクトされること

## 参考
- Rails Security Guide
  - https://guides.rubyonrails.org/security.html
- Rails Guides: Sign Up and Settings(generates_token_for)
  - https://guides.rubyonrails.org/sign_up_and_settings.html#new-email-confirmation
- ActiveRecord::generates_token_for
  - https://api.rubyonrails.org/classes/ActiveRecord/TokenFor/ClassMethods.html
- Rails 8で基本的な認証ジェネレータが導入される（翻訳）
  - https://techracho.bpsinc.jp/hachi8833/2024_10_21/145343
- Rails8で追加された認証ジェネレータを試してみた
  - https://qiita.com/maabow/items/71078c5fe67ed53bcc02
