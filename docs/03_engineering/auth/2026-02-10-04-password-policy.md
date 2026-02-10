# パスワード制約ポリシー（MVP）

## 結論
- パスワード制約は以下。
  - 最小長: 12文字以上
  - 文字種: 英字と数字を両方含む
- これらはレート制限と組み合わせて、総当たり攻撃の成立を避ける目的で運用する。
- 判定の最終責任はサーバ側（`User` バリデーション）とする。
- フロントのOK/未達成表示とボタン制御は補助UIとして扱う。

---

## 背景
- UXとセキュリティのバランスを取り、MVPでは過度な複雑性（記号必須など）は採用しない。
- 一方で短すぎるパスワードや単一文字種はセキュリティ上避ける。

---

## 方針（決め方）

### 1) サーバ側で必ず検証する
- フロントJSのみだと、直接リクエストで回避できるため不十分。
- `User` モデルでバリデーションを持つ。

### 2) フロントは入力補助に限定する
- 入力中に `英字と数字を含む - OK/未達成`、`12文字以上 - OK/未達成` を表示。
- 登録ボタンは以下すべてを満たすときのみ有効化する。
  - メール形式が妥当
  - パスワードが12文字以上
  - 英字と数字を含む
  - 確認用パスワード一致
  - 利用規約同意

### 3) エラーはフォーム上で再表示する
- サーバ側失敗時は `render :new, status: :unprocessable_entity` で戻し、
  入力内容確認を促す。

---

## 実装

### Model
- `app/models/user.rb`
  - `PASSWORD_MIN_LENGTH = 12`
  - `PASSWORD_COMPLEXITY = /\A(?=.*[A-Za-z])(?=.*\d).+\z/`
  - `validates :password, length: ...`
  - `validates :password, format: ...`

### Controller
- `app/controllers/sign_ups_controller.rb`
  - 失敗時: `render :new, status: :unprocessable_entity`

### Frontend（Stimulus）
- `app/javascript/controllers/password_rules_controller.js`
  - 条件達成状況（OK/未達成）表示
- `app/javascript/controllers/password_confirmation_controller.js`
  - 確認用パスワードの一致判定表示
- `app/javascript/controllers/sign_up_submit_controller.js`
  - 送信可否の統合判定と送信ガード
- `app/javascript/controllers/password_visibility_controller.js`
  - パスワード表示/非表示切り替え

### View
- `app/views/sign_ups/new.html.erb`
  - パスワード入力・確認入力・同意チェック・送信ボタンの連動
- `app/views/sign_ups/_password_rules.html.erb`
  - ルール表示文言

### 関連ドキュメント
- レート制限運用は `docs/03_engineering/auth/2026-02-10-05-rate-limit-policy.md` を参照。

---

## テスト
- `test/models/user_test.rb`
  - 12文字未満で失敗
  - 英字数字混在でない場合に失敗
  - 条件達成で成功
- `test/integration/sign_ups_flow_test.rb`
  - 登録成功/失敗のフロー検証
  - サインアップ画面の主要Stimulus配線を検証

---

## 見直し条件
- 不正ログイン試行の傾向が変わった場合
- UI離脱率や入力失敗率が高い場合
- 本番運用で追加要件（記号必須・辞書語対策・再認証強化）が必要になった場合
