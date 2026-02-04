# SimilarPostsQuery / AnalyzePost ベンチ結果

## 目的
- Issue #7: 「名詞一致 + 極性 + 直近投稿」で類似投稿が実用速度で返るか確認する
- Issue #8: 投稿解析（名詞抽出/スコア計算/保存）を非同期化する必要性の判断材料を得る

## 結論
- 類似投稿クエリは **ミリ秒オーダー**で安定しており、**1000件規模で遅すぎない**（MVP要件を満たす）
- 投稿解析（AnalyzePost）も **ミリ秒オーダー**で、MVP段階では **Solid Queue 等での非同期化は必須ではない**
  - 将来「投稿作成レスポンスを最優先」または「解析が重くなる（辞書増・処理追加・同時投稿増）」場合に検討余地あり

## 測定環境
- 実行: Docker dev コンテナ内（`make exec`）
- 計測: Rails runner + Benchmark（ウォームアップあり）
- 出力ログ:
  - `log/bench/explain_similar_posts_20260113_155845.log`
  - `log/bench/bench_similar_posts_20260113_160114.log`
  - `log/bench/bench_analyze_post_20260113_160205.log`

## 計測結果

### 1) SimilarPostsQuery（EXPLAIN）
- Planning Time: **0.282 ms**
- Execution Time: **1.277 ms**

> 詳細はログ参照: `log/bench/explain_similar_posts_20260113_155845.log`

### 2) SimilarPostsQuery（ベンチ）
実行コマンド:
```bash
N=300 LIMIT=10 bin/rails runner script/bench_similar_posts.rb
```
結果:
- avg: 2.92 ms
- p50: 2.62 ms
- p95: 3.62 ms
- p99: 18.30 ms
- max: 22.81 ms

> 詳細はログ参照: `log/bench/bench_similar_posts_20260113_160114.log`

### 3) Posts::AnalyzePost（ベンチ）
実行コマンド:
```bash
N=200 bin/rails runner script/bench_analyze_post.rb
```
結果:
- avg: 7.11 ms
- p50: 6.84 ms
- p95: 8.76 ms
- p99: 16.30 ms
- max: 30.61 ms

> 詳細はログ参照: `log/bench/bench_analyze_post_20260113_160205.log`

## 判断メモ（Issue #7 Done条件 / Issue #8）
- Issue #7（速度要件）
  - 「1000件程度で遅すぎない」について、`SimilarPostsQuery` が avg 2〜3ms / p95 4ms未満であり、MVPとして十分
  - `EXPLAIN`でも `Execution(実行時間)` 1.277ms を確認済み

- Issue #8（非同期化の必要性）
  - `AnalyzePost` が `avg` 7ms / `p95` 9ms 程度であり、投稿作成時に同期で走らせても体感ボトルネックになりにくい
  - よって、MVP時点では `Solid Queue` 等による非同期化は機能として追加せず、同期実行のまま進める
  - ただし、以下の条件では非同期化を本リリース前に再検討する
    - 辞書増加・処理追加で `AnalyzePost` が目に見えて重くなった
    - 同時投稿が増え、Webレスポンスを最優先したくなった
    - 外部API連携やAI解析等、I/O待ちが入るようになった
