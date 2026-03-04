import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["links"]

  toggleMenu() {
    this.linksTarget.classList.toggle("open")
  }

  connect() {
    // Close mobile menu on navigation
    this._turboHandler = () => this.linksTarget.classList.remove("open")
    document.addEventListener("turbo:before-visit", this._turboHandler)
  }

  disconnect() {
    document.removeEventListener("turbo:before-visit", this._turboHandler)
  }
}
