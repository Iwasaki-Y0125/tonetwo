# レート制限運用ポリシー（MVP）

## 結論
- レート制限は `Rack::Attack`（middleware層）と `rate_limit`（controller層）を併用する。
- 役割分担は以下。
  - `Rack::Attack`: 粗い遮断（`429`）
  - `rate_limit`: UXを保つ抑止（主に `302` リダイレクト）
- 監視は `security.throttle` イベントで `layer` を分けて記録する。

---

## レート制限一覧
| レイヤ | 対象 | しきい値 | 超過時の挙動 | 実装箇所 |
|---|---|---|---|---|
| Middleware (`Rack::Attack`) | 全リクエスト（IP単位） | 240回/1分 | `429 Too Many Requests` | `config/initializers/rack_attack.rb` |
| Middleware (`Rack::Attack`) | `POST /session`（IP単位） | 20回/1分 | `429 Too Many Requests` | `config/initializers/rack_attack.rb` |
| Middleware (`Rack::Attack`) | `POST /sign_up`（IP単位） | 20回/1分 | `429 Too Many Requests` | `config/initializers/rack_attack.rb` |
| Controller (`rate_limit`) | `SessionsController#create` | 10回/3分 | ログイン画面へリダイレクト（`302`） | `app/controllers/sessions_controller.rb` |
| Controller (`rate_limit`) | `SignUpsController#create` | 10回/3分 | サインアップ画面へリダイレクト（`302`） | `app/controllers/sign_ups_controller.rb` |

---

## 補足
- `Rack::Attack` は `production` 環境でのみ有効。
- `security.throttle` ログは `layer` / `rule` / `status` / `method` / `path` を出力する。
- `path` は詳細値をそのまま残さず、先頭セグメントのみ記録する。

---

## 参照実装
- `config/initializers/rack_attack.rb`
- `config/initializers/security_throttle_observability.rb`
- `app/controllers/sessions_controller.rb`
- `app/controllers/sign_ups_controller.rb`
