import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["email", "password", "confirmation", "terms", "submit"]

  // 初期表示時にボタン状態を同期
  connect() {
    this.update()
  }

  // 入力状態に応じてsubmitのdisabledを切り替える
  update() {
    if (!this.hasSubmitTarget) return
    this.submitTarget.disabled = !this.canSubmit()
  }

  // 念のため、無効条件ではsubmit自体を抑止する
  guardSubmit(event) {
    if (this.canSubmit()) return
    event.preventDefault()
  }

  // 有効化条件: メール妥当 + PWルール達成 + PW一致 + 規約同意
  canSubmit() {
    if (!this.hasEmailTarget || !this.hasPasswordTarget || !this.hasConfirmationTarget || !this.hasTermsTarget) {
      return false
    }

    const email = this.emailTarget.value || ""
    const password = this.passwordTarget.value || ""
    const confirmation = this.confirmationTarget.value || ""

    const validEmail = email.length > 0 && this.emailTarget.checkValidity()
    const hasAlnum = /[A-Za-z]/.test(password) && /\d/.test(password)
    const hasLength = password.length >= 12
    const matched = password.length > 0 && password === confirmation
    const acceptedTerms = this.termsTarget.checked

    return validEmail && hasAlnum && hasLength && matched && acceptedTerms
  }
}
