# MeCab を Docker（Debian slim）に導入する技術検証

## 目的
- Rails から MeCab を呼べる状態にする
- 開発環境（docker-compose.dev.yml）で動作確認できること

## 結論
- Debian slim では apt で MeCab を入れればOK

## 変更点
- Dockerfile.dev に MeCab パッケージを追加
  - mecab / libmecab-dev / mecab-ipadic-utf8

## 手順
1. Dockerfile.dev を修正
2. `make dev-build-nocache` でビルド
3. `make exec` でコンテナに入る
4. 動作確認
   - `mecab -v`
   - `echo "グラコロ新作もめっちゃおいしい" | mecab`

## 参考
- MeCab公式: https://taku910.github.io/mecab/
- https://zenn.dev/ndjndj/articles/5f58caadc264ef
