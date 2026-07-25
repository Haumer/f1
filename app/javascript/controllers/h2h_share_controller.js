import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  copy(event) {
    event.preventDefault()
    navigator.clipboard.writeText(this.urlValue).then(() => {
      this.element.classList.add("copied")
      const label = this.element.querySelector(".h2h-share-label")
      const original = label ? label.textContent : null
      if (label) label.textContent = "Copied!"
      setTimeout(() => {
        this.element.classList.remove("copied")
        if (label && original) label.textContent = original
      }, 1500)
    })
  }
}
