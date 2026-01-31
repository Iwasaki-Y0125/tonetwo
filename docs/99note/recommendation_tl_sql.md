雑記

おすすめTL表示方法検討

1. 直近7日・最新10件の自分の投稿を取る
2. その10件と紐づくpost_termsからterms取り出す。termsにその投稿ごとのsentiment_labelをくっつける → seed は (term_id, sentiment_label) の集合になる
3. seedのterm_idと一致する他ユーザーのpost_idをpost_termsから引き出す。その際にpostsからsentiment_labelも参照し、seedと一致するもののみcandidatesに格納する
4. 新しい投稿順に並べる。

なんかもっとすっきりできる気もするが、スクール卒業日まで時間ないので、一旦これを前提のテーブル構成で行く。

SQL案メモ　未精査
```sql
-- おすすめTL（単語×ポジネガ一致で候補抽出 → 新しい投稿順）
WITH recent_posts AS (
  -- 1. 直近7日・最新10件の自分の投稿
  SELECT id, sentiment_label
  FROM posts
  WHERE user_id = :me
    AND created_at >= (now() - interval '7 days')
    AND moderation_state = 'visible'
  ORDER BY created_at DESC
  LIMIT 10
),
seed AS (
  -- 2. 10件に含まれる term を取り出し、(term_id, sentiment_label) の集合にする
  SELECT DISTINCT pt.term_id, rp.sentiment_label
  FROM post_terms pt
  JOIN recent_posts rp ON rp.id = pt.post_id
),
candidates AS (
  -- 3. seed と term_id が一致する他ユーザー投稿を拾い、
  --    posts.sentiment_label も seed と一致するものだけ候補にする
  SELECT DISTINCT p.id AS post_id, p.created_at
  FROM seed s
  JOIN post_terms pt2
    ON pt2.term_id = s.term_id
  JOIN posts p
    ON p.id = pt2.post_id
   AND p.sentiment_label = s.sentiment_label
  WHERE p.user_id <> :me
    AND p.moderation_state = 'visible'
    AND p.share_scope = 'all'
    AND p.created_at >= (now() - interval '7 days')
)
-- 4. 新しい投稿順に並べる
SELECT post_id
FROM candidates
ORDER BY created_at DESC
LIMIT 50;

```

  インデックス貼るか迷う。たぶん要らない。どうしても遅かったら試す。
  - `index_posts_on_sentiment_label_share_scope_and_moderation_state_and_created_at`（おすすめTL表示用）

  post_termsにsentiment_labelを持たせることも考えたが、将来ポジネガ値調整後に再集計する場合に不整合がおこりそうなのでやめる。
