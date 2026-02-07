# Dependabot 基本知識と運用手順

## 目的
- Dependabot の機能差を混同せずに運用する。
- 依存更新PRの「反映する/しない」を一定の基準で判断する。
- セキュリティ優先で、開発速度を落としすぎない更新サイクルを作る。

## このリポジトリの現状（2026-02-07時点）
- `.github/dependabot.yml` で `bundler` と `github-actions` を `daily` 監視。
- 依存更新PRは Dependabot が自動作成する。
- CIは `.github/workflows/ci.yml` で以下を実行。
  - `bin/brakeman --no-pager`
  - `bin/importmap audit`
  - `bin/rubocop -f github`
  - `bin/rails db:test:prepare test test:system`

## まず押さえる用語
- Dependabot version updates:
  依存ライブラリの新しい版が出たときに更新PRを作る機能。
- Dependabot alerts:
  既知脆弱性（GHSA/CVE）が依存に見つかったときに Security タブに警告を出す機能。
- Dependabot security updates:
  alerts を解消するための修正PRを自動作成する機能。
- Dependency graph:
  manifest/lockfile から依存関係を解析する土台機能。alerts の前提。
- Automatic dependency submission:
  build時の依存を自動提出して、Dependency graph の把握精度を補助する機能。

## 更新の種類（SemVer）
- patch: `8.0.4 -> 8.0.5`（末尾だけ変化）。通常は小さな修正中心。
- minor: `8.0.4 -> 8.1.2`（中央が変化）。機能追加や挙動差分があり得る。
- major: `8.1.2 -> 9.0.0`（先頭が変化）。大きな変更が入りやすい。

## 依存更新PRの判断フロー
1. セキュリティ起点か確認する。
   - Security > Dependabot で `Critical/High` があるなら優先対応。
2. 更新種別を確認する。
   - patch は原則前向きに取り込む。
   - minor/major は検証時間を確保して扱う。
3. PRの差分を確認する。
   - 依存更新以外の差分が混ざっていないか。
4. CI結果を確認する。
   - `scan_ruby / scan_js / lint / test` が Green か。
5. 最低限の手動確認を行う。
   - 主要画面表示
   - 作成/更新などの基本導線

## Rails更新PR（例: 8.0.4 -> 8.1.2）の扱い
- Railsの minor 更新は patch より影響範囲が広くなりやすい。
- 主要機能の実装前フェーズなら、先に取り込んで基盤を揃える判断は合理的。
- ただし、機能開発で手が足りない時は一旦保留してよい。
- 長期放置は差分拡大で将来コストが増えるため、月次で消化する。

## 推奨運用サイクル
- 毎週:
  - Dependabot PRを確認し、patch中心に処理。
- 毎月:
  - minor更新をまとめて検証し、対応可否を決める。
- 随時:
  - alerts の `Critical/High` は優先対応。

## 運用方針（2026-02-07 決定）
### 通常運用
- `CI中心 + 最低限の手動確認 + 本番由来バグ検知時の即ロールバック` を基本とする。
- 低リスク更新（主に patch）は、通常運用で処理する。

### 例外運用（影響が大きい更新）
- 以下は「影響が大きい更新」として扱う。
  - Rails minor 以上（例: `8.0.x -> 8.1.x`）
  - 破壊的なDB変更の可能性がある更新
  - 認証/セッション/ジョブ基盤などの基盤変更
- 影響が大きい更新は、次のどちらかで対応する。
  - staging で事前確認（コストかかるから避けたい）
  - 時間帯を選び、事前告知したうえで一時停止して検証

### 一時停止で検証する場合の最小手順
1. 実施時間帯と影響範囲を事前告知する。
2. 更新を反映し、主要導線（表示/作成/更新）を確認する。
3. 問題があれば即ロールバックする。
4. 復旧完了を告知する。

## 推奨設定（段階導入）
### 最低限（必須）
- `Dependency graph`: ON
- `Dependabot alerts`: ON

### 次点（推奨）
- `Dependabot security updates`: ON
- `Grouped security updates`: ON（PR乱立を抑える）

### 体制が整ってから
- `Private vulnerability reporting`: ON
  - 対応体制が弱い時点では OFF でも可。

## 初学者向けチェックリスト（5分版）
1. このPRは security update か？
2. patch/minor/major のどれか？
3. CIは全部通っているか？
4. 自分がよく触る画面を最低1回ずつ触ったか？
5. 問題なければマージ、怪しければ保留+次回検証日を決める。

## 参考（公式一次情報）
- Configuring Dependabot version updates  
  https://docs.github.com/en/code-security/dependabot/dependabot-version-updates/configuring-dependabot-version-updates
- Dependabot options reference  
  https://docs.github.com/en/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot.yml-file
- About Dependabot alerts  
  https://docs.github.com/en/code-security/concepts/supply-chain-security/about-dependabot-alerts
- Configuring the dependency graph  
  https://docs.github.com/en/code-security/supply-chain-security/understanding-your-software-supply-chain/configuring-the-dependency-graph
- Configuring automatic dependency submission for your repository  
  https://docs.github.com/enterprise-cloud@latest/code-security/supply-chain-security/understanding-your-software-supply-chain/configuring-automatic-dependency-submission-for-your-repository
