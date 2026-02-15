import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "message"]
  static values = { limit: { type: Number, default: 140 } }

  // 初期表示時に警告表示を同期する
  connect() {
    this.check()
  }

  // 文字数に応じて警告文を切り替える
  check() {
    const value = this.inputTarget.value || ""
    const isOver = value.length > this.limitValue
    this.messageTarget.textContent = isOver ? `${this.limitValue}文字を超えています` : "\u00A0"
    this.messageTarget.classList.toggle("invisible", !isOver)
  }
}
