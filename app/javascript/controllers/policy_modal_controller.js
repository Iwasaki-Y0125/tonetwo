import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "overlay" ]

  connect() {
    this.overlayTarget?.focus()
  }

  close() {
    const frame = document.getElementById("policy_modal")
    if (frame) frame.innerHTML = ""
  }

  closeOnBackdrop(event) {
    if (event.target === this.overlayTarget) this.close()
  }
}
