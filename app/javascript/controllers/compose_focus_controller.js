import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "submit"]

  // 投稿ボタン以外を押したときに、入力欄へフォーカスを移す
  activate(event) {
    if (this.hasSubmitTarget && this.submitTarget.contains(event.target)) return
    if (!this.hasInputTarget) return

    this.inputTarget.focus({ preventScroll: true })
  }
}
