# 監視方法の整理 (Initial)

監視方法を「失敗から学ぶRDBの正しい歩き方」を参考に、以下の3つに分けて整理する。

- (1) サービス（プロセス）の死活監視
- (2) 特定条件のチェック監視
- (3) 時系列データをもとにしたメトリックス監視

---

## (1) サービス（プロセス）の死活監視

### 目的
- サービスが「落ちていないか」「外部からアクセスできる状態か」を検知する。

### 代表例
- WebアプリのURLを定期的に叩いて 200 が返るか
- ヘルスチェックエンドポイント（/healthz 等）が応答するか

### ToneTwoでの実装案
- **Render Health Check（Web Service）**
  - Webサービスに対してヘルスチェックを設定し、異常なら再起動やデプロイ失敗判定に使う。
- （将来）**外形監視（外部からの監視）**
  - “Render自体が不調で通知が出ない” 可能性を薄めるなら、外部のUptime監視を追加する。



## (2) 特定条件のチェック監視

### 目的
- 「こうなったら異常」という条件を検知してアラートする。

### 代表例
- バックアップが「今日1回も取れていない」
- 定期処理（今日の話題の発出）が失敗した / 実行されていない

### ToneTwoでの実装案（優先度順）
- **MVP〜初期**
  - RenderCronJob を使う場合：
    - Render Notifications で「cron job 実行失敗」を Slack/Email 通知（まずはこれで最低限）
    - ログ（Dashboard Logs）で原因追跡
- **本リリース以降（推奨）**
  - **check-in型**を追加（例：Sentry Crons）
    - ジョブが「完了したら check-in を送る」
    - check-in が来ない場合に “未実行” としてアラートできる
  - これにより、Render側で何らかの理由で「そもそもジョブが起動されなかった」ケースの検知が強くなる。

### Render Cronの注意点（ここがポイント）
- Render Notifications が拾えるのは基本「実行が走って失敗した」ケース。
- “基盤側の都合で実行されなかった（miss）” は、通知が出ない可能性がある。（要検証）
- なので重要なcron（バックアップ等）は将来的に check-in型を併用。

---

## (3) 時系列データをもとにしたメトリックス監視（MVP時点では未実装、本リリース前に実装予定）

### 目的
- 状態を数字で継続観測し、劣化や異常傾向を早期に見つける。
- 「いつから遅くなった？」「どの操作が重い？」を追えるようにする。

### 代表例
- レイテンシ（p95/p99）、スループット、エラー率
- DBのCPU/メモリ、接続数、遅いクエリ傾向
- キューの滞留数、ジョブ実行時間の推移

### ToneTwoでの実装案
- **Sentry Performance（トレース/トランザクション）**
  - Railsのリクエスト単位で遅い処理やボトルネックを追える。
- **Render側のメトリクス**
  - Render Dashboard 上のメトリクス閲覧を起点に、必要なら外部基盤へ送る。
- **DBメトリクス**
  - まずは「遅いクエリ・接続数・エラー」をログ/可観測性で拾い、必要が出たら本格的なメトリクス基盤へ。

---

# どれをいつ入れるか（運用コスト最小の方針）

## MVP（最小で事故りにくく）
- (1) 死活：Render Health Check（Web）
- (2) 条件：Render Notifications（cron failure）＋ログ追跡
- (3) メトリクス：MVP時点ではリリース優先で実装なし

## 本リリース前
- (2) 条件：重要cronだけ check-in型（Sentry Crons等）を追加
- (3) メトリクス：Sentry Performance を低サンプリングで開始、必要に応じて拡張

---

# 参考（公式ドキュメント）
- 失敗から学ぶRDBの正しい歩き方 曽根 壮大 (著) 技術評論社 第11・12章

- Render Docs
  - Health Checks（Web Services）
    - https://render.com/docs/health-checks
  - Notifications（Cron job失敗通知など）
    - https://render.com/docs/notifications

- Sentry Docs
  - Error Monitoring
    - https://docs.sentry.io/product/issues/
  - Performance Monitoring
    - https://docs.sentry.io/product/sentry-basics/performance-monitoring/
  - Cron Monitoring（Crons / Check-ins）
    - https://docs.sentry.io/product/crons/
