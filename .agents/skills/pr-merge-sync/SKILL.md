---
name: pr-merge-sync
description: PRをリモートでマージした後に、ローカルmainを同期し、不要な作業ブランチを安全に片付けるための「実行用コマンドのみ」を提示する。
---

<!--
使い方テンプレ（コピペ用）:

`pr-merge-sync` を使って、PRマージ後のローカル同期コマンドを作って。
対象ブランチは 現在のブランチ。
実行はしないで、コマンドだけ表示して。
-->

# PR Merge Sync

## ゴール
- リモートでマージ済みの内容をローカル `main` に反映する。
- 不要になったローカル作業ブランチを安全に削除する。
- `origin` 側で消えた追跡ブランチを整理する。
- 以上を実行するためのコマンドのみを提示する。

## 手順
1. 現在の作業状態を確認する。
- `git status --short` で未コミット変更がある場合は停止し、方針を確認する。

2. 対象ブランチを確定する。
- `git branch --show-current` で現在ブランチを取得し、削除対象を `<work_branch>` とする。
- すでに `main` にいる場合は、削除ステップをスキップする。

3. ローカル `main` を最新化する。
- `git switch main`
- `git pull --ff-only origin main`

4. 作業ブランチを削除する（任意）。
- 対象: `<work_branch>`
- `git branch -d <work_branch>`
- 未マージなどで `-d` が失敗した場合は削除せず、理由を報告して停止する。

5. 追跡ブランチを整理する。
- `git fetch -p`

6. 実行はしない。
- 実行順のコマンドだけを提示する。
- コマンド以外の説明は最小限にする。

## 既定コマンドセット
```bash
git status --short
git branch --show-current
git switch main
git pull --ff-only origin main
git branch -d <work_branch>
git fetch -p
```

## 制約
- 未コミット変更がある場合、勝手にstash/resetしない。
- `git reset --hard` や強制削除 `git branch -D` は、明示指示がある場合のみ。
- ユーザーが「コマンドだけ」を要求した場合、実行結果の報告は行わない。
