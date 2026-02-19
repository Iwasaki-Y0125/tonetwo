import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "submit"]

  // 投稿ボタン以外を押したときに、入力欄へフォーカスを移す
  activate(event) {
    const submit =
      this.hasSubmitTarget ? this.submitTarget : this.element.querySelector("[data-compose-focus-target='submit']")
    if (submit && submit.contains(event.target)) return

    const input =
      this.hasInputTarget ? this.inputTarget : this.element.querySelector("textarea, input[type='text']")
    if (!input) return

    input.focus({ preventScroll: true })
  }
}
