import { Controller } from "@hotwired/stimulus"

// flash通知を「一定時間後に消す / ボタンで閉じる」ための controller
export default class extends Controller {
  // closeAfterMsValue: ミリ秒で指定。例: 5000 (5秒後に消す)
  static values = {
    closeAfterMs: Number
  }

  // closeAfterMsValue後に閉じるためのタイマーをセット
  connect() {
    this.timeoutId = setTimeout(() => {
      this.closeToast()
    }, this.closeAfterMsValue)
  }

  // タイマー終了後、次回に残らないようにタイマーをクリアする
  disconnect() {
    if (this.timeoutId) clearTimeout(this.timeoutId)
  }

  // 閉じるアクション本体
  // （application.html.erbの「×」ボタンからも呼び出されるため切り出し）
  closeToast() {
    this.element.remove()
  }
}
