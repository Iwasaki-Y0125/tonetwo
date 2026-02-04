# mecab-ipadic-neologdのインストール

## 目的
- mecab-ipadic-neologdのインストールすることでMeCabの分かち書きが改善するか検証するため

## 結論
- 例文（「〜のうざいから…」）では mecab-ipadic-neologd のみでは改善が不十分だった
-追加対応として、ユーザー辞書の導入し検証する必要がある。

## 変更点
- Dockerfile.dev に mecab-ipadic-neologd のインストール処理を追加
-  NEologd インストールがネットワーク要因で失敗しやすいため、最大5回までリトライ（バックオフ）を追加

## 手順
1. Dockerfile.dev に依存パッケージを追加
    NEologdインストーラが利用するコマンドをapt-get install ブロックに追記する。

    例 :
    - xz-utils
    - patch
    - file
    - （環境によって必要）sudo
    ※ `ruby:* -slim` では `sudo: command not found` が出ることがあるため、エラーになる場合のみ、sudoを追加する。

2. Dockerfile.dev にNEologd のインストール処理を追加

    - NEologd はインストールが重く、GitHub 側の混雑などで失敗することがあるため、最大5回までリトライする。
    - 【2025-12-28追記】NEologd辞書を固定パスにコピーして退避処理を追記

    ```dockerfile
    ENV MECAB_DICDIR=/opt/mecab-dic/neologd

    # set -eux: Dockerビルドのデバッグをしやすくする定番セット
    # -e:エラー時に即座に終了 -u:未定義の変数を使ったらエラー -x:実行するコマンドをログに全部出力
    RUN set -eux; \
      # NEologdのインストールを最大5回までリトライ
      for i in 1 2 3 4 5; do \
        # 毎回クローンキャッシュを削除してから実行
        rm -rf /tmp/mecab-ipadic-neologd; \
        # NEologdのGitクローン(公式手順に準拠) --depth 1: 履歴を1つだけにして軽量化
        if git clone --depth 1 https://github.com/neologd/mecab-ipadic-neologd.git /tmp/mecab-ipadic-neologd && \
          \
          # インストールを実行(公式手順に準拠)
          # -y:全てyesで実行
          # -n: ログからインストーラの更新/更新チェック挙動に関わるオプションっぽい、詳細不明
          /tmp/mecab-ipadic-neologd/bin/install-mecab-ipadic-neologd -n -y; then \
          rm -rf /tmp/mecab-ipadic-neologd; \
          \
          # インストール成功後、NEologd辞書を固定パスにコピーして退避
          mkdir -p "$(dirname "${MECAB_DICDIR}")"; \
          rm -rf "${MECAB_DICDIR}"; \
          cp -a "$(mecab-config --dicdir)/mecab-ipadic-neologd" "${MECAB_DICDIR}"; \
          test -f "${MECAB_DICDIR}/dicrc"; \
          # RUN ステップを成功で終了
          exit 0; \
        fi; \
        # >&2: 標準エラー出力にメッセージを出す
        echo "NEologd install failed. retry=${i}" >&2; \
        # バックオフ戦略: リトライ毎に待機時間を長くする(混雑や一時障害に強い)
        # 例: 1回目=10秒, 2回目=20秒, 3回目=30秒...
        sleep $((i*10)); \
      # forループここまで
      # 5回リトライしても成功しなかった場合の処理
      done; \
      echo "NEologd install failed after retries" >&2; \
      # exit 1：RUNステップが失敗 → Dockerビルド全体が失敗
      exit 1
    ```

3. ビルド
    ```sh
    make dev-build-nocache
    ```
    ビルドが失敗した場合に、詳細ログ表示するコマンド
    ```bash
    DOCKER_BUILDKIT=1 docker build --progress=plain -f Dockerfile.dev .
    ```

## 動作確認
コンテナ内で以下を実行し、NEologd が使われていることを確認

```sh
mecab-config --dicdir
ls "$(mecab-config --dicdir)"
mecab -d "$(mecab-config --dicdir)/mecab-ipadic-neologd" -D | head -n 5

# 出力結果
$ mecab-config --dicdir
/usr/lib/x86_64-linux-gnu/mecab/dic

$ ls "$(mecab-config --dicdir)"
mecab-ipadic-neologd

$ mecab -d "$(mecab-config --dicdir)/mecab-ipadic-neologd" -D | head -n 5
filename:       /usr/lib/x86_64-linux-gnu/mecab/dic/mecab-ipadic-neologd/sys.dic
version:        102
charset:        UTF8
type:   0
size:   4668394
```

### 導入補足情報
- `sudo: command not found`<br>
  slim系イメージでは sudo が入っていないため、NEologd インストーラが sudo を呼ぶと失敗する。必要に応じて sudo を追加する。

- `Unable to access https://github.com/ (504)`<br>
GitHub 側・経路要因で失敗することがある。リトライ（バックオフ）で吸収する。

## 参考
- mecab-ipadic-neologd(GitHub):
 https://github.com/neologd/mecab-ipadic-neologd
- Manpages of manpages-ja in Debian testing : https://manpages.debian.org/testing/manpages-ja/index.html
- Docker ドキュメント日本語化プロジェクト(RUN) :https://docs.docker.jp/develop/develop-images/dockerfile_best-practices.html#run
