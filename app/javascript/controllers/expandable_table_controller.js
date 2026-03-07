import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]
  static values = { limit: { type: Number, default: 10 } }

  connect() {
    this.expanded = false
    this.rows = this.element.querySelectorAll("tbody tr")
    this.collapse()
  }

  toggle() {
    this.expanded = !this.expanded
    this.expanded ? this.expand() : this.collapse()
  }

  collapse() {
    this.rows.forEach((row, i) => {
      row.style.display = i < this.limitValue ? "" : "none"
    })
    if (this.hasButtonTarget) {
      this.buttonTarget.textContent = `Show all ${this.rows.length} drivers`
    }
  }

  expand() {
    this.rows.forEach(row => row.style.display = "")
    if (this.hasButtonTarget) {
      this.buttonTarget.textContent = "Show less"
    }
  }
}
