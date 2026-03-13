# 管理画面 Gem 比較メモ

## 目的
- ToneTwo に導入する管理画面 Gem の候補を、現行の Rails 構成と運用要件を前提に比較し、採用判断の材料を残す。

## 結論
- ToneTwo の現時点の優先順位では、管理画面 Gem は `Administrate` を第一候補として採用する。
- `Administrate` は現行構成に対して十分相性が良く、保守性と安心感のバランスが最もよい。
- `Madmin` は `Rails 8.1.2` + `Hotwire` + `importmap-rails` + `propshaft` との技術相性は魅力だが、情報量と継続保守の見通しで採用リスクが相対的に高い。
- 判断軸ごとの推奨は以下。
  - 総合判断: `Administrate`
  - 技術相性重視: `Madmin`
  - 日本語情報量 / 即戦力重視: `RailsAdmin`
- `ActiveAdmin` は Rails 8 前提だと採用判断がやや難しいため、優先度は下げる。

## 前提
- ローカル一次情報で確認した現行構成
  - Rails: `8.1.2`
  - Ruby / Gem 管理: `Gemfile`, `Gemfile.lock`
  - Frontend: `turbo-rails`, `stimulus-rails`, `importmap-rails`, `propshaft`
  - 認証: `has_secure_password`
  - 管理画面の主用途想定:
    - 通報対応
    - 危険ワード管理
    - 投稿 / ユーザーの検索と停止
    - モデレーション運用
    - `sentiment backfill` の運用実行

## 比較対象
- `Administrate`
- `Madmin`
- `RailsAdmin`
- `ActiveAdmin`

## 比較サマリ

| Gem | ライセンス | 初期機能量 | Rails標準への近さ | 現行構成との相性 | 主な評価 |
|---|---|---:|---:|---:|---|
| Administrate | MIT | 中 | 高 | 高 | 総合では最も無難 |
| Madmin | MIT | 中 | 高 | とても高い | 技術相性は高いが採用リスクあり |
| RailsAdmin | MIT | 高 | 中 | 中 | 情報量と即戦力は強い |
| ActiveAdmin | MIT | 高 | 低〜中 | 中 | 実績はあるが Rails 8 判断が難しい |

## 各候補の評価

### 1. Administrate

#### 良い点
- Rails に近い構成で理解しやすい。
- DSL が過剰ではなく、controller / view のカスタマイズに素直に入れる。
- CRUD 中心の管理画面を小さく始めやすい。
- モデレーション運用のように、画面ごとの独自要件が出やすいケースで破綻しにくい。

#### 注意点
- 初期状態の機能は控えめ。
- 複雑な絞り込み、監査、エクスポート、独自 action などは自前実装が増えやすい。

#### 向いているケース
- 必要な運営機能だけを段階的に足したい。
- Gem 独自 DSL に強く依存したくない。

#### ToneTwo 観点での評価
- 管理画面が業務システム級に肥大化しない前提なら十分有力。
- 技術相性、保守性、情報量のバランスが良く、現時点の第一候補として採用する。

### 2. Madmin

#### 良い点
- `Hotwire`、`Import maps`、`ActionText`、`has_secure_password` 対応が明示されている。
- Rails 標準寄りで、現代 Rails 構成との整合が取りやすい。
- `Administrate` と同様に、理解しやすく保守しやすい。

#### 注意点
- `Administrate` より導入事例や情報量は少なめ。

#### 向いているケース
- Rails 8 / Hotwire / importmap の流れを崩したくない。
- Rails 標準寄りの管理画面を採りたい。

#### ToneTwo 観点での評価
- 現行構成との相性は最も良い。
- ただし、日本語情報の少なさと新興ライブラリのため継続保守の見通しが立たないことを踏まえ、今回は代替候補として残す。

### 3. RailsAdmin

#### 良い点
- 検索、フィルタ、カスタム action、エクスポートなど初期機能が厚い。
- 早く「使える管理画面」を出しやすい。

#### 注意点
- Gem 側の流儀に寄るため、Rails の素直な作りからは少し離れる。
- 将来的なカスタマイズや保守で、Gem 前提の理解コストが上がりやすい。

#### 向いているケース
- 短期間で高機能な管理画面が必要。
- 管理画面側の要求が早期から多い。

#### ToneTwo 観点での評価
- 通報審査や投稿検索を早く厚く作りたいなら有力。
- 日本語記事・知名度・即戦力では有力。
- ただし、長期保守の軽さと gem 流儀の薄さでは `Administrate` / `Madmin` に劣る。

### 4. ActiveAdmin

#### 良い点
- 採用実績が多く、DSL ベースで管理画面を組みやすい。
- 機能量は多い。

#### 注意点
- 独自 DSL への依存が強め。
- Rails 8 前提では stable だけでなく beta 系も含めて確認が必要で、今このタイミングの新規採用候補としてはやや扱いづらい。

#### 向いているケース
- DSL ベースの管理画面構築に抵抗がない。

#### ToneTwo 観点での評価
- 今から新規で選ぶ優先度は低め。

## 判断軸ごとの整理

### 1. すぐ使える機能量
- 強い: `RailsAdmin`, `ActiveAdmin`
- 中間: `Madmin`
- 控えめ: `Administrate`

### 2. Rails 標準への近さ
- 高い: `Madmin`, `Administrate`
- 中間: `RailsAdmin`
- 低め: `ActiveAdmin`

## ToneTwo 向けの推奨

### 管理画面でやりたいこと
- 通報された投稿の確認と非表示対応
- ユーザーの状態確認と強制退会対応
- 危険ワード / 禁止語の管理
- 問題投稿の検索
- ユーザー辞書更新時に直近7日分の `sentiment backfill` を管理画面から実行

### これを踏まえた判断
- 主目的が「運営用モデレーション」であり、バックオフィス全体を大規模に作るわけではない。
- 単純な CRUD だけでなく、`backfill` 実行のような運用 action を載せたい。
- Rails 8 / Hotwire / importmap / propshaft を崩したくない。
- Rails 標準に寄せて保守したい。

この条件なら、以下の順で検討する。

1. `Administrate`
2. `Madmin`
3. `RailsAdmin`

## 採用判断メモ
- `Administrate` を選ぶなら:
  - 保守しやすさと安心感を優先する判断として妥当。
  - 最初は最小機能で入れて、通報対応画面や危険ワード管理、`backfill` 実行 action を必要に応じて足していく方針と相性が良い。
  - 技術相性も十分良く、総合では最も無難。
- `Madmin` を選ぶなら:
  - 現行構成との整合性を最優先する判断として妥当。
  - 新しめの Rails 標準構成を崩しにくく、運用向け action の追加も比較的素直に進めやすい。
  - ただし、日本語情報の少なさと継続保守の不透明さは採用リスクとして残る。
- `RailsAdmin` を選ぶなら:
  - 初期からフィルタや一覧機能、運用 action を厚く欲しい場合の割り切りとして妥当。
  - 日本語記事や知名度を重視するなら候補になる。
  - Gem 流儀への依存は受け入れる前提で採用する。

## 次の確認項目
1. 管理画面の対象モデルを列挙する
2. 通報審査フローで必要な画面と action を洗い出す
3. `Administrate` と `Madmin` のどちらで試作するかを決める
4. 試作後に、一覧性・検索性・カスタム action の実装負荷を比較する

## 参考
- ローカル一次情報
  - [Gemfile](../../../Gemfile)
  - [Gemfile.lock](../../../Gemfile.lock)
  - [README.md](../../../README.md)
- 公式情報
  - Administrate: <https://github.com/thoughtbot/administrate>
  - Administrate Getting Started: <https://administrate-demo.herokuapp.com/getting_started>
  - Administrate gem: <https://rubygems.org/gems/administrate/versions/1.0.0>
  - Madmin: <https://github.com/excid3/madmin>
  - Madmin gem: <https://rubygems.org/gems/madmin/versions/2.3.2>
  - RailsAdmin: <https://github.com/railsadminteam/rails_admin>
  - RailsAdmin gem: <https://rubygems.org/gems/rails_admin/versions/3.3.0>
  - ActiveAdmin: <https://github.com/activeadmin/activeadmin>
  - ActiveAdmin gem: <https://rubygems.org/gems/activeadmin>
