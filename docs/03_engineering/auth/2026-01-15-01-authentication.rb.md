# Rails標準認証（authentication.rb）理解メモ：Session と Cookie の役割分担

このメモは `app/controllers/concerns/authentication.rb` の挙動を、**セッション（DB）**と**クッキー（ブラウザ）**を混同しないために整理したもの。

---

## 0. 用語の整理

### Session（この実装では「DBの sessions テーブル」）
- **ログイン状態の“本体”**。
- `sessions` テーブルのレコード（例：`id`, `user_id`, `user_agent`, `ip_address`）が「ログイン中」を表す。
- `Session.find_by(id: ...)` で復元できる。

### Cookie（ブラウザに保存される小さいデータ）
- **ログイン状態の本体ではない**。
- ここでは `session_id`（= DBの sessions.id）を入れておき、次回リクエストでサーバが「どのSessionか」を探すための“鍵”になる。
- `cookies.signed[:session_id]` なので改ざん検知がある。

### Current（リクエスト中だけの一時置き場）
- **1リクエスト中の「現在のセッション」を置く箱**。
- `Current.session` に入れると、そのリクエスト内の他の処理が同じセッションを参照できる。
- リクエストが終わると消える（永続しない）。
- 具体例
  - Currentがないと、
  ```rb
  Session.find_by(id: cookies.signed[:session_id])&.user
  ```
  で逐一SessionとCookieの参照が必要になる。
  - Currentがあれば、
  ```rb
  Current.user
  ```
  だけでリクエスト中使いまわせる。


## 1. `extend ActiveSupport::Concern`の役割
- モジュールの依存関係もきれいに扱えるようになる
  - `included do ... end` : モジュールがコントローラに取り込まれた瞬間に実行される => ログイン処理を定義すれば全アクションでログイン必須にできる
  - `class_methods do ... end` : 例外ルールをクラスメソッドとして定義できる => ログイン不要なアクションに`skip_before_action`をつける
- なお`app/controllers/application_controller.rb`の
```
class ApplicationController < ActionController::Base
  include Authentication
```
でコントローラー全体にincludeされている。


## 2. リクエストの流れ

### A) 普通のページにアクセス（GET /posts など）
1. `before_action :require_authentication` が動く
2. `require_authentication` は `resume_session` を試す
3. `resume_session` は `find_session_by_cookie` を呼ぶ（必要なら）
4. cookie に `session_id` があれば `Session.find_by(id: ...)` でDBから session を取得
5. 取れたら `Current.session` に入り「ログイン中」
6. 取れなければ `request_authentication` でログイン画面へ

---

### B) ログイン実行（POST /session）
1. （パスワード/マジックリンク等で）ユーザー認証に成功
2. `start_new_session_for(user)` を呼ぶ
   - DBに `sessions` レコードを作る（Sessionの本体を作る）
   - cookie に `session_id`（DBの sessions.id）を書き込む（次回の鍵）
   - `Current.session` にも入れる（このリクエスト内でもログイン扱いにする）
3. `redirect_to after_authentication_url` などでレスポンス終了

---

### C) リダイレクト先のページ（次のリクエスト）
1. ブラウザが cookie（session_id）を付けてリクエストしてくる
2. Aの流れと同じく、cookie→DBで `Current.session` を復元
3. 「ログイン中」が成立する

---

## 3. 各メソッドの意味（authentication.rb内）

### 3.1 include されたときの設定
- `before_action :require_authentication`
  - デフォルトで全ページをログイン必須にする
- `helper_method :authenticated?`
  - view でログイン状態を見られるようにする

### 3.2 allow_unauthenticated_access
- `skip_before_action :require_authentication`
- ログイン画面・パスワード再設定など「ログイン不要」ページだけ門番を外すための宣言。

### 3.3 require_authentication（門番）
- `resume_session || request_authentication`
- セッション復元できれば通す。できなければログインへ飛ばす。

### 3.4 resume_session（復元の入口）
- `Current.session ||= find_session_by_cookie`
- すでに `Current.session` があればそれを使う（1リクエスト中は使い回す）
- なければ cookie を見てDBから session を探す

### 3.5 find_session_by_cookie（cookie→DB）
- `cookies.signed[:session_id]` があれば、
- `Session.find_by(id: ...)` でDBの sessions を取得する

### 3.6 request_authentication（未ログイン時）
- `session[:return_to_after_authenticating] = request.url`
  - ログイン後に元のURLへ戻るため保存
- `redirect_to new_session_path`
  - ログイン画面へ

### 3.7 after_authentication_url（ログイン後の戻り先）
- `session.delete(:return_to_after_authenticating) || root_url`
- 保存していたURLがあればそこへ、無ければトップへ

### 3.8 start_new_session_for（ログイン開始：本体＋鍵）
- **DBに Sessionを作る**：`user.sessions.create!(...)`
  - これがログイン状態の“本体”
- **Cookieに session_id を書く**：`cookies.signed.permanent[:session_id] = session.id`
  - 次回以降、どのSessionかを指す“鍵”
- **Current.session をセット**：`Current.session = session`
  - このリクエスト内でも一貫してログイン扱いにするための一時置き場

### 3.9 terminate_session（ログアウト）
- `Current.session.destroy`：DBの session を削除（本体を消す）
- `cookies.delete(:session_id)`：ブラウザの鍵も消す

---

## 4. よくある混乱ポイント

- **Cookie = ログイン状態そのもの** ではない
  → Cookieは「どのDBセッションか」を探すための“鍵（ID）”を入れてるだけ

- **DB Session = ログイン状態の本体**
  → 本体が消えたら、cookieが残ってても復元できず未ログインになる

- **Current = そのリクエスト中だけの一時置き場**
  → 次のリクエストではまたcookieから復元する（Currentは残らない）

---

## 5. まとめ（1行）

- **DB Sessionが本体**
- **Cookieは本体を指す鍵（session_id）**
- **Currentはリクエスト中の一時キャッシュ**

## 6. 参考

- Rails Guides: Sign Up and Settings
 https://guides.rubyonrails.org/sign_up_and_settings.html

- Ruby / Rails関連 2023.03.01
Rails API: ActiveSupport::ConcernとModule::Concerning（翻訳）
https://techracho.bpsinc.jp/hachi8833/2023_03_01/126773
