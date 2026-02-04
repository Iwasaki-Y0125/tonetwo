# ↓コメントだけどBuildKit使うための宣言なので消さない
# syntax=docker/dockerfile:1

# *本番構成用
############################
# ビルドのみNode.js使用
# 実行環境ではNode.jsなしで脆弱性リスク軽減
############################

# 2025-12-26追記
############################
# Mecab導入メモ
# build ステージで MeCab + NEologd + user.dic を作る
# runtime ステージは最小で MeCab 本体だけ apt で入れる
# 辞書ファイルは build から COPY
############################

# 2026-01-07追記
############################
# ポジネガ辞書導入メモ
# build ステージで辞書をDLして /opt/sentiment_lex に配置
# runtime ステージへ COPY（RailsはENVの固定パスを参照）
############################

# バージョン管理
ARG RUBY_VERSION=3.4.8
ARG NODE_MAJOR=22

############################
# 1) base（共通）
############################
FROM ruby:${RUBY_VERSION}-slim AS base

# multi-stageではARGのスコープが途切れるのでARGを再宣言
ARG RUBY_VERSION
ARG NODE_MAJOR

# コンテナ内にrailsディレクトリを作り、以降の処理は/railsをカレントディレクトリとして扱う
WORKDIR /rails

# Railsを本番環境として起動
ENV RAILS_ENV="production" \
    # Gemfile.lockを正として、Gemfileと不整合があればエラーになる
    BUNDLE_DEPLOYMENT="1" \
    # Dockerコンテナ内のGemのインストール先の指定（Bundlerの管理ディレクトリ）
    BUNDLE_PATH="/usr/local/bundle" \
    # developmentとtestグループのGemはインストールしない
    BUNDLE_WITHOUT="development test" \
    # natto が libmecab.so を見つけられるようにする
    MECAB_PATH="/usr/lib/x86_64-linux-gnu/libmecab.so.2" \
    # MeCab辞書の固定パス（build/runtime/Railsで揃える）
    MECAB_DICDIR="/usr/local/lib/mecab/dic/mecab-ipadic-neologd" \
    MECAB_USER_DIC="/usr/local/lib/mecab/dic/user.dic" \
    # ポジネガ辞書の固定パス（build/runtime/Railsで揃える）
    SENTIMENT_LEX_DIR="/opt/sentiment_lex" \
    # 環境設定
    LANG=C.UTF-8 \
    TZ=Asia/Tokyo

############################
# 2) build（ビルド専用：Nodeあり）
############################
FROM base AS build

# multi-stageではARGのスコープが途切れるのでARGを再宣言
ARG NODE_MAJOR

# OSパッケージ導入　/ Node.js導入（npm同梱）
# apt-get update -qq：aptのパッケージ一覧を更新
# apt-get install -y：対話なしでインストール
# --no-install-recommends：おすすめパッケージを入れない → 余計な依存なしで軽量化
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    # Cコンパイラ一式
    build-essential \
    # psych(yaml読み込み)を使う時に必須の開発用ヘッダ(Rails8で本番でも必須)
    libyaml-dev \
    # Gemfileで Git から gem を取る場合に必要
    git \
    # タイムゾーン設定
    tzdata \
    # HTTPS証明書ストア。これがないと https 経由のダウンロード（curl等）が失敗しやすい。
    ca-certificates \
    # NodeSource の鍵を取るのに使う。
    # ====================
    # Node.js 関連
    # ====================
    curl \
    # 鍵（GPG）を扱う。ダウンロードした鍵を apt が使える形に変換するため。
    gnupg \
    # Node.jsをいれるための前処理
    # NodeSourceの鍵をを置くディレクトリ
    # ====================
    #  MeCab（本体 + 補助コマンド + 開発ヘッダ + IPA辞書）
    # ====================
    mecab \
    libmecab-dev \
    mecab-ipadic-utf8 \
    mecab-utils \
    mecab-ipadic \
    libmecab2 \
    # ====================
    # NEologdのインストールに必要な追加パッケージ群
    # ====================
    # .xz 形式で圧縮された辞書データやコーパスを展開するため
    xz-utils \
    # ファイルにパッチを当てる（NEologd のセットアップで辞書定義やビルド用ファイルに修正を当てる工程がある）
    patch \
    # ファイル種別を判定するコマンド。インストーラが「これは何のファイルか」を確認するのに使うことがある。
    file \
  && rm -rf /var/lib/apt/lists/*

# ====================
#  Node.js
# ====================
    # Node.jsをいれるための前処理
    # NodeSourceの鍵をを置くディレクトリ
RUN mkdir -p /etc/apt/keyrings \
    # NodeSourceの署名鍵を取得して保存
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    # NodeSourceのaptリポジトリを追加
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list \
    # リポジトリ追加後に update して nodejs をインストール
    && apt-get update -qq && apt-get install -y --no-install-recommends nodejs \
    # rm -rf /var/lib/apt/lists/*：aptのキャッシュ削除 → 軽量化
    && rm -rf /var/lib/apt/lists/*

# ====================
#  NEologdのインストール
#  NEologdは重くたまに失敗するので5回までリトライする
# ====================
# set -eux: Dockerビルドのデバッグをしやすくする定番セット
# -e:エラー時に即座に終了 -u:未定義の変数を使ったらエラー -x:実行するコマンドをログに全部出力
RUN set -eux; \
  # NEologdのインストールを最大5回までリトライ
  for i in 1 2 3 4 5; do \
    # 毎回クローンキャッシュを削除してから実行
    rm -rf /tmp/mecab-ipadic-neologd; \
    # NEologdのGitクローン(公式手順に準拠) --depth 1: 履歴を1つだけにして軽量化
    if git clone --depth 1 https://github.com/neologd/mecab-ipadic-neologd.git /tmp/mecab-ipadic-neologd && \
    # インストールを実行(公式手順に準拠)
    # -y:全てyesで実行
    # -n: ログからインストーラの更新/更新チェック挙動に関わるオプションっぽい、詳細不明
      /tmp/mecab-ipadic-neologd/bin/install-mecab-ipadic-neologd -n -y; then \
      rm -rf /tmp/mecab-ipadic-neologd; \
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

# ====================
#  NEologd辞書の退避 + user.dic 生成
# ====================

# user辞書ソースだけ先にコピー
COPY mecab_userdic/user.csv ./mecab_userdic/user.csv

RUN set -eux; \
  # パスブレを防ぐために変数に格納
  # MeCabの"辞書ディレクトリ"を取得
  DICDIR="$(mecab-config --dicdir)"; \
  # MeCabの“実行補助コマンド置き場”を取得
  LIBEXECDIR="$(mecab-config --libexecdir)"; \
  # mecab-dict-index コマンドのパスを変数にセット
  MECAB_DICT_INDEX="${LIBEXECDIR}/mecab-dict-index"; \
  mkdir -p /opt/mecab-dic; \
  # NEologd辞書を固定パスへ退避
  cp -a "${DICDIR}/mecab-ipadic-neologd" /opt/mecab-dic/; \
  # user.csv から user.dic を生成
  "${MECAB_DICT_INDEX}" \
    -d "${DICDIR}/mecab-ipadic-neologd" \
    -u /opt/mecab-dic/user.dic \
    -f utf-8 -t utf-8 \
    /rails/mecab_userdic/user.csv

# ====================
#  日本語評価極性辞書（名詞編 + 用言編）の取得（prod build）
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

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    # バンドルインストール時のキャッシュをDockerコンテナから削除
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# !todo: npm導入後コメントアウト解除
# # npm設定（本番 build 用）
# COPY package.json package-lock.json ./
# RUN npm ci && npm cache clean --force

# Railsアプリのコードすべて（一個目の./ホスト側のカレントディレクトリ)を
# コンテナ内(二個目の./コンテナ内のカレントディレクトリ)にコピー = コンテナに載せる
COPY . .

# precompile => アセットを先に用意しておき、読み込み速度向上するRailsの仕組み
# bootsnap => Rails が標準で使う高速化用ライブラリ、Rubyファイルの読み込みを速くする
RUN bundle exec bootsnap precompile app/ lib/

# SECRET_KEY_BASE_DUMMY=1　=> 本番用の秘密情報なしで、アセットプリコンパイルしてOKというフラグ
# !↑がないと、本物のSECRET_KEY_BASEがビルド時に渡されて、ビルドログやイメージレイヤーに残り、秘密情報が漏洩するリスクがある
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Node.jsがビルド時に存在するかチェック
RUN node -v

############################
# 3) runtime（実行専用：Nodeなし）
############################
FROM base AS runtime

# 実行時に必要な最小パッケージだけ
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    postgresql-client \
    tzdata \
    ca-certificates \
    # ====================
    #  MeCab（本体 + ランタイムライブラリ）
    # ====================
    mecab \
    libmecab2 \
    && rm -rf /var/lib/apt/lists/*

# natto が libmecab.so を見つけられるようにする
ENV MECAB_PATH=/usr/lib/x86_64-linux-gnu/libmecab.so.2

# build時の成果物をコピー（gems + アプリ + 生成済みassets）
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# =========================================
# ポジネガ辞書
COPY --from=build "${SENTIMENT_LEX_DIR}" "${SENTIMENT_LEX_DIR}"
RUN chmod -R a+rX "${SENTIMENT_LEX_DIR}"

# =========================================
#  ipadic-neologd + user.dic の配置

# MeCab辞書の配置先を作成
RUN mkdir -p /usr/local/lib/mecab/dic

# buildで退避した辞書をruntimeへコピー
COPY --from=build /opt/mecab-dic/mecab-ipadic-neologd \
  /usr/local/lib/mecab/dic/mecab-ipadic-neologd

COPY --from=build /opt/mecab-dic/user.dic \
/usr/local/lib/mecab/dic/user.dic

# =========================================

# 非rootで動かす => 本番環境は一般ユーザーで動かす
# rails(ID 1000)というLinuxグループを作る
RUN groupadd --system --gid 1000 rails && \
# rails(ID 1000) という一般ユーザーを作って、railsグループに入れる
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    # db log storage tmpのみ書き込み権限をrails:rails（一般ユーザー）に移譲
    chown -R rails:rails db log storage tmp
# 以降のユーザー権限はrails
USER 1000:1000

# ENTRYPOINT => コンテナを起動するときにはじめに実行するファイルを指定
# docker-entrypoint　=> DBを使える状態にしてからRails起動するコマンドが書いてある
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# 本番検証用のポート/サーバー指定
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
