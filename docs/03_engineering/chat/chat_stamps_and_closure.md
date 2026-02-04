# ToneTwo 仕様メモ：チャット

---

## 1. チャット：交互返信 + スタンプで終了

### 1.1 要件
- chatrooms内は交互返信（連投不可）
- 返信の代わりにスタンプで終わらせられる
- スタンプが押されたメッセージには、テキストでもスタンプでも返信できない

### 1.2 判定を単純化する設計
- `chatrooms.last_sender_id` を持つ
  - 交互返信判定：`last_sender_id != current_user.id`
- `chatrooms.closed_at` を追加
  - スタンプが押されたら `closed_at` をセットし、以後は送信不可
  - 送信可否判定を `closed_at` に統一できる
