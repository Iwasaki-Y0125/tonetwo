# Issue 156 作業メモ: PN名詞の中立上書き対応（user_pn.tsvの追加）

## 対象
- Issue: `#156`
- タイトル: `[nlp] PN名詞の中立上書き対応（user_pn.tsvの追加）`
- 作業ブランチ: `feature/issue-156-neutral-pn-overrides`

## 先に結論
- 今回の主目的は、`友人 / 友達 / 俳優 / 飛行機` をポジ扱い `+1` ではなく中立 `0` として扱えるようにすること。
- 既存の `sentiment_userdic/user_wago.tsv` は Wago 用で、実装上は `ポジ/ネガ` しか持てない。
- そのため、Issue キャプチャにある通り、**PN 側にユーザー上書き辞書を追加する方針**が妥当。
- MeCab 側は今回の4語が既に1語で安定して取れているかを確認し、必要な場合だけ `mecab_userdic/user.csv` を触る。今回の本丸は PN 辞書ロード順の変更。

## ローカル根拠
- サービス全体の NLP 構成は [README](../../../../README.md) にあり、形態素解析は `MeCab（Natto / NEologd + user.dic）`、ポジネガ分析は `日本語評価極性辞書（PN / Wago辞書 + user_wago.tsv / user_pn.tsv）`。
- MeCab のユーザー辞書運用は [2026-03-08-01-mecab-userdic-runbook.md](../mecab/2026-03-08-01-mecab-userdic-runbook.md) と [2025-12-26-02-userdic.md](../mecab/2025-12-26-02-userdic.md) にまとまっている。
- sentiment の現在実装は [2025-12-29-01-sentiment-module.md](./2025-12-29-01-sentiment-module.md) と [2026-01-07-02-sentiment-lexicon-prod.md](./2026-01-07-02-sentiment-lexicon-prod.md) が近い。
- 実コードでは:
  - `config/initializers/sentiment.rb` が `PN_LEX`、`WAGO_LEX`、`SENTIMENT_SCORER` を生成している
  - `app/services/sentiment/lexicon/pn.rb` は複数ファイルを順に読んで先勝ちで辞書化する
  - `app/services/sentiment/lexicon/wago.rb` は複数ファイル + 先勝ち実装
  - `script/sentiment/sentiment_test_score_cases.rb` が手元確認に使える
- `Gemfile.lock` では `natto (1.2.0)` を使用中。

## 一次ソース
- MeCab 公式トップ: <https://taku910.github.io/mecab/>
- MeCab 公式ドキュメント（辞書・学習系）: <https://taku910.github.io/mecab/learn.html>
- MeCab 公式フォーマット仕様: <https://taku910.github.io/mecab/format.html>
- mecab-ipadic-neologd 公式リポジトリ: <https://github.com/neologd/mecab-ipadic-neologd>
- Natto 公式リポジトリ: <https://github.com/buruzaemon/natto>
- 日本語評価極性辞書 配布元（東北大学 乾・岡崎研究室）: <https://www.cl.ecei.tohoku.ac.jp/Open_Resources-Japanese_Sentiment_Polarity_Dictionary.html>

## 現状整理
### sentiment 側
- `config/initializers/sentiment.rb` では、PN は `[user_pn.tsv, pn.csv.m3.120408.trim]`、Wago は `[user_wago.tsv, wago.121808.pn]` の順で読む。
- 辞書パスの存在確認は initializer 側で行い、足りないファイルがあれば名前付きで raise する。
- `app/services/sentiment/lexicon/wago.rb` は配列パスを受けて先勝ち上書きできる。
- `app/services/sentiment/lexicon/pn.rb` も同じく複数ファイルを先勝ちで読める。
- そのため、今回の中立上書きは Wago ではなく PN の拡張で入れる。

### MeCab 側
- `app/services/mecab/analyzer.rb` は dev/test では `mecab_userdic/user.dic`、production では `MECAB_USER_DIC` を読む。
- `Dockerfile` は build 時に `mecab_userdic/user.csv` から `user.dic` を生成する。
- つまり MeCab 側の語追加は:
  1. `mecab_userdic/user.csv` を編集
  2. dev では `mecab_userdic/user.dic` を再生成
  3. prod では Docker build 時に自動生成

## Issue 156 の実装方針
### 1. PN 用ユーザー上書き辞書を追加
- 追加候補: `sentiment_userdic/user_pn.tsv`
- 形式:

```tsv
友人	e	general
友達	e	general
俳優	e	general
飛行機	e	general
```

- 2列目は `p / n / e` を使い、`e` を中立として扱う。
- 3列目の category は現実装では未使用だが、base PN 辞書フォーマットに合わせて埋める。

### 2. `Sentiment::Lexicon::Pn` を複数ファイル対応にする
- `initialize(path)` を `initialize(paths)` 相当に変える。
- `Array(path)` で複数ファイル対応にする。
- 読み込み順は `user -> base` にして、先勝ちで採用する。
- `LABEL_MAP = { "p" => 1, "n" => -1, "e" => 0 }` をそのまま使う。

### 3. initializer を変更する
- `config/initializers/sentiment.rb` に `pn_user_path = Rails.root.join("sentiment_userdic/user_pn.tsv").to_s` を追加する。
- `PN_LEX = Sentiment::Lexicon::Pn.new([pn_user_path, pn_path])` に変更する。
- Wago と同じ「ユーザー辞書優先」の構造に揃える。

### 4. 必要なら MeCab 側を追加調整する
- 4語が MeCab 上で1語として取れていない場合のみ `mecab_userdic/user.csv` を検討する。
- ただし、この4語は一般名詞として既存辞書で取れる可能性が高いので、まずは token 確認を先にやる。

## 実作業の順番
1. 4語の token と base 表記を確認する。
2. base PN 辞書で現状 `+1` になっているかを確認する。
3. `sentiment_userdic/user_pn.tsv` を追加する。
4. `app/services/sentiment/lexicon/pn.rb` を複数ファイル対応に変える。
5. `config/initializers/sentiment.rb` を変更する。
6. テストまたは runner で `e => 0` に上書きできたことを確認する。
7. 必要時のみ `mecab_userdic/user.csv` と `user.dic` を触る。

## 推奨確認コマンド
### 1. 開発環境へ入る
```sh
make exec
```

### 2. MeCab で 4語の token を確認
```sh
bin/rails runner '
analyzer = Mecab::Analyzer.new
%w[友人 友達 俳優 飛行機].each do |word|
  tokens = analyzer.tokens(word)
  puts "=== #{word}"
  tokens.each { |t| p t.slice(:surface, :base, :pos, :pos1, :feature) }
end
'
```

### 3. 現状の PN スコアを確認
```sh
bin/rails runner '
%w[友人 友達 俳優 飛行機].each do |word|
  puts "#{word}: #{PN_LEX.score(word).inspect}"
end
'
```

### 4. 文中でのスコア確認
```sh
bin/rails runner '
analyzer = Mecab::Analyzer.new
[
  "友人のことを考えた",
  "友達と話した",
  "俳優を見た",
  "飛行機に乗った"
].each do |text|
  tokens = analyzer.tokens(text)
  p text: text, result: SENTIMENT_SCORER.score_tokens(tokens)
end
'
```

### 5. 変更後の最小確認
```sh
bin/rails runner '
%w[友人 友達 俳優 飛行機].each do |word|
  puts "#{word}: #{PN_LEX.score(word).inspect}"
end
'
```

## テスト観点
- `PN_LEX.score("友人") == 0` になること
- `PN_LEX.score("友達") == 0` になること
- `PN_LEX.score("俳優") == 0` になること
- `PN_LEX.score("飛行機") == 0` になること
- base PN 辞書にしかない既存語のスコアが壊れていないこと

## 実装メモ
- `app/services/sentiment/lexicon/wago.rb` の `@paths.each` + `dictionary[key] ||= score` は、そのまま PN に寄せられる。
- `sentiment_userdic/user_wago.tsv` は Wago 用なので、中立 `e` を表したい今回の用途には使わない。

## この Issue で触る可能性が高いファイル
- `sentiment_userdic/user_pn.tsv`
- `config/initializers/sentiment.rb`
- `app/services/sentiment/lexicon/pn.rb`
- `script/sentiment/sentiment_test_score_cases.rb`
- `mecab_userdic/user.csv`（必要時のみ）
- `mecab_userdic/user.dic`（必要時のみ）

## メモ
- `mecab_userdic/user.csv` は「分割を防ぐ辞書」、`sentiment_userdic/user_pn.tsv` は「極性を上書きする辞書」と役割が違う。混ぜて考えない。
- 先に token を確認してから辞書追加する。分かち書き問題と極性問題を切り分けるため。
