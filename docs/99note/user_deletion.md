# ToneTwo 仕様メモ：ユーザー削除/退会/強制退会/通報/審査/ペナルティ

## 1. 退会（ユーザー削除）の基本方針

### 1.1 ゴール
- 退会後も、他ユーザー視点では投稿・メッセージ・スタンプ等の関与データは残したい
- 一方で、個人情報であるユーザーのメールアドレスは保持し続けない
- 荒らし対策として、一定期間は同じメールで再登録できないようにしたい

### 1.2 データ保持方針（原則）
- ユーザーが関与して他ユーザーに影響するデータは残す
  - posts
  - messages
  - post_stamps / message_stamps
  - chatrooms（会話履歴自体）
  - abuse_reports / abuse_reviews / abuse_penalties（審査ログ）
- ユーザー本人情報は削除・無効化する
  - users.email_address はダミー値に差し替え("deleted+<user_id>@example.invalid")
  - users は物理削除しない（退会状態は status / deleted_at などで管理する方針）
  - 退会後の投稿/メッセージの owner 表示は ghost_user として扱う

> NOTE: usersはリレーションが多く、物理削除やghost_user.id差し替えの場合、制御が困難である可能性が高い => email_address差し替え＋deleted_atで退会管理

---

## 2. 退会フロー（通常退会）

### 2.1 退会処理でやること（概略）
1. 対象ユーザーを「退会」状態にする（users.deleted_at を設定）
2. 再登録制限のため、メールアドレス由来のdigestをロックテーブルに保存
3. users.email_address をダミー化（例：deleted+<uuid>@example.invalid）
4. users.password_digest 等の認証情報も無効化（ログイン不能にする）
6. sessions を無効化（ログアウト）

---

## 3. メール再利用ロック（荒らし対策）

### 3.1 目的
- 退会直後の「同一メールでの即時再登録」を防ぐ
- 期間は「1か月」などを想定

### 3.2 テーブル案
- `deleted_user_email_locks`
  - `email_digest`: 退会者のemailのdigest
  - `lock_type` ：ロック種別（normal：通常退会 / banned：強制退会）
  - `locked_until`: ロック期限（強制退会は "9999-12-31 23:59:59"）
  - `created_at`

### 3.3 `lock_type`について
- locked_until を NULL にすると「永久ロック」を表現できる
- ただ、nullだけだとなんのためのnullなのか不明瞭のため、一旦、`lock_type`で退会種別を表すことにする
- かといって、lock_typeと合わせてチェックしなくてはならないのは冗長だとは思うし、実際の実装の時に要調整。

---

## 4. 強制退会（モデレーションによる退会）

### 4.1 想定フロー
1. 通報が来る
2. 管理者が審査する
3. 規約違反なら:
   - 投稿/メッセージの露出を止める（全体TL・おすすめから除外）
   - 該当者に規約違反の投稿であることを警告
   - チャットが存在する場合、管理者によるhiddenにする
   - post/message_abuse_penaltiesを加算
4. 累積が閾値を超えたら強制退会(いくつにするかは実際運用してみて検討)
5. 強制退会通知メールを送る
6. 再登録を永久にロック

### 4.2 「警告済みフラグ」について
- 状態フラグは不整合が起きやすいので、原則はイベント（ペナルティ）から導出したい
- MVPでは「警告履歴テーブル」を持たず、post/message_abuse_penaltiesの合算で管理画面での運用

---

## 5. 通報・審査・ペナルティ（Post / Message）

### 5.1 abuse_***テーブルらを1テーブルにしない方針
- polymorphicは便利だが、複雑性が上がるアンチパターン
- テーブル数は増えるがpost と message は分割する方針

### 5.2 テーブル構成（合計5テーブル）
#### Post 用
- `post_abuse_reports`
- `post_abuse_reviews`
- `post_abuse_penalties`

#### Message 用
- `message_abuse_reports`
- `message_abuse_reviews`
- `message_abuse_penalties`

### 5.3 カーディナリティの基本
- `*_abuse_reports -> *_abuse_reviews` は 0..1
  - 通報が作られても、審査されるまで review は存在しない
- `*_abuse_reviews -> *_abuse_penalties` も 0..1
  - 審査結果が「違反」なら penalty を作る、違反でなければ作らない

### 5.4 二重加算（重複ペナルティ）防止の考え方
- 「審査済み日と updated_at」等の更新日時比較は危険（後更新で壊れる）
- penalties を “付与イベント” として別テーブル化すると、構造的に防げる
  - 1 review に対して penalty を 0..1 に制約する（DB制約/アプリ制約）
