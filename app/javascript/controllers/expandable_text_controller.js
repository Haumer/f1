import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["body", "button"]
  static values = { collapsed: { type: Boolean, default: true } }

  connect() {
    this.update()
  }

  toggle() {
    this.collapsedValue = !this.collapsedValue
    this.update()
  }

  update() {
    if (this.collapsedValue) {
      this.bodyTarget.style.maxHeight = "200px"
      this.bodyTarget.style.overflow = "hidden"
      this.buttonTarget.textContent = "Read full analysis"
    } else {
      this.bodyTarget.style.maxHeight = "none"
      this.bodyTarget.style.overflow = "visible"
      this.buttonTarget.textContent = "Show less"
    }
  }
}
