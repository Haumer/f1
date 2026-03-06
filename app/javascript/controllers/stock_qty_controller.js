import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "plus", "minus", "cost", "buyBtn", "shortBtn"]
  static values = { price: Number, max: Number, canLong: Boolean, canShort: Boolean }

  connect() {
    this.update()
  }

  increment(event) {
    event.preventDefault()
    const val = this.qty
    if (val < this.maxValue) {
      this.inputTarget.value = val + 1
      this.update()
    }
  }

  decrement(event) {
    event.preventDefault()
    const val = this.qty
    if (val > 1) {
      this.inputTarget.value = val - 1
      this.update()
    }
  }

  update() {
    const qty = this.qty
    const total = qty * this.priceValue
    const affordable = qty <= this.maxValue

    // Cost preview
    if (this.hasCostTarget) {
      this.costTarget.textContent = `= ${total.toFixed(1)}`
      this.costTarget.classList.toggle("text-red", !affordable)
    }

    // Stepper buttons
    if (this.hasPlusTarget) {
      this.plusTarget.disabled = qty >= this.maxValue
    }
    if (this.hasMinusTarget) {
      this.minusTarget.disabled = qty <= 1
    }

    // Trade buttons
    if (this.hasBuyBtnTarget) {
      this.buyBtnTarget.disabled = !this.canLongValue || !affordable
    }
    if (this.hasShortBtnTarget) {
      this.shortBtnTarget.disabled = !this.canShortValue || !affordable
    }

    // Sync hidden inputs
    this.element.querySelectorAll("input[name='quantity']").forEach(el => {
      el.value = qty
    })
  }

  get qty() {
    return Math.max(1, parseInt(this.inputTarget.value) || 1)
  }
}
