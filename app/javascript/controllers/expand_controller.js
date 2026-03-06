import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "label", "trigger"]

  toggle() {
    const hidden = this.contentTargets[0]?.style.display === "none"
    this.contentTargets.forEach(el => el.style.display = hidden ? "" : "none")
    if (this.hasLabelTarget) {
      const showText = this.labelTarget.dataset.showText
      this.labelTarget.textContent = hidden ? "Show less" : showText
    }
  }
}
