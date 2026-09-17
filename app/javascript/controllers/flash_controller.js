import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { clearedCart: String, clearedPicks: String }

  connect() {
    if (this.clearedPicksValue) {
      try { sessionStorage.removeItem(this.clearedPicksValue) } catch {}
      this.clearedPicksValue = ""
    }
    if (this.clearedCartValue) {
      try { sessionStorage.removeItem(`f1elo:stock-cart:${this.clearedCartValue}`) } catch {}
      // Don't let a cached success notice delete a later, unrelated draft.
      this.clearedCartValue = ""
    }
    this.timeout = setTimeout(() => this.dismiss(), 7000)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.style.opacity = "0"
    this.element.style.transform = "translateX(20px)"
    setTimeout(() => this.element.remove(), 300)
  }
}
