### ER図
すべてのテーブルに共通するため下記は省略する
- created_at : datetime
- updated_at : datetime
![alt text](ToneTwo.drawio.png)

---

### 本サービスの概要（700文字以内）
- 140字の匿名投稿を「名詞×気分（ポジ/ネガ）」で分析し、似た投稿をレコメンドするSNS
- 「たまたま同じ気分」の相手と1on1で、交互返信やスタンプで落ち着いてやり取りできる
- 通報/ブロック、危険ワード規制、ミュートワードで心理的安全性を担保する

ToneTwo（トーン・ツー）は、140字の匿名投稿から名詞と気分（ポジ/ネガ）を抽出し、
似た気分の投稿をレコメンドして「たまたま同じ気分だった」相手と1on1でやり取りできるSNSです。
フォロー数や“いいね”のような評価軸に寄らず、投稿そのものを起点にゆるくつながる体験を目指します。
投稿はテキストのみ。返信は交互返信で連投できず、返信圧や荒らしを抑えます。
通報/ブロック、危険ワード規制、ミュートワード等で心理的安全性を担保します。

---

### MVPで実装する予定の機能
- ユーザー登録機能
- 利用規約 / プライバシーポリシー / サードパーティーライセンスの明示
- 投稿機能
    - 投稿の形態素解析/ポジネガ分析
    - 似ている気分のおすすめTLでレコメンド機能
    - チャット機能
        - メッセージを交互にやり取りできる
        - スタンプが押されたらチャット終了
    - スタンプ機能(ポスト)
        - ポストにスタンプを返せる。
        - ポジ/ネガで表示されるスタンプが異なる
        - 3種類表示され、それぞれ一回まで押せる
    - スタンプ機能(チャット)
        - 2種類表示され、どちらか一回しか押せない
        - スタンプ押された場合、チャット終了（どちらもメッセージを送れなくなる）
        - チャットのスタンプは、返信するのは気分的に重いが、軽くお礼はしたいときのためを想定しているのでこの仕様
- TL機能
    - すべての投稿の表示
    - おすすめ投稿の表示
- メール配信
    - 登録時のメールアドレス確認
    - リプライの通知
- マイページ
    - 自投稿の一覧
        - 投稿ごとに設定の変更機能
    - リプライ中のチャットを一覧で表示
        - ブロック/通報機能
    - ユーザー設定
        - 自投稿のリアクション(リプOKか/スタンプのみか)のデフォルト設定
        - 自投稿の表示範囲（全体TLも含むか/おすすめのみか）のデフォルト設定
        - メール通知のON/OFF設定
        - ミュートワードの設定
        - メールアドレスの変更
        - 退会機能
            - アカウント（メールアドレス）は物理削除
            - 他ユーザーへのリプライを残すため、投稿内容は残す
            （メールアドレス "deleted+<user_id>@example.invalid" に差し替え）
            - 退会後、一定期間は同一メールで再登録不可
    - お問い合わせ（不具合報告フォーム、MVPはGoogleフォームで代用）
- 管理画面(モデレーション)
    - 危険ワードの投稿規制
    - こころの電話等の公式窓口への案内
    - 公序良俗にそぐわない投稿へのバリデーション
        - 危険ワードは投稿時にブロック/案内
        - 通報された投稿は審査で非表示/措置
        - 通報回数が一定数たまった場合、強制退会

---

### テーブル詳細

すべてのテーブルに共通するため下記は省略する
- id (PK)    : bigint
- created_at : datetime
- updated_at : datetime

なお、冗長になるため、各カラムの型は省略（ER図参照）

テーブル詳細では主にカラムの役割とユニーク制約/インデックスを説明

---

#### usersテーブル（ユーザー情報）
- email_address : ログイン認証用メールアドレス / UNIQUE
- password_digest : パスワードハッシュ
- pending_email_address : メール変更時のメールアドレス仮置き / UNIQUE
- email_verified_at : メール確認完了日時
- role : 権限（admin/user）
- deleted_at : 退会日時
- Index
  - `index_users_on_email_address`（UNIQUE）
  - `index_users_on_pending_email_address`（UNIQUE）

#### user_settingsテーブル（ユーザー設定）
- user_id (FK) : users.id / UNIQUE（1ユーザー1設定）
- default_visibility : 投稿のデフォルト公開範囲
- default_reply_mode : 投稿のデフォルト返信モード
- mail_notification : メール通知ON/OFF
- Index
  - `index_user_settings_on_user_id`（UNIQUE）

#### user_muted_termsテーブル（ミュートワード）
- user_id (FK) : users.id
- term : ミュート対象語 / UNIQUE(user_id, term)
- Index
  - `index_user_muted_terms_on_user_id_and_term`（UNIQUE）

#### user_blocksテーブル（ブロック）
- blocker_user_id (FK) : users.id
- blocked_user_id (FK) : users.id / UNIQUE(blocker_user_id, blocked_user_id)
- Index
  - `index_user_blocks_on_blocker_and_blocked`（UNIQUE）

#### sessionsテーブル（ログインセッション）
- user_id (FK) : users.id
- ip_address : IPアドレス（Rails8標準認証デフォルトカラム）
- user_agent : UA情報（Rails8標準認証デフォルトカラム）
- Index
  - `index_sessions_on_user_id`（退会・BAN時のユーザーの全セッション削除/参照用）

---

#### postsテーブル（投稿）
- user_id (FK) : users.id
- body : 投稿本文
- sentiment_score : ポジネガスコア
- sentiment_label : ポジ/ネガの二値（クエリ高速化のため）
- share_scope : TL表示範囲（すべてのTL/おすすめのみ）
- reply_mode : 返信可/スタンプのみ
- moderation_state : モデレーション状態（通報審査後の表示状態：visible / hidden）
- moderated_at : モデレーション日時
- Index
  - `index_posts_on_user_id_and_created_at`（自投稿一覧）
  - `index_posts_on_share_scope_and_moderation_state_and_created_at`（すべてTL表示用）

#### termsテーブル（抽出語マスタ）
- term : 抽出語 / UNIQUE
- Index
  - `index_terms_on_term`（UNIQUE）

#### post_termsテーブル（投稿×抽出語の中間テーブル）
- post_id (FK) : posts.id
- term_id (FK) : terms.id / UNIQUE(post_id, term_id)
- Index
  - `index_post_terms_on_post_id_and_term_id`（UNIQUE）
  - `index_post_terms_on_term_id_and_post_id`（「この単語を含む投稿」の逆引き検索）

---

#### stampsテーブル（スタンプマスタ）
- stamp : スタンプ種類
- category : カテゴリ（ポジ/ネガ/チャット用）

#### post_stampsテーブル（投稿へのスタンプ,一人一回までそれぞれ押せる）
- post_id (FK) : posts.id
- stamp_id (FK) : stamps.id
- user_id (FK) : users.id / UNIQUE(post_id, stamp_id, user_id)
- Index
  - `index_post_stamps_on_post_stamp_user`（UNIQUE：post_id, stamp_id, user_id）

---

#### chatroomsテーブル（チャットルーム）
- post_id (FK) : posts.id
- reply_user_id (FK) : users.id
- last_sender_id (FK) : users.id（直近送信者、交互やり取りのフラグ保存に使用）
- last_message_at : 最終メッセージ日時（チャット一覧でのソート用）
- closed_at : チャットクローズ日時（スタンプをおしたときに入る *スタンプ機能要件を参照）
- UNIQUE(post_id, reply_user_id)（同一投稿×同一相手のルーム重複防止）
- Index
  - `index_chatrooms_on_post_id_and_reply_user_id`（UNIQUE）
  - `index_chatrooms_on_reply_user_id_and_last_message_at`（一覧ソート）
  - `index_chatrooms_on_post_id_and_last_message_at`（自投稿詳細の紐づいてるチャット一覧用）
- 補足 post_user_idを持たせるかは最後まで迷いましたが、MVP時点では正規化した状態とし、JOINが重いなどパフォーマンスに問題が出てきた場合に追加する想定。

#### messagesテーブル（チャットメッセージ）
- chatroom_id (FK) : chatrooms.id
- user_id (FK) : users.id（送信者）
- body : 本文
- moderation_state : モデレーション状態（通報審査後の表示状態：visible / hidden）
- moderated_at : モデレーション日時
- Index
  - `index_messages_on_chatroom_id_and_created_at`（ルーム内時系列表示）

#### message_stampsテーブル（メッセージへのスタンプ）
- message_id (FK) : messages.id
- stamp_id (FK) : stamps.id
- user_id (FK) : users.id / UNIQUE(message_id, user_id)
- Index
  - `index_message_stamps_on_message_id_and_user_id`（UNIQUE）
  *1ユーザーあたり一つしかスタンプ押せない
  - `index_message_stamps_on_message_id`（メッセージのスタンプ集計）

---

#### filter_termsテーブル（危険ワード・規制ワード）
- term : 投稿禁止語 / UNIQUE
- action : アクション（reject：通常の投稿禁止語 / support：自殺企図が含まれていてサポート案内する語）
- Index
  - `index_filter_terms_on_term`（UNIQUE）

#### matching_exclusion_termsテーブル（マッチング除外語）
- term : おすすめ表示のマッチングでの除外語（私、ここ、今日など） / UNIQUE
- Index
  - `index_matching_exclusion_terms_on_term`（UNIQUE）

---

#### post_abuse_reportsテーブル（投稿通報）
- reporter_user_id (FK) : users.id（通報者）
- post_id (FK) : posts.id（通報対象投稿）
- reason : 通報理由
- reason_other_details : その他詳細 / UNIQUE(reporter_user_id, post_id)
- Index
  - `index_post_abuse_reports_on_reporter_and_post`（UNIQUE）

#### post_abuse_reviewsテーブル（投稿通報の審査）
- post_abuse_report_id (FK) : post_abuse_reports.id / UNIQUE（1通報=1審査）
- result : 審査結果（violation：違反あり / no_violation：違反なし）
- Index
  - `index_post_abuse_reviews_on_post_abuse_report_id`（UNIQUE）

#### post_abuse_penaltiesテーブル（投稿に対する措置）
- penalized_user_id (FK) : users.id（被ペナルティ者）
- post_abuse_review_id (FK) : post_abuse_reviews.id / UNIQUE（1審査=1措置）
- Index
  - `index_post_abuse_penalties_on_post_abuse_review_id`（UNIQUE）

---

#### message_abuse_reportsテーブル（メッセージ通報）
- reporter_user_id (FK) : users.id（通報者）
- message_id (FK) : messages.id（対象メッセージ）
- reason : 通報理由
- reason_other_details : その他詳細 / UNIQUE(reporter_user_id, message_id)
- Index
  - `index_message_abuse_reports_on_reporter_and_message`（UNIQUE）

#### message_abuse_reviewsテーブル（メッセージ通報の審査）
- message_abuse_report_id (FK) : message_abuse_reports.id / UNIQUE（1通報=1審査）
- result : 審査結果（violation：違反あり / no_violation：違反なし）
- Index
  - `index_message_abuse_reviews_on_message_abuse_report_id`（UNIQUE）

#### message_abuse_penaltiesテーブル（メッセージに対する措置）
- penalized_user_id (FK) : users.id（被措置者）
- message_abuse_review_id (FK) : message_abuse_reviews.id / UNIQUE（1審査=1措置）
- Index
  - `index_message_abuse_penalties_on_message_abuse_review_id`（UNIQUE）

---

#### deleted_user_email_locksテーブル（退会メールの再登録ロック、荒らし対策）
- email_digest : 退会者のemailのdigest / UNIQUE
- lock_type : ロック種別（normal：通常退会 / banned：強制退会）
- locked_until : ロック期限（強制退会は "9999-12-31 23:59:59"）
- Index
  - `index_deleted_user_email_locks_on_email_digest`（UNIQUE）



### ER図の注意点
- [ ] プルリクエストに最新のER図のスクリーンショットを画像が表示される形で掲載できているか？
- [ ] テーブル名は複数形になっているか？
- [ ] カラムの型は記載されているか？
- [ ] 外部キーは適切に設けられているか？
- [ ] リレーションは適切に描かれているか？多対多の関係は存在しないか？
- [ ] STIは使用しないER図になっているか？
- [ ] Postsテーブルにpost_nameのように"テーブル名+カラム名"を付けていないか？
