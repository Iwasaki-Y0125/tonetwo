---
name: issue-to-branch
description: Issue番号/URL/タイトルが提示されたとき、ローカル規約を確認してGitブランチを作成する。Issue起点で作業開始する依頼（「Issue #123でブランチ切って」など）で使う。
---

<!--
使い方テンプレ（コピペ用）:

`issue-to-branch` を使って、添付したIssueキャプチャから作業ブランチを切って。
読み取り結果（Issue番号 / タイトル / repo）を先に確認してから作成して。
命名規則は `feature/issue-<num>-<slug>` を使い、作成したブランチ名と実行コマンドも報告して。
-->

# Issue to Branch

## ゴール
- Issue情報を根拠に、衝突しない作業ブランチを作成する。
- このリポジトリの既定命名規約 `feature/issue-<num>-<slug>` に統一する。
- `web_search = cached` を前提に、ユーザー入力（キャプチャやコピペなど）を一次情報として扱う。
- 画像（Issueキャプチャ）入力を標準運用として扱う。


## 手順
1. 入力を正規化する。
- 入力は「Issueキャプチャ」を優先で受け取る。
- 画像から `Issue番号 / Issueタイトル / repo(owner/repo)` を抽出する。
- URLは任意入力とし、なくても進める。
- 読み取り結果は作成前に短く復唱し、ユーザー確認後に進む。
- `Issue番号` または `repo` が読み取れない場合は不足項目を列挙し、確定まで処理を止める。
- Web検索で不足情報を補完する前提では進めない。

2. ローカル規約を確認する。
- `AGENTS.md`、`docs/`、既存ブランチ名（`git branch -a`）を確認する。
- ローカルに別規約が明示されていない限り、`feature/issue-<num>-<slug>` を採用する。

3. ブランチ名を決める。
- 規約がある場合は規約を優先する。
- 規約がない場合は `feature/issue-<number>-<slug>` を使う。
- `<slug>` はIssueタイトルを小文字kebab-caseにし、英数字と`-`以外は除去する。
- `<slug>` が長くなる場合は、意味が崩れない範囲で短縮してよい（目安: 2〜4語）。
- タイトルがない、または `<slug>` が空になる場合は `feature/issue-<number>-task` を使う。

4. 競合を確認する。
- `git branch --list '<branch>'` と `git branch -r --list 'origin/<branch>'` で重複確認する。
- 重複時は末尾に連番を付ける案を提示し、確定後に進む。

5. ブランチを作成する。
- 既定ブランチ（通常 `main`）から作る。例:
  - `git switch main`
  - `git switch -c <branch>`
- 既定ブランチが `main` 以外ならローカル設定を優先する。

6. 結果を短く報告する。
- 作成ブランチ名
- 作成元ブランチ
- 実行コマンド

## 制約
- 既存規約と矛盾する命名で作らない。
- Issueタイトルが不足しても `feature/issue-<number>-task` で作業開始できる状態にする。
- slugは可読性を優先し、冗長な語を詰め込みすぎない。
- `git checkout -b` より `git switch -c` を優先する。
- `cached` 設定時はIssueメタデータの自動補完を期待しない。
- キャプチャ読取は誤認識の可能性があるため、番号とrepoだけは必ず確認を取る。
