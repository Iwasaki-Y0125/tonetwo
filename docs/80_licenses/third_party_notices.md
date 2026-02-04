# Third-party notices (サードパーティ通知)

本リポジトリは、OSS および公開言語資源を利用しています。

各ソフトウェア／辞書のライセンス・利用条件は、配布元の記載に従います。
※このファイルは法的助言ではありません。

---

## 形態素解析

### MeCab
- 概要: 日本語形態素解析エンジン
- 配布元: MeCab 公式サイト
- ライセンス: GPL / LGPL / BSD のトリプルライセンス（利用者が選択可能）
- 備考: 実行環境では OS パッケージ経由でインストールしています。

### natto (Ruby gem)
- 概要: MeCab の Ruby バインディング
- バージョン: 1.2.0
- 配布元: RubyGems / GitHub
- ライセンス: BSD（RubyGems の gem 情報に基づく）

### mecab-ipadic-NEologd
- 概要: MeCab 用の新語辞書（mecab-ipadic 派生）
- 配布元: GitHub (neologd/mecab-ipadic-neologd)
- ライセンス: Apache License 2.0（配布元表記に基づく）
- 利用形態:
  - Docker ビルド時に配布元リポジトリを取得し、辞書を生成・インストールします。
  - 実行時は、生成済み辞書をコンテナ内の固定パスに退避して参照します。

---

## 感情極性（ポジネガ）辞書

### 日本語評価極性辞書（名詞編 / 用言編）
- 配布元: 東北大学 乾・岡崎研究室 公開資源
- 利用ファイル:
  - 用言編: `wago.121808.pn`
  - 名詞編: `pn.csv.m3.120408.trim`
- 利用条件（配布元の記載に従う）:
  - クレジット明記により商用利用可
  - 辞書利用時は参考文献を引用すること
- 運用:
  - リポジトリには原本を同梱せず、Docker ビルド時に配布元からダウンロードして利用します。

#### 参考文献（配布元の指示に従い引用）
- 小林のぞみ，乾健太郎，松本裕治，立石健二，福島俊一. 意見抽出のための評価表現の収集. 自然言語処理，Vol.12, No.3, pp.203-222, 2005. / Nozomi Kobayashi, Kentaro Inui, Yuji Matsumoto, Kenji Tateishi. Collecting Evaluative Expressions for Opinion Extraction, Journal of Natural Language Processing 12(3), 203-222, 2005.
- 東山昌彦, 乾健太郎, 松本裕治, 述語の選択選好性に着目した名詞評価極性の獲得, 言語処理学会第14回年次大会論文集, pp.584-587, 2008. / Masahiko Higashiyama, Kentaro Inui, Yuji Matsumoto. Learning Sentiment of Nouns from Selectional Preferences of Verbs and Adjectives, Proceedings of the 14th Annual Meeting of the Association for Natural Language Processing, pp.584-587, 2008.

---

## RubyGems（Bundler）依存関係（抜粋）

依存 gem は増減するため、一覧は **自動生成** します。
- 一覧: `docs/licenses/gems.md`（生成物）

生成コマンド例:
- `bundle exec ruby script/licenses/gems_md_report.rb > docs/licenses/gems.md`

（※なお、本ファイルでは、確認できないライセンスを推測で記載しない方針です）
