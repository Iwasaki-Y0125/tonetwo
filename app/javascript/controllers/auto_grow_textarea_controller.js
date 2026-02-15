import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field"]

  connect() {
    this.resize()
  }

  resize() {
    if (!this.hasFieldTarget) return

    const field = this.fieldTarget
    field.style.height = "auto"
    field.style.height = `${field.scrollHeight}px`
  }
}
