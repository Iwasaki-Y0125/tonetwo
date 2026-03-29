# npm依存更新メモ

## 前提
- このリポジトリは [package-lock.json](../../../package-lock.json) を使う。
- npm 操作は Docker 経由で実行する。

## 使うコマンド
- まとめて更新:
```bash
make npm-update
```
- 個別更新:
```bash
make npm-update-one p="@tailwindcss/cli"
```
- 依存経路確認:
```bash
make npm-ls p="picomatch"
```

## 判断順
1. `make npm-ls p="<pkg>"` で依存経路を確認する。
2. 直接依存に近いものだけ動かしたいなら `make npm-update-one` を試す。
3. 脆弱性対応を優先し、差分が多少広がってもよいなら `make npm-update` を使う。

## 今回の学び
- `make npm-update-one p="@tailwindcss/cli"` では `picomatch` は上がらなかった。
- `make npm-update` では `picomatch` は `4.0.4` に上がった。
- npm は個別更新でも周辺依存が動くことがあり、親を上げても子の脆弱性が必ず直るとは限らない。

## 確認
- 脆弱性確認:
```bash
make npm-audit
```
- 差分確認:
```bash
git diff -- package.json package-lock.json
```
