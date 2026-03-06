import { Controller } from "@hotwired/stimulus"

// Client-side cart for the stock market.
// Collects long/short orders with quantities before batch submission.
export default class extends Controller {
  static targets = ["card", "cartEmpty", "cartItems", "cartList",
                     "cartTotal", "cartCount", "cartRemaining", "confirmBtn"]
  static values = { cash: Number, maxPositions: Number, usedPositions: Number }

  connect() {
    this.cart = [] // [{ id, name, price, direction, quantity, cardEl }]
    this.update()
  }

  addLong(event) {
    event.preventDefault()
    this._addFromRow(event, "long")
  }

  addShort(event) {
    event.preventDefault()
    this._addFromRow(event, "short")
  }

  _addFromRow(event, direction) {
    const card = event.target.closest("[data-driver-id]")
    if (!card) return

    const id = card.dataset.driverId
    // Don't add duplicates
    if (this.cart.find(d => d.id === id)) return

    const name = card.dataset.driverName
    const price = parseFloat(card.dataset.driverPrice)
    const qtyInput = card.querySelector(".stock-qty-input")
    const quantity = qtyInput ? Math.max(1, parseInt(qtyInput.value) || 1) : 1

    this.cart.push({ id, name, price, direction, quantity, cardEl: card })
    card.classList.add("in-cart")
    this.update()
  }

  remove(event) {
    event.preventDefault()
    const id = event.currentTarget.dataset.driverId
    const idx = this.cart.findIndex(d => d.id === id)
    if (idx === -1) return

    this.cart[idx].cardEl.classList.remove("in-cart")
    this.cart.splice(idx, 1)
    this.update()
  }

  clear(event) {
    event.preventDefault()
    this.cart.forEach(item => item.cardEl.classList.remove("in-cart"))
    this.cart = []
    this.update()
  }

  confirm(event) {
    if (this.cart.length === 0) { event.preventDefault(); return }

    event.preventDefault()
    const summary = this.cart.map(d => `${d.quantity}x ${d.name} (${d.direction})`).join(", ")
    const total = this.cart.reduce((s, d) => s + d.price * d.quantity, 0)
    const form = this.confirmBtnTarget.closest("form")

    window.Swal.fire({
      text: `Execute trades: ${summary}\nTotal cost: ${Math.round(total)}`,
      icon: "question",
      showCancelButton: true,
      confirmButtonText: "Execute Trades",
      cancelButtonText: "Cancel",
      background: "#1a1a1a",
      color: "#e0e0e0",
      confirmButtonColor: "#e10600",
      cancelButtonColor: "#333",
    }).then((result) => {
      if (result.isConfirmed && form) form.requestSubmit()
    })
  }

  update() {
    const total = this.cart.reduce((s, d) => s + d.price * d.quantity, 0)
    const remaining = this.cashValue - total
    const newPositions = this.cart.length
    const positionsLeft = this.maxPositionsValue - this.usedPositionsValue - newPositions
    const hasItems = this.cart.length > 0

    // Toggle empty/items
    if (this.hasCartEmptyTarget) this.cartEmptyTarget.style.display = hasItems ? "none" : ""
    if (this.hasCartItemsTarget) this.cartItemsTarget.style.display = hasItems ? "" : "none"

    // Cart list
    if (this.hasCartListTarget) {
      this.cartListTarget.innerHTML = this.cart.map(d => {
        const dirClass = d.direction === "long" ? "stock-long" : "stock-short"
        const dirIcon = d.direction === "long" ? "arrow-trend-up" : "arrow-trend-down"
        const cost = Math.round(d.price * d.quantity)
        return `<div class="fantasy-cart-item">
          <span class="stock-direction-badge ${dirClass}" style="font-size:10px; padding:1px 5px;">
            <i class="fa-solid fa-${dirIcon}" style="font-size:8px"></i> ${d.direction.toUpperCase()}
          </span>
          <span class="fantasy-cart-item-name">${d.quantity}x ${d.name}</span>
          <span class="fantasy-cart-item-price">${cost}</span>
          <button class="fantasy-cart-remove" data-action="click->stock-cart#remove" data-driver-id="${d.id}">
            <i class="fa-solid fa-xmark"></i>
          </button>
        </div>`
      }).join("")
    }

    // Totals
    if (this.hasCartTotalTarget) this.cartTotalTarget.textContent = Math.round(total)
    if (this.hasCartRemainingTarget) {
      this.cartRemainingTarget.textContent = Math.round(remaining)
      this.cartRemainingTarget.classList.toggle("text-red", remaining < 0)
      this.cartRemainingTarget.classList.toggle("text-green", remaining >= 0)
    }
    if (this.hasCartCountTarget) this.cartCountTarget.textContent = this.cart.length

    // Hidden inputs for batch form
    if (this.hasConfirmBtnTarget) {
      const form = this.confirmBtnTarget.closest("form")
      if (form) {
        form.querySelectorAll("[name^='orders']").forEach(el => el.remove())
        this.cart.forEach((d, i) => {
          this._addHidden(form, `orders[][driver_id]`, d.id)
          this._addHidden(form, `orders[][direction]`, d.direction)
          this._addHidden(form, `orders[][quantity]`, d.quantity)
        })
      }
      this.confirmBtnTarget.disabled = !hasItems || remaining < 0
    }

    // Update row availability
    this.cardTargets.forEach(card => {
      const driverId = card.dataset.driverId
      const inCart = !!this.cart.find(d => d.id === driverId)
      const tradeArea = card.querySelector(".stock-trade-actions")
      const cartIndicator = card.querySelector(".stock-in-cart-badge")

      if (inCart) {
        if (tradeArea) tradeArea.style.display = "none"
        if (!cartIndicator) {
          const td = card.querySelector("td:last-child")
          if (td) {
            const badge = document.createElement("span")
            badge.className = "stock-in-cart-badge fantasy-badge-on-roster"
            badge.innerHTML = '<i class="fa-solid fa-cart-shopping"></i>'
            td.appendChild(badge)
          }
        }
      } else {
        if (tradeArea) tradeArea.style.display = ""
        if (cartIndicator) cartIndicator.remove()
      }
    })
  }

  _addHidden(form, name, value) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = name
    input.value = value
    form.appendChild(input)
  }
}
