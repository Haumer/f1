import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle"]

  connect() {
    this.element.classList.add("result-details-enhanced")
    this.toggleTargets.forEach(button => { button.hidden = false })
  }

  toggle(event) {
    const button = event.currentTarget
    const row = document.getElementById(button.getAttribute("aria-controls"))
    if (!row || !this.element.contains(row)) return
    row.hidden = !row.hidden
    button.setAttribute("aria-expanded", String(!row.hidden))
  }
}
