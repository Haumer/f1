import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Scroll to the current/next race week
    const target = this.element.querySelector("[data-cal-focus]")
    if (target) {
      // Small delay to ensure layout is ready
      requestAnimationFrame(() => {
        target.scrollIntoView({ behavior: "smooth", block: "center" })
      })
    }
  }
}
