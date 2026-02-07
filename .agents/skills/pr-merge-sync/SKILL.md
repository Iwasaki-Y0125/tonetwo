---
name: pr-merge-sync
description: PRをリモートでマージした後に、ローカルmainを同期し、不要な作業ブランチを安全に片付ける。毎回同じGit手順を省力化したい依頼（「マージ後のローカル更新して」「mainを同期してブランチ掃除して」など）で使う。
---

<!--
使い方テンプレ（コピペ用）:

`pr-merge-sync` を使って、PRマージ後のローカル同期を実行して。
対象ブランチは `feature/issue-87-bump-rails-8-1-2`。
実行コマンドと結果を短く報告して。
-->

# PR Merge Sync

## ゴール
- リモートでマージ済みの内容をローカル `main` に反映する。
- 不要になったローカル作業ブランチを安全に削除する。
- `origin` 側で消えた追跡ブランチを整理する。

## 手順
1. 現在の作業状態を確認する。
- `git status --short` で未コミット変更がある場合は停止し、方針を確認する。

2. ローカル `main` を最新化する。
- `git switch main`
- `git pull --ff-only origin main`

3. 作業ブランチを削除する（任意）。
- 対象: `<work_branch>`
- `git branch -d <work_branch>`
- 未マージなどで `-d` が失敗した場合は削除せず、理由を報告して停止する。

4. 追跡ブランチを整理する。
- `git fetch -p`

5. 結果を報告する。
- 実行コマンド
- `main` の同期可否
- ブランチ削除可否

## 既定コマンドセット
```bash
git status --short
git switch main
git pull --ff-only origin main
git branch -d <work_branch>
git fetch -p
```

## 制約
- 未コミット変更がある場合、勝手にstash/resetしない。
- `git reset --hard` や強制削除 `git branch -D` は、明示指示がある場合のみ。
- 失敗時はエラー原因をそのまま報告し、推測で継続しない。
