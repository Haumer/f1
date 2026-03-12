import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "plus", "minus", "total", "submit"]
  static values = { price: Number, max: Number }

  connect() {
    this.update()
  }

  increment(event) {
    event.preventDefault()
    if (this.qty < this.maxValue) {
      this.inputTarget.value = this.qty + 1
      this.update()
    }
  }

  decrement(event) {
    event.preventDefault()
    if (this.qty > 1) {
      this.inputTarget.value = this.qty - 1
      this.update()
    }
  }

  update() {
    const qty = this.qty
    const total = (qty * this.priceValue).toFixed(1)
    const isAll = qty === this.maxValue

    if (this.hasPlusTarget) this.plusTarget.disabled = qty >= this.maxValue
    if (this.hasMinusTarget) this.minusTarget.disabled = qty <= 1

    if (this.hasTotalTarget) {
      this.totalTarget.textContent = total
    }

    if (this.hasSubmitTarget) {
      const label = this.submitTarget.dataset.label || "Sell"
      this.submitTarget.value = isAll ? `${label} All` : `${label} ${qty}x`
      this.submitTarget.dataset.turboConfirm =
        `${label} ${qty}x ${this.submitTarget.dataset.driverName} for ${total}?`
    }

    // Sync hidden quantity input
    const hidden = this.element.querySelector("input[name='quantity']")
    if (hidden) hidden.value = qty
  }

  get qty() {
    return Math.max(1, parseInt(this.inputTarget.value) || 1)
  }
}
