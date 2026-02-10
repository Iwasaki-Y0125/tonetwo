# ユーザー同意ポリシー（MVP）

## 結論
- ユーザー同意は `users` テーブルで管理する。
- 保存項目は以下の4つ。
  - `terms_accepted_at: datetime`
  - `terms_version: string`
  - `privacy_accepted_at: datetime`
  - `privacy_version: string`
- 同意チェックはフロントだけでなく、サーバ側で必須にする。

---

## 背景
- 画面の `required` チェックのみでは、直接 `POST /sign_up` で回避できる。
- そのため、同意有無の判定と同意メタ情報（日時/版）はサーバ側で確定する。
- MVPでは履歴テーブルは作らず、まずは「最新同意状態」を `users` に保持する。

---

## 方針（決め方）

### 1) サーバ側を正とする
- クライアントから受ける同意入力は `terms_agreed` のみ。
- `terms_accepted_at` など4カラムはクライアント入力を受けず、モデル側で自動設定する。

### 2) 規約版は数値ではなく文字列で管理する
- `terms_version` / `privacy_version` は `string` を採用。
- 版は計算対象ではなく識別子のため、`float` より `string` が適切。

### 3) MVPは単一レコード管理、将来は履歴テーブル分離
- 現在は「どの版に同意したか」を追える最小構成。
- 改定履歴や再同意履歴を厳密運用する段階で `user_policy_consents` などへ拡張する。

---

## 実装

### DB
- `db/migrate/20260210100000_add_policy_consents_to_users.rb`
  - `users` に同意日時/同意版の4カラムを追加。

### Model
- `app/models/user.rb`
  - `attr_accessor :terms_agreed`
  - `validates :terms_agreed, acceptance: { accept: "1" }, on: :create`
  - `before_validation :stamp_policy_consents, on: :create, if: :terms_agreed_accepted?`
  - 同意済み時は `terms_accepted_at` / `privacy_accepted_at` / `terms_version` / `privacy_version` を必須化。
  - 現在版は `CURRENT_TERMS_VERSION` / `CURRENT_PRIVACY_VERSION` 定数で管理。

### Controller
- `app/controllers/sign_ups_controller.rb`
  - `sign_up_params` では `:terms_agreed` のみを permit。

### View
- `app/views/sign_ups/new.html.erb`
  - `form.check_box :terms_agreed, "1", "0"` で同意入力を送信。
  - 同意文言と規約リンクを表示。

---

## 運用ルール
- 規約を更新したら `CURRENT_TERMS_VERSION` / `CURRENT_PRIVACY_VERSION` を更新する。
- 更新後、必要なら「旧版同意ユーザーへの再同意導線」を別タスクで実装する。

---

## テスト
- `test/models/user_test.rb`
  - 同意なしで無効
  - 同意ありで日時/版が保存される
- `test/integration/sign_ups_flow_test.rb`
  - 同意ありで登録成功 + 同意日時/版保存
  - 同意なしで `422` になる

---

## 既知の制約
- 現在は履歴テーブルがないため、複数回同意の時系列履歴までは保持しない。
- 監査要件が強くなった時点で、履歴テーブル分離を再検討する。

---

## 参考（一次ソース）
- Rails Guides: Active Record Validations
  - https://guides.rubyonrails.org/active_record_validations.html
- Rails Guides: Active Record Callbacks
  - https://guides.rubyonrails.org/active_record_callbacks.html
