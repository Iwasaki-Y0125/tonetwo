import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["confirmation", "message"]
  static values = { passwordSelector: String }

  // Enter確定時にだけ一致判定を走らせる
  checkOnKeydown(event) {
    if (event.key !== "Enter") return

    event.preventDefault()
    this.checkMismatch()
  }

  // 元パスワードと確認用を比較し、不一致時のみメッセージ表示
  checkMismatch() {
    const password = this.passwordInput()?.value || ""
    const confirmation = this.confirmationTarget.value || ""

    if (confirmation.length === 0 || password === confirmation) {
      this.clearMessage()
      return
    }

    this.messageTarget.textContent = "パスワードが一致しません。"
    this.messageTarget.classList.add("text-error")
    this.messageTarget.classList.remove("text-base-content/70")
  }

  // 元パスワード入力はIDセレクタで参照する
  passwordInput() {
    return document.querySelector(this.passwordSelectorValue)
  }

  // 一致時/未入力時はメッセージを消して通常色に戻す
  clearMessage() {
    this.messageTarget.textContent = ""
    this.messageTarget.classList.remove("text-error")
    this.messageTarget.classList.add("text-base-content/70")
  }
}
