# 日本語評価極性辞書（名詞編 + 用言編）をDocker（dev）で取得して利用する

## 目的
- 投稿テキストのポジネガ判定（簡易スコア算出）に利用するため、**日本語評価極性辞書**（名詞編 + 用言編）を開発環境のDockerビルド時に取得できるようにする。
- リポジトリに辞書原本を含めずに運用し、GitHub/Renderデプロイ時も同一手順で再現できる状態にする。

## 結論
- 辞書ファイルは **Dockerビルド時に公式配布元から `curl` でDL**し、コンテナ内の固定パス（`/opt/sentiment_lex`）へ配置する。
- Rails側はDockerfileの`ENV["SENTIMENT_LEX_DIR"]` を参照し、名詞編/用言編のファイルを読み込む。

## 変更点
- `Dockerfile.dev` に、日本語評価極性辞書（名詞編 + 用言編）のDL処理を追加
- `SENTIMENT_LEX_DIR=/opt/sentiment_lex` をENVとして定義（コンテナ内固定パス）

## ディレクトリ / ファイル
- 配置先（コンテナ内）
  - `${SENTIMENT_LEX_DIR}/wago.121808.pn`（用言編）
  - `${SENTIMENT_LEX_DIR}/pn.csv.m3.120408.trim`（名詞編）
- 参照用ENV
  - `SENTIMENT_LEX_DIR=/opt/sentiment_lex`

## 手順
1. `Dockerfile.dev` に辞書DLのENVとRUNを追加する

   ```dockerfile
    # ====================
    #  日本語評価極性辞書（名詞編 + 用言編）の取得（dev用）
    #  参照: 東北大 乾・岡崎研究室 公開辞書
    # ====================
    ENV SENTIMENT_LEX_DIR=/opt/sentiment_lex

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

2. （アプリ側）辞書パスは ENV["SENTIMENT_LEX_DIR"] 経由で参照する
    - ハードコードは避け、環境差分をENVで吸収する

    例（読み込み側のパス組み立てイメージ）：

    - `File.join(ENV.fetch("SENTIMENT_LEX_DIR", "/opt/sentiment_lex"), "wago.121808.pn")`
    - `File.join(ENV.fetch("SENTIMENT_LEX_DIR", "/opt/sentiment_lex"), "pn.csv.m3.120408.trim")`

## 動作確認
1) Dockerをビルドできること
    ``` sh
    make dev-build-nocache
    ```

2) コンテナ内でファイルが存在すること
    ```sh
    make exec
    echo "$SENTIMENT_LEX_DIR"
    ls -la "$SENTIMENT_LEX_DIR"
    test -s "$SENTIMENT_LEX_DIR/wago.121808.pn" && echo "wago OK"
    test -s "$SENTIMENT_LEX_DIR/pn.csv.m3.120408.trim" && echo "pn OK"
    ```

3) ファイルサイズが0でないこと
    ```sh
    ruby -e 'dir=ENV.fetch("SENTIMENT_LEX_DIR"); puts File.size("#{dir}/wago.121808.pn")'
    ruby -e 'dir=ENV.fetch("SENTIMENT_LEX_DIR"); puts File.size("#{dir}/pn.csv.m3.120408.trim")'
    ```

## 運用メモ
- ビルド時DL方式のため、配布元の一時的なネットワーク障害に備えてリトライを入れている。
- SENTIMENT_LEX_DIR は /app 配下に置かない（bind mountで上書きされる可能性があるため）。

## 参考
- 日本語評価極性辞書 配布ページ（東北大学 乾・岡崎研究室）
https://www.cl.ecei.tohoku.ac.jp/Open_Resources-Japanese_Sentiment_Polarity_Dictionary.html

