import { Controller } from "@hotwired/stimulus"

// Intercepts a card click, plays a short win/lose animation on both cards,
// then submits the clicked card's form. Respects prefers-reduced-motion.
export default class extends Controller {
  connect() {
    this.locked = false
  }

  choose(event) {
    const card = event.target.closest(".h2h-card")
    if (!card || this.locked) return

    const form = card.closest("form.h2h-card-form")
    if (!form) return

    event.preventDefault()
    this.locked = true

    const other = this.pickOther(card)
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    const submit = () => form.requestSubmit()

    if (reduced) return submit()

    card.classList.add("h2h-picked")
    if (other) other.classList.add("h2h-eliminated")

    // Match the longest keyframe duration below (loser flip = 480ms).
    setTimeout(submit, 480)
  }

  pickOther(card) {
    const all = Array.from(this.element.querySelectorAll(".h2h-card"))
    return all.find((c) => c !== card)
  }
}
