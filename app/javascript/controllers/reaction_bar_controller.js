import { Controller } from "@hotwired/stimulus"

// Progressive-enhancement controller for the reaction bar.
// The bar works without JS via full-page POST + Turbo Stream replacement.
// This controller just adds a micro pop animation on click so it feels snappy
// before the server response lands.
export default class extends Controller {
  connect() {
    this.element.addEventListener("click", this.handleClick)
  }

  disconnect() {
    this.element.removeEventListener("click", this.handleClick)
  }

  handleClick = (event) => {
    const btn = event.target.closest(".reaction-btn")
    if (!btn) return
    btn.classList.remove("reaction-btn--pop")
    // Force reflow so the animation restarts on re-click
    void btn.offsetWidth
    btn.classList.add("reaction-btn--pop")
  }
}
