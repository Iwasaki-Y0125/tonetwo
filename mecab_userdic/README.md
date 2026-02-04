# MeCab ユーザー辞書メモ

### 目的
- MeCab（mecab-ipadic-neologd）で、意図した単語が分割される問題を防ぐ
- 俗語/新語/固有名詞などを1語として扱えるようにする
- 品詞や読みを明示して、解析結果を安定させる

### 登録方針
- left-id / right-id / cost は推測しない
  - 近い既存語を `--node-format` で確認し、その値を流用する
- 品詞（feature）は既存語と同じ系列に揃える
  - 例：形容詞（イ段）、名詞（一般）、名詞（固有名詞）など
- まずは「分割されないこと」を優先し、必要に応じてコストを微調整する
  - 将来的にはAIで形態素解析~ポジネガ判定まで行うため、必要十分の登録にとどめて時間をかけないこと

### 登録手順
1. 登録したい語（例：うざい）が、現状どう分割されているか確認する
```sh
make exec
BASE_DIC="$(mecab-config --dicdir)/mecab-ipadic-neologd"
echo "うざい" | mecab -d "$BASE_DIC"

# 出力結果
う      感動詞,*,*,*,*,*,う,ウ,ウ
ざい    名詞,一般,*,*,*,*,*
EOS
```

2. 意味・用法が近い既存の参照語（例：うっとうしい）を選び、以下を取得する

```sh
echo "うっとうしい" | mecab -d "$BASE_DIC" \
  --node-format='%S 連結L=%phl 連結R=%phr 生起=%c 品詞=%H\n' \
  --bos-format='' --eos-format=''

# 出力結果
うっとうしい 連結L=43 連結R=43 生起=6956 品詞=形容詞,自立,*,*,形容詞・イ段,基本形,うっとうしい,ウットウシイ,ウットーシイ

# 連結L  = 43（前の単語と接続するときに参照されるID）
# 連結R = 43（次の単語と接続するときに参照されるID）

# 連接コスト
# 前の単語の right-id と 次の単語の left-id の組み合わせで決まる接続コスト
# 小さいほどその接続を含む経路が選ばれやすい

# 生起コスト = その単語を使うときのペナルティ。小さいほど採用されやすい
# 頻度などを目安に辞書側が調整している値だが、頻度そのものではない

# MeCabは
# 合計コスト = 生起コスト + 連接コストを足し上げ、
# BOS→EOS までの経路で合計が最小の分割を採用する

# ※ 連接コスト（%pC）や累積（%pc）は文脈（前後の単語）で変動するため、
#   ユーザー辞書登録の確認では生起（%c）と連結L/R（%phl/%phr）を主に見る。
```

3. `mecab_userdic/user.csv` に、参照語の形式をベースに行を追加する
   - 表層形 / 原形 / 読み / 発音だけ新語に合わせる
```csv
うざい,43,43,6956,形容詞,自立,*,*,形容詞・イ段,基本形,うざい,ウザイ,ウザイ
```

4. `mecab-dict-index` で `user.csv` を `user.dic` にコンパイルする
```sh
/usr/lib/mecab/mecab-dict-index -d "$BASE_DIC" -u mecab_userdic/user.dic -f utf-8 -t utf-8 mecab_userdic/user.csv
# mecab-dict-index　=> 辞書コンパイラ(csvを.dicにする)
# -d "$BASE_DIC"    => NEologd側の辞書設定に合わせてユーザー辞書をビルドする（互換性のため）
# -u mecab_userdic/user.dic => 出力先のバイナリファイル
# -f utf-8 -t utf-8 => 入力CSV（from）も出力辞書（to）もUTF-8で扱う指定(文字化け防止)
# mecab_userdic/user.csv => 入力元のCSV指定
```

5. `-u user.dic` を付けて期待どおりの解析になるか確認する
```sh
echo "うざい" | mecab -d "$BASE_DIC" -u mecab_userdic/user.dic \
  --node-format='%S 連結L=%phl 連結R=%phr 生起=%c 品詞=%H\n' \
  --bos-format='' --eos-format=''

# 出力例
うざい 連結L=43 連結R=43 生起=6956 品詞=形容詞,自立,*,*,形容詞・イ段,基本形,うざい,ウザイ,ウザイ
```
※nodeフォーマットについては下記情報を参考にしました
https://shogo82148.github.io/mecab/format.html
元ページ: https://github.com/taku910/mecab/blob/master/format.html

### 補足: mecab-dict-index: command not found のエラー対応
=>`mecab-dict-index`のファイルのパスを特定する必要がある。
  1) `LIBEXEC="$(mecab-config --libexecdir)"`
      - `mecab-config` は MeCab 付属の設定参照コマンド。
      - `--libexecdir` は「MeCabの補助実行ファイル（辞書作成ツールなど）が置かれるディレクトリ」を返す。
      => “辞書コンパイラ系ツールが置かれてる場所を聞いて、変数に保存

  2) `echo "$LIBEXEC"`
      変数の中身を表示してパスを確認

  3) `ls -la "$LIBEXEC" | head`
      /usr/lib/mecab の中身の先頭部分だけを一覧表示。
      => `mecab-dict-index`が`/usr/lib/mecab`にあることがわかる

  4) `find "$LIBEXEC" -maxdepth 2 -name 'mecab-dict-index*' -type f`
      念押しで、/usr/lib/mecab の中（`-maxdepth 2`深さ2階層まで）から`mecab-dict-index`のファイルを探す。
      -　`-type f `は「ファイルだけを対象にする指定」
      - `2>/dev/null`は「権限エラーなどの不要なエラー表示を捨てる」

  => `usr/lib/mecab/mecab-dict-index` に存在することを特定

出力例
```sh
$ LIBEXEC="$(mecab-config --libexecdir)"
$ echo "$LIBEXEC"
/usr/lib/mecab
$ ls -la "$LIBEXEC" | head
total 88
drwxr-xr-x 2 root root  4096 Dec 25 00:31 .
drwxr-xr-x 1 root root  4096 Dec 25 00:31 ..
-rwxr-xr-x 1 root root 14576 Feb 28  2025 mecab-cost-train
-rwxr-xr-x 1 root root 14576 Feb 28  2025 mecab-dict-gen
-rwxr-xr-x 1 root root 14576 Feb 28  2025 mecab-dict-index
-rwxr-xr-x 1 root root 14576 Feb 28  2025 mecab-system-eval
-rwxr-xr-x 1 root root 14576 Feb 28  2025 mecab-test-gen
$ find "$LIBEXEC" -maxdepth 2 -name 'mecab-dict-index*' -type f 2>/dev/null
/usr/lib/mecab/mecab-dict-index
```
