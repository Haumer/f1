import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "toggle"]

  connect() {
    this.toggleTarget.hidden = false
    this.element.classList.add("password-field--enhanced")
    this._beforeCache = () => this.hide()
    document.addEventListener("turbo:before-cache", this._beforeCache)
    this.hide()
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this._beforeCache)
    this.hide()
  }

  toggle() {
    this.setVisible(this.inputTarget.type === "password")
  }

  hide() {
    this.setVisible(false)
  }

  setVisible(visible) {
    this.inputTarget.type = visible ? "text" : "password"
    this.toggleTarget.textContent = visible ? "Hide" : "Show"
    this.toggleTarget.setAttribute("aria-pressed", String(visible))
  }
}
