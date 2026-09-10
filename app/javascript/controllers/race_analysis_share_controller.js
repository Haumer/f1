import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["url", "native", "status"]
  static values = { title: String, text: String }

  connect() {
    this.nativeTarget.hidden = typeof navigator.share !== "function"
  }

  select() {
    this.urlTarget.focus()
    this.urlTarget.select()
  }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.urlTarget.value)
      this.statusTarget.textContent = "Link copied."
    } catch {
      this.select()
      this.statusTarget.textContent = "Copy isn't available here. The link is selected—copy it manually."
    }
  }

  async share() {
    try {
      await navigator.share({ title: this.titleValue, text: this.textValue, url: this.urlTarget.value })
    } catch (error) {
      if (error.name !== "AbortError") await this.copy()
    }
  }
}
