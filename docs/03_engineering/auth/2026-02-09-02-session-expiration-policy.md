# セッション有効期限ポリシー（MVP）

## 結論
- セッション期限は以下で運用する。
  - **アイドル期限: 7日**（最終操作から7日で失効）
  - **絶対期限: 30日**（操作継続中でも作成から30日で失効）

---

## 背景
- 認証導線は MVP で Rails 標準のパスワード認証を採用した。
- ただし、`cookies.signed.permanent` のような無期限に近い運用は、セッションID流出時の悪用期間が長くなる。
- 一方で、毎回短期間で再ログインを要求すると MVP 初期の体験コストが高くなる。

---

## 判断理由

### 1) セキュリティと UX のバランス
- アイドル期限を 7 日にすると、放置端末での乗っ取りリスクを抑えつつ、数日おきでログインするユーザーの体験を阻害しない。
- 絶対期限を 30 日に置くことで、「長期継続セッション」を固定化しない。

### 2) MVP の運用容易性
- 3日以下のアイドル期限はセキュリティ寄りだが、再ログイン離脱や、再ログイン問い合わせ増のリスクがある。
- 14日以上は、紛失端末・共有端末のリスクを引き上げる。
- MVP では中間の **7日 / 30日** を初期値とし、運用データで再評価する。

### 3) 実装整合性
- Cookie 側だけでなくサーバ側 `sessions` テーブルの時刻で失効判定することで、期限管理の一貫性を確保する。

---

## 実装方針

### 定数
- `config/initializers/session_policy.rb`
  - `SessionPolicy::IDLE_TIMEOUT = 7.days`
  - `SessionPolicy::ABSOLUTE_TIMEOUT = 30.days`

### 適用箇所
- `app/controllers/concerns/authentication.rb`
  - セッション復元時に以下を判定:
    - `updated_at < IDLE_TIMEOUT.ago`
    - `created_at < ABSOLUTE_TIMEOUT.ago`
  - 期限切れ時:
    - `Session` レコード削除
    - `session_id` cookie 削除
  - 有効時:
    - `session.touch` でアイドル期限を延長
  - Cookie 発行:
    - `expires: ABSOLUTE_TIMEOUT.from_now`
    - `httponly: true`
    - `same_site: :lax`
    - `secure: Rails.env.production?`

---

## テスト
- `test/integration/authentication_flow_test.rb`
  - ログイン成功/失敗
  - ログアウト
  - 認証必須ページへの未ログインアクセス時のリダイレクト
  - **アイドル期限切れセッションが無効化されること**
  - **絶対期限切れセッションが無効化されること**

---

## セッション付帯情報（IP / UA）の保持方針

### 現時点の決定事項
- `sessions` テーブルでは `ip_address` と `user_agent` を保持する。
- 用途は以下。
  - `ip_address`: 不正アクセス対策・インシデント時の調査補助
  - `user_agent`: 障害解析（特定ブラウザ依存の不具合調査）と異常検知の補助情報

### 今回の実装状況
- ログイン時に `ip_address` / `user_agent` を保存している。
- 一方で、保持期間と定期削除ジョブ（Cron + Rake）は未実装。

### 保留（本リリースまでに決める/実装すること）
- 保持期間の明文化（例: 期限超過セッション削除後、監査目的で追加保持するかどうか）。
- 期限超過セッションの定期削除ジョブを実装する（Cron + Rake）。
- プライバシーポリシーに、取得目的・保持期間・削除方針を実装内容と一致させて明記する。

---

## 見直し条件
- 本リリース後、以下のどれかが発生したら再評価する。
  - 再ログイン離脱が有意に増える
  - セッション関連インシデント/不正アクセス兆候が増える
  - MFA やデバイス管理機能を導入する

---

## 参考（一次ソース）
- Rails Guides: Security
  - https://guides.rubyonrails.org/security.html
- Rails Guides: Action Controller Overview（Cookies）
  - https://guides.rubyonrails.org/action_controller_overview.html#cookies
