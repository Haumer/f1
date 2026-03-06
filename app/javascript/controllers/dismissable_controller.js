import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { key: String }

  connect() {
    if (localStorage.getItem(this.keyValue)) {
      this.element.remove()
    }
  }

  dismiss() {
    localStorage.setItem(this.keyValue, "1")
    this.element.style.opacity = "0"
    this.element.style.maxHeight = "0"
    this.element.style.marginBottom = "0"
    this.element.style.padding = "0"
    setTimeout(() => this.element.remove(), 300)
  }
}
