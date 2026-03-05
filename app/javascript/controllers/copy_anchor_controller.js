import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  copy(event) {
    event.preventDefault()
    const url = new URL(this.element.href, window.location.origin)
    url.search = ""
    url.pathname = window.location.pathname

    navigator.clipboard.writeText(url.toString()).then(() => {
      this.element.classList.add("copied")
      const icon = this.element.querySelector("i")
      if (icon) {
        icon.className = "fa-solid fa-check"
        setTimeout(() => {
          icon.className = "fa-solid fa-link"
          this.element.classList.remove("copied")
        }, 1500)
      }
    })
  }
}
