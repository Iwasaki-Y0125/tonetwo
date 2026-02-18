import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "message", "alert", "counter", "submit"]
  static values = { limit: { type: Number, default: 140 } }

  // 初期表示時に警告表示を同期する
  connect() {
    this.check()
  }

  // 文字数に応じて警告文を切り替える
  check() {
    const value = this.inputTarget.value || ""
    const count = value.length
    const isOver = value.length > this.limitValue

    if (this.hasCounterTarget) {
      this.counterTarget.textContent = `${count}/${this.limitValue}`
      this.counterTarget.classList.toggle("tt-form-counter-over", isOver)
    }

    this.messageTarget.textContent = isOver ? `${this.limitValue}字を超えているため投稿できません。` : "\u00A0"
    this.messageTarget.classList.toggle("invisible", !isOver)
    if (this.hasSubmitTarget) this.submitTarget.disabled = isOver
    if (!isOver) this.alertTarget.classList.add("hidden")
  }

  // 超過時の送信を防ぎ、フォーム上部にエラーを表示する
  guardSubmit(event) {
    const value = this.inputTarget.value || ""
    if (value.length <= this.limitValue) return

    event.preventDefault()
    this.alertTarget.classList.remove("hidden")
  }
}
