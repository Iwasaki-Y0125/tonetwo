# 日本語評価極性辞書（名詞編 + 用言編）をDocker本番構成に導入（localprod / prod）

## 目的
- ローカル本番環境（`docker-compose.localprod.yml`）で、日本語評価極性辞書（名詞編 + 用言編）を使ったポジネガ判定ができる状態にする
- リポジトリに辞書原本を含めず、**Dockerビルド時に公式配布元から取得**して再現可能にする
- Rails側は **ENVで固定パスを参照**し、環境差分を最小化する

## 結論（構成方針）
- **build ステージ**
  - `curl` で公式配布元から辞書をDL
  - 配置先は `/opt/sentiment_lex`（固定パス）
- **runtime ステージ**
  - build で取得した辞書を runtime へ `COPY`
  - 非rootでも読めるよう権限を付与（念のため）
- **Rails**
  - `SENTIMENT_LEX_DIR=/opt/sentiment_lex` を参照して辞書パスを組み立てる



## ディレクトリ / ファイル
- 既存辞書（Docker内・固定パス）
  - `${SENTIMENT_LEX_DIR}/wago.121808.pn`（用言編）
  - `${SENTIMENT_LEX_DIR}/pn.csv.m3.120408.trim`（名詞編）
- 参照用ENV（Dockerfileで固定）
  - `SENTIMENT_LEX_DIR=/opt/sentiment_lex`


## 手順

### 1) Dockerfile（base）で参照パスをENV固定
- build / runtime の両方で同じパスを参照できるように **base で固定**しておく
```Dockerfile
ENV SENTIMENT_LEX_DIR="/opt/sentiment_lex"
```
### 2) Dockerfile（build）で辞書をDLする
```Dockerfile
# ====================
#  日本語評価極性辞書（名詞編 + 用言編）の取得（localprod/prod build）
#  参照: 東北大 乾・岡崎研究室 公開辞書
# ====================
RUN set -eux; \
  mkdir -p "${SENTIMENT_LEX_DIR}"; \
  for i in 1 2 3 4 5; do \
    rm -f "${SENTIMENT_LEX_DIR}/wago.121808.pn" "${SENTIMENT_LEX_DIR}/pn.csv.m3.120408.trim"; \
    if \
      curl -fsSL --retry 3 --retry-delay 5 --retry-all-errors \
        -o "${SENTIMENT_LEX_DIR}/wago.121808.pn" \
        "https://www.cl.ecei.tohoku.ac.jp/resources/sent_lex/wago.121808.pn" \
      && \
      curl -fsSL --retry 3 --retry-delay 5 --retry-all-errors \
        -o "${SENTIMENT_LEX_DIR}/pn.csv.m3.120408.trim" \
        "https://www.cl.ecei.tohoku.ac.jp/resources/sent_lex/pn.csv.m3.120408.trim"; \
    then \
      break; \
    fi; \
    echo "Japanese Sentiment Dictionary download failed. retry=${i}" >&2; \
    sleep $((i*10)); \
  done; \
  test -s "${SENTIMENT_LEX_DIR}/wago.121808.pn"; \
  test -s "${SENTIMENT_LEX_DIR}/pn.csv.m3.120408.trim"
```

### 3) Dockerfile（runtime）で辞書をCOPYする
```Dockerfile
# =========================================
# ポジネガ辞書
# buildで取得した辞書をruntimeへコピー
COPY --from=build "${SENTIMENT_LEX_DIR}" "${SENTIMENT_LEX_DIR}"

# 非root実行でも読めるように（念のため）
RUN chmod -R a+rX "${SENTIMENT_LEX_DIR}"
```

### 4) Rails側は`sentiment.rb`で `SENTIMENT_LEX_DIR` を参照して読み込む
```rb
# ポジネガ辞書ディレクトリの指定
sentiment_lex_dir = ENV.fetch("SENTIMENT_LEX_DIR", "/opt/sentiment_lex")

# ビルド時にコンテナに配布(File.join)
pn_path   = File.join(sentiment_lex_dir, "pn.csv.m3.120408.trim")
wago_path = File.join(sentiment_lex_dir, "wago.121808.pn")

# レポジトリ内で管理(Rails.)
wago_user_path = Rails.root.join("sentiment_userdic/user.pn").to_s
```

## 動作確認

1) ビルドできること
```sh
make lprod-build-nocache
```

2) コンテナ内でファイルが存在し、0byteでないこと
```sh
make lprod-exec

echo "$SENTIMENT_LEX_DIR"
ls -la "$SENTIMENT_LEX_DIR"

test -s "$SENTIMENT_LEX_DIR/wago.121808.pn" && echo "wago OK"
test -s "$SENTIMENT_LEX_DIR/pn.csv.m3.120408.trim" && echo "pn OK"

```

3) Railsから辞書が引けること
```sh
make lprod-exec

bin/rails runner "p PN_LEX.score(%q[最高])"
bin/rails runner "p PN_LEX.score(%q[最悪])"

bin/rails runner "p WAGO_LEX.score_terms(%w[楽しい])"
bin/rails runner "p WAGO_LEX.score_terms(%w[良い ない])"

```

4) Wagoユーザー辞書が引けること
```sh
make lprod-exec

bin/rails runner "p WAGO_LEX.score_terms(%w[うれしい])"
bin/rails runner "p WAGO_LEX.score_terms(%w[微妙])"

```

## トラブルシュート
- ビルド時にDLが落ちる / 0byteになる
  - 配布元の瞬断の可能性が高い
  - 対策：リトライ

- runtime で辞書が見つからない
  - `COPY --from=build "${SENTIMENT_LEX_DIR}" "${SENTIMENT_LEX_DIR}" `が抜けている可能性
  - `SENTIMENT_LEX_DIR` の ENV が build/runtime でズレている可能性
  - 対策：baseで `ENV SENTIMENT_LEX_DIR="/opt/sentiment_lex"` を固定する

- 非rootで読めずに落ちる
  - 対策：`chmod -R a+rX "${SENTIMENT_LEX_DIR}"` を runtime に入れる

## 運用メモ
- `/opt` 配下に置くのは、`/rails`（アプリ）配下だと bind mount 等で上書きされる事故が起きやすいから
- `localprod / prod `では、辞書原本はイメージに含まれる
  - 辞書更新の際は、再ビルドが必要(ただし、辞書の修正はdev環境で行う想定)

## 参考
- 日本語評価極性辞書 配布ページ（東北大学 乾・岡崎研究室）
https://www.cl.ecei.tohoku.ac.jp/Open_Resources-Japanese_Sentiment_Polarity_Dictionary.html
