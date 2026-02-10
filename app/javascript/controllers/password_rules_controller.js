import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "alnum", "length"]

  // 初期値が入っているケースでも表示を正しくする
  connect() {
    this.check()
  }

  // 2条件（英字と数字を含む / 12文字以上）を判定
  check() {
    const value = this.inputTarget.value || ""
    const hasAlnum = /[A-Za-z]/.test(value) && /\d/.test(value)
    const hasLength = value.length >= 12

    this.updateLine(this.alnumTarget, "英字と数字を含む", hasAlnum)
    this.updateLine(this.lengthTarget, "12文字以上", hasLength)
  }

  // 1行分のテキストと色を更新
  updateLine(element, label, ok) {
    element.textContent = `${label} - ${ok ? "OK" : "未達成"}`
    element.classList.toggle("text-success", ok)
    element.classList.toggle("text-base-content/70", !ok)
  }
}
