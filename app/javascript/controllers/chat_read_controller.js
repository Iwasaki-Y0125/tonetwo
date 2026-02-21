import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // 同一DOMでの再接続時に二重送信しない
    if (this.element.dataset.submitted === "true") return

    this.element.dataset.submitted = "true"
    this.element.requestSubmit()
  }
}
