import { Controller } from "@hotwired/stimulus"

// Toggle the .flipped class on the flip wrapper. Inside a stack, clicks on a
// ghost card (.stack-back-1 / .stack-back-2) promote it to the top slot
// instead of flipping — actual flipping is only available on .stack-top.
export default class extends Controller {
  toggle(event) {
    // Ignore clicks on the stack count badge / tier breakdown chip
    if (event.target.closest(".dc-stack-count, .dc-stack-breakdown")) return

    if (this.element.classList.contains("stack-back-1") ||
        this.element.classList.contains("stack-back-2")) {
      this.promoteInStack()
      return
    }

    this.element.classList.toggle("flipped")
  }

  promoteInStack() {
    const stack = this.element.closest(".dc-stack")
    if (!stack) return
    const top = stack.querySelector(".dc-flip.stack-top")
    if (!top || top === this.element) return

    const clickedSlot = this.element.classList.contains("stack-back-1")
      ? "stack-back-1"
      : "stack-back-2"

    this.element.classList.remove(clickedSlot)
    this.element.classList.add("stack-top")
    top.classList.remove("stack-top")
    top.classList.add(clickedSlot)
    // New top starts unflipped
    this.element.classList.remove("flipped")
  }
}
