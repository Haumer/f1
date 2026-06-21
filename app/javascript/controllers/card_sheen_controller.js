import { Controller } from "@hotwired/stimulus"

// Per-card random animation-delay so the frame sheen on adjacent cards doesn't
// catch light at the same moment. Stimulus-driven so it runs every time a card
// connects (e.g. after a Turbo navigation).
export default class extends Controller {
  connect() {
    const card = this.element
    const dur = parseFloat(getComputedStyle(card).animationDuration) || 0
    if (!dur) return
    card.style.animationDelay = `-${(Math.random() * dur).toFixed(2)}s`
  }
}
