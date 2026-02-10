import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // visibleIcon: 「表示する」アクションを示すアイコン（visibility）
  // hiddenIcon: 「非表示にする」アクションを示すアイコン（visibility_off）
  static targets = ["input", "visibleIcon", "hiddenIcon", "toggleButton"]

  // 初期状態の設定をsyncIconVisibilityで実行
  connect() {
    this.syncIconVisibility()
  }

  // input.type を password/text で切り替え。アイコンの hidden を再同期する。
  toggle() {
    this.inputTarget.type = this.inputTarget.type === "password" ? "text" : "password"
    this.syncIconVisibility()
  }

  // password のときは visibility を表示、text のときは visibility_off を表示
  syncIconVisibility() {
    const passwordHidden = this.inputTarget.type === "password"
    this.visibleIconTarget.classList.toggle("hidden", !passwordHidden)
    this.hiddenIconTarget.classList.toggle("hidden", passwordHidden)
    this.toggleButtonTarget.setAttribute(
      "aria-label",
      passwordHidden ? "パスワードを表示" : "パスワードを非表示"
    )
  }
}
