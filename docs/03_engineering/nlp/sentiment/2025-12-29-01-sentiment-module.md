# 日本語評価極性辞書でポジネガスコア算出

## 目的
- 日本語評価極性辞書（PN / wago）で投稿テキストの簡易ポジネガスコアを出す
- MeCab（Natto）の `tokens(Hash配列)` をそのまま入力にできる形にする
- 辞書未収録の表記ゆれ/俗語を **ユーザー辞書で運用**できるようにする

## 結論
- PN：
  - `word \t label(p/n/e/ノイズ) \t category` を読み込み
  - `p=1, n=-1, e=0` の辞書化（ノイズ除外）
- Wago：
  - `ラベル \t 表現(単語/フレーズ)` を **空白区切りフレーズ（最大5語）**として辞書化
  - 6語以上は一致しにくく辞書内でも少数のため対象外
  - `user.pn` を **本体辞書より優先**して読み込む
- Scorer：
  - 対象品詞（名詞/形容詞/動詞/副詞）をインデックス抽出し探索を軽量化
  - `wago` は **最長一致（最大5語）**でフレーズ評価 → 次に `pn` を単語評価
  - 重複カウント防止のため `covered_by_hit` でヒット範囲をマーキング
  - 否定語は tokens 全体から検出し、window以内の直前ヒットを **フレーズ単位**で反転
    - 否定語が「ヒットフレーズ内」に含まれる場合は反転しない
  - 「ん」の否定扱いは誤爆しやすいので **助動詞のときのみ**否定扱いに調整

## ディレクトリ / ファイル
- 既存辞書（Docker内）
  - `/opt/sentiment_lex/pn.csv.m3.120408.trim`
  - `/opt/sentiment_lex/wago.121808.pn`
- ユーザー辞書（リポジトリ管理）
  - `sentiment_userdic/user.pn`（Wago user dict）
- 初期化（Rails）
  - `config/initializers/sentiment.rb`
    - `SENTIMENT_LEX_DIR` 配下の辞書パスを組み立てて `PN_LEX / WAGO_LEX / SENTIMENT_SCORER` を生成
- 動作確認スクリプト
  - `script/sentiment_test_score_cases.rb`（短文ケース）
  - `script/mecab_samples.rb`（長文サンプル定義）
  - `script/sentiment_test_score_mecab_samples.rb`（長文ケース）



## 変更点
- `Sentiment::Lexicon::Wago`
  - 語幹だけの辞書化を廃止し、**フレーズ（最大5語）**を長さ別 Hash で保持
  - `score_terms(terms)`（`terms.join(" ")`）で参照できるようにした
  - パスを複数受け取り可能にし、`[wago_user_path, wago_path]` の順で読み込み
- `Sentiment::Scorer`
  - `wago` をフレーズ最長一致（最大5語）で評価
  - `span`（マッチ語数）を hits に追加
  - `covered_by_hit` で重複カウント防止
  - 優先順位を `wago（フレーズ） → pn（単語）` に変更
  - 否定反転をフレーズ対応（covered_by_hit参照）に変更
- ユーザー辞書
  - `sentiment_userdic/user.pn` に表記ゆれ/俗語を追加して吸収（例：うれしい、まずい、微妙、買い得 など）
  - `mecab_userdic/user.csv` に `しか勝たん` を登録して分割を防止



## ユーザー辞書追加手順
### 1) ユーザー辞書を編集
- Wago：`sentiment_userdic/user.pn` に追記（TSV：ラベル + TAB + 表現）
- MeCab：`mecab_userdic/user.csv` に追記（近い既存語のL/R/cost/featureを流用）

### 2) web を再起動して反映
```sh
make dev-restart
```

### 3) 動作確認
- 短文サンプル
```sh
make exec
bin/rails runner script/sentiment_test_score_cases.rb > tmp/sentiment_score_cases.log
```
- 長文サンプル
```sh
make exec
bin/rails runner script/sentiment_test_score_mecab_samples.rb > tmp/sentiment_mecab_samples.log
```



## エラー時チェック用コマンド例
### 1) 既存辞書（pn / wago）が配置されているか
```sh
make exec
ls -l /opt/sentiment_lex/pn.csv.m3.120408.trim
ls -l /opt/sentiment_lex/wago.121808.pn
```

### 2) user辞書がコンテナ内にあるか
```sh
make exec
ls -l /app/sentiment_userdic/user.pn
```

### 3) PN が引けてるか（pn側の語で確認）
```sh
make exec
bin/rails runner "p PN_LEX.score(%q[最高])"
bin/rails runner "p PN_LEX.score(%q[最悪])"
# 期待: 1 / -1 が返る（nil なら辞書ロード失敗 or その語が辞書にない）
```

### 4) Wago（本体辞書）が引けてるか
```sh
make exec
bin/rails runner "p WAGO_LEX.score_terms(%w[楽しい])"
bin/rails runner "p WAGO_LEX.score_terms(%w[良い ない])"
# 期待: 1 / -1 が返る（nil なら辞書ロード失敗 or そのフレーズが辞書にない）
```

### 5) user辞書を読めてるか
```sh
make exec
bin/rails runner "p WAGO_LEX.score_terms(%w[うれしい])"
bin/rails runner "p WAGO_LEX.score_terms(%w[微妙])"
# 期待: 1 / -1 が返る（nil なら user辞書が未反映 or 表記が一致してない）
```

### 6) scorer が動くか
```sh
make exec
bin/rails runner '
analyzer = Mecab::Analyzer.new
tokens = analyzer.tokens(%q[最高じゃない])
p SENTIMENT_SCORER.score_tokens(tokens)
'
# 期待: {:total=>-1.0,... negated=true ...} のように結果が出る
```


## ユーザー辞書について補足メモ
- 慣用表現は MeCabの分割・品詞次第でbase表記がズレる
  - スコアに反映されない時は、短文サンプルの`NORM_TERM`を確認し、ポジネガユーザー辞書側でbase表記で登録
  - 例 => `鼻持ちならない` は `鼻持ち だ ない` (base表記)で登録
  #### NORM_TERMS を確認するコマンド例（単発で確認）
  ```sh
  make exec
  bin/rails runner '
  analyzer = Mecab::Analyzer.new
  text = %q[鼻持ちならない]
  tokens = analyzer.tokens(text)

  norm_terms = tokens.map do |t|
    base = t[:base].to_s
    surf = t[:surface].to_s
    (base.empty? || base == "*") ? surf : base
  end

  puts norm_terms.join(" ")
  '
  ```


## 参考
- 日本語評価極性辞書 配布ページ（東北大学 乾・岡崎研究室）
https://www.cl.ecei.tohoku.ac.jp/Open_Resources-Japanese_Sentiment_Polarity_Dictionary.html
- Qiita: 3. Pythonによる自然言語処理　5-4. 日本語文の感情値分析［日本語評価極性辞書（名詞編）］https://qiita.com/y_itoh/items/4693bd8f64ac811f8524
- Qiita: 3. Pythonによる自然言語処理　5-5. 日本語文の感情値分析［日本語評価極性辞書（用言編）］https://qiita.com/y_itoh/items/7c528a04546c79c5eec2
- MeCab公式: https://taku910.github.io/mecab/
- natto（GitHub）: https://github.com/buruzaemon/natto
