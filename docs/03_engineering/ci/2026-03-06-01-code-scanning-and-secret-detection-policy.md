# [CI] CodeQL / GitHub Security 運用方針メモ

## 目的
- `tonetwo` で使うコード解析と GitHub Security 機能の役割分担を整理する。
- 公開リポジトリ前提で、GitHub 標準機能と GitGuardian の使い分けを明文化する。

## 結論
- `tonetwo` のコード解析は [`.github/workflows/codeql.yml`](../../../.github/workflows/codeql.yml) と [`.github/codeql/codeql-config.yml`](../../../.github/codeql/codeql-config.yml) を使う `CodeQL advanced setup` で運用する。
- CodeQL は `pull_request` のみで実行し、`test/**` などのテストコードは除外する。
- 公開リポジトリのシークレット検知は GitHub 標準の `Secret Protection` と `Push protection` を優先する。
- GitGuardian は private repository 向けを主用途とし、`tonetwo` では必須にしない。
- ローカルのレビュー補助は `security-privacy-check` を継続利用し、`ggshield` は現時点では導入しない。

## 背景
- CodeQL default setup では、テストコード内のダミーパスワードまで alert になることがあった。
- `tonetwo` は public repository なので、GitHub 標準の `Secret Protection` と `Push protection` が使える。
- GitGuardian と GitHub の secret scanning はどちらもシークレット検知の領域で重なるため、public repository では二重運用の価値が薄い。

## 現在の方針
### 1. CodeQL
- `CodeQL default setup` は使わず、YAML 管理の `advanced setup` に切り替える。
- workflow は [`.github/workflows/codeql.yml`](../../../.github/workflows/codeql.yml) で管理する。
- CodeQL 設定は [`.github/codeql/codeql-config.yml`](../../../.github/codeql/codeql-config.yml) で管理する。
- 解析対象は `actions` / `javascript-typescript` / `ruby` とする。
- テスト由来のノイズを避けるため、以下を除外する。
  - `test/**`
  - `**/*_test.rb`
  - `**/*.test.js`
  - `**/*.test.ts`
  - `**/*.spec.js`
  - `**/*.spec.ts`
- トリガーは既存 CI とそろえて `pull_request` のみとする。

### 2. GitHub 標準の Security 機能
- GitHub の `Secret Protection` は有効化する。
- GitHub の `Push protection` は有効化する。
- 公開リポジトリでの secret 検知は、まず GitHub 標準機能を一次導線にする。
- 設定場所は以下のとおり。
  - `CodeQL analysis`
    - repository の `Settings` → `Security` → `Advanced Security`
  - `Secret Protection`
    - repository の `Settings` → `Security` → `Advanced Security`
  - `Push protection`
    - GitHub 個人設定の `Code security` → `Push protection for yourself`

### 3. GitGuardian
- GitGuardian は private repository 向けの secret 検知を主用途とする。
- `tonetwo` では、重複するため GitGuardian を前提にしない。
- 自動で public repository まで監視対象に入れ続けると運用がぶれるため、public / private の使い分けを定期的に見直す。

### 4. ローカルレビュー
- ローカルのセキュリティ/プライバシーレビューは `security-privacy-check` を使う。
- `ggshield` は secret 専用の CLI として有用だが、`security-privacy-check`で現状問題ないので、現時点では `tonetwo` の必須ツールにはしない。

## 手順
1. GitHub 側で `CodeQL default setup` を無効化する。
2. `CodeQL advanced setup` に切り替える。
3. [`.github/workflows/codeql.yml`](../../../.github/workflows/codeql.yml) と [`.github/codeql/codeql-config.yml`](../../../.github/codeql/codeql-config.yml) を push する。
4. PR で `CodeQL` workflow が走ることを確認する。
5. 既存 alert が test 由来の誤検知で残る場合は、再解析後も残るものだけ個別に dismiss する。

## 動作確認
- `make test-all`
- PR 作成時に `CI` と `CodeQL` が別 check として表示されること

## 関連ドキュメント
- [GitHub Actions: RuboCop / Brakeman / 最小テスト導入メモ](./2026-02-08-01-github-actions-rubocop-brakeman-min-tests.md)
- [システムテスト基盤の運用メモ](../testing/2026-02-23-01-system-test-foundation-runbook.md)

## 参考
- [GitHub CodeQL advanced setup](https://docs.github.com/en/code-security/code-scanning/creating-an-advanced-setup-for-code-scanning/configuring-advanced-setup-for-code-scanning)
- [GitHub secret scanning](https://docs.github.com/en/code-security/secret-scanning/introduction/about-secret-scanning)
- [GitHub Push protection for users](https://docs.github.com/en/code-security/secret-scanning/working-with-secret-scanning-and-push-protection/push-protection-for-users)
- [GitGuardian monitored perimeter](https://docs.gitguardian.com/internal-monitoring/integrate-sources/monitored-perimeter)
