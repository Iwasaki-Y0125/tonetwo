# 規約・ライセンス更新ランブック

このドキュメントは、以下2つの更新手順をまとめた運用手順です。
- 利用規約 / プライバシーポリシー更新
- サードパーティーライセンス更新

---

## 1. 規約系の更新手順

### 1-1. 正となるファイル
- 利用規約: `app/views/pages/policies/terms.md`
- プライバシーポリシー: `app/views/pages/policies/privacy.md`

補足:
- 画面表示は `Policies::PolicyDocuments.fetch!` が上記 Markdown を読む。
- 同意版は `User.current_terms_version` / `User.current_privacy_version` が本文ハッシュ（`sha256-...`）を自動算出して保存する。

### 1-2. 更新作業
1. `terms.md` または `privacy.md` を編集する。
2. ローカル表示確認を行う。
   - `/tos`
   - `/privacy`
3. サインアップ導線の同意保存に影響するため、最低限テストを実行する。

推奨コマンド:
```bash
make test
```

### 1-3. 差分確認ポイント
- 文言の誤字脱字
- 改定内容と実装の整合
- 規約リンク導線（LP / ログイン / 設定 / サインアップ）

---

## 2. ライセンス更新手順

### 2-1. 正となるファイル
- 手動管理の説明本文: `docs/80_licenses/third_party_notices.md`
- 自動生成の RubyGems 一覧: `docs/80_licenses/gems.md`
- 画面表示用の統合生成物: `docs/80_licenses/licenses_full.md`

補足:
- 画面の `/licenses` は `Policies::PolicyDocuments.fetch!(:licenses)` で表示内容を組み立てる。
- `fetch!(:licenses)` は `third_party_notices.md` に `gems.md` と実行環境ライセンス情報を連結する。

### 2-2. 更新作業
1. 必要に応じて `docs/80_licenses/third_party_notices.md` を編集する。
2. 以下を実行して生成物を更新する。

```bash
make license-report
```

3. `/licenses` を開いて表示崩れ・欠落を確認する。

### 2-3. `make license-report` の実行内容
- `docs/80_licenses/gems.md` を再生成
- `docs/80_licenses/licenses_full.md` を再生成

---

## 3. リリース前チェックリスト

- [ ] `app/views/pages/policies/terms.md` の更新内容を確認
- [ ] `app/views/pages/policies/privacy.md` の更新内容を確認
- [ ] `docs/80_licenses/third_party_notices.md` の更新内容を確認
- [ ] `make license-report` 実行済み
- [ ] `/tos` `/privacy` `/licenses` の表示確認済み
- [ ] テスト結果を確認済み

---

## 4. よくあるハマりどころ

### `make license-report` が失敗する
- `docker compose` が起動していない
- 出力先パスが変わっている

確認コマンド:
```bash
make up
make license-report
```

### モーダルで表示が崩れる
- CSSビルドが未反映の可能性あり

確認コマンド:
```bash
make css-build
```
