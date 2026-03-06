import { Controller } from "@hotwired/stimulus"

// Client-side shopping cart for the fantasy driver market.
// Lets users add/remove drivers to preview pairings and remaining cash
// before committing any purchases.
export default class extends Controller {
  static targets = ["card", "cartPanel", "cartEmpty", "cartItems", "cartList",
                     "cartTotal", "cartRemaining", "cartCount", "confirmBtn", "slotsLeft"]
  static values = { cash: Number, slots: Number, filled: Number }

  connect() {
    this.cart = [] // [{ id, name, price, cardEl }]
    this.update()
  }

  add(event) {
    event.preventDefault()
    const card = event.target.closest("[data-driver-id]")
    if (!card) return

    const id = card.dataset.driverId
    if (this.cart.find(d => d.id === id)) return
    if (this.filledValue + this.cart.length >= this.slotsValue) return

    const name = card.dataset.driverName
    const price = parseFloat(card.dataset.driverPrice)

    this.cart.push({ id, name, price, cardEl: card })
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
    const names = this.cart.map(d => d.name).join(", ")
    const total = this.cart.reduce((s, d) => s + d.price, 0)
    const form = this.confirmBtnTarget.closest("form")

    window.Swal.fire({
      text: `Buy ${names} for ${Math.round(total)} total?`,
      icon: "question",
      showCancelButton: true,
      confirmButtonText: "Buy Drivers",
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
    const total = this.cart.reduce((s, d) => s + d.price, 0)
    const remaining = this.cashValue - total
    const slotsLeft = this.slotsValue - this.filledValue - this.cart.length
    const hasItems = this.cart.length > 0

    // Toggle empty / items view
    if (this.hasCartEmptyTarget) this.cartEmptyTarget.style.display = hasItems ? "none" : ""
    if (this.hasCartItemsTarget) this.cartItemsTarget.style.display = hasItems ? "" : "none"

    // Cart list
    if (this.hasCartListTarget) {
      this.cartListTarget.innerHTML = this.cart.map(d =>
        `<div class="fantasy-cart-item">
          <span class="fantasy-cart-item-name">${d.name}</span>
          <span class="fantasy-cart-item-price">${Math.round(d.price)}</span>
          <button class="fantasy-cart-remove" data-action="click->fantasy-cart#remove" data-driver-id="${d.id}">
            <i class="fa-solid fa-xmark"></i>
          </button>
        </div>`
      ).join("")
    }

    // Totals
    if (this.hasCartTotalTarget) this.cartTotalTarget.textContent = Math.round(total)
    if (this.hasCartRemainingTarget) {
      this.cartRemainingTarget.textContent = Math.round(remaining)
      this.cartRemainingTarget.classList.toggle("text-red", remaining < 0)
      this.cartRemainingTarget.classList.toggle("text-green", remaining >= 0)
    }
    if (this.hasCartCountTarget) this.cartCountTarget.textContent = this.cart.length
    if (this.hasSlotsLeftTarget) this.slotsLeftTarget.textContent = slotsLeft

    // Hidden inputs for confirm form
    if (this.hasConfirmBtnTarget) {
      const form = this.confirmBtnTarget.closest("form")
      if (form) {
        form.querySelectorAll("input[name='driver_ids[]']").forEach(el => el.remove())
        this.cart.forEach(d => {
          const input = document.createElement("input")
          input.type = "hidden"
          input.name = "driver_ids[]"
          input.value = d.id
          form.appendChild(input)
        })
      }
      this.confirmBtnTarget.disabled = !hasItems || remaining < 0
    }

    // Update every card's action area based on cart state
    this.cardTargets.forEach(card => {
      const actionArea = card.querySelector(".fantasy-market-actions")
      if (!actionArea) return

      const driverId = card.dataset.driverId
      const price = parseFloat(card.dataset.driverPrice)
      const onRoster = card.classList.contains("on-roster")
      const inCart = !!this.cart.find(d => d.id === driverId)

      if (onRoster || inCart) return // don't touch these

      const addBtn = actionArea.querySelector("[data-action*='fantasy-cart#add']")
      const reason = actionArea.querySelector(".fantasy-cart-reason")

      if (slotsLeft <= 0) {
        if (addBtn) addBtn.style.display = "none"
        this._setReason(actionArea, reason, "Roster full")
      } else if (remaining < price) {
        if (addBtn) addBtn.style.display = "none"
        this._setReason(actionArea, reason, "Insufficient funds")
      } else {
        if (addBtn) { addBtn.style.display = ""; addBtn.disabled = false }
        if (reason) reason.remove()
      }
    })
  }

  _setReason(container, existing, text) {
    if (existing) {
      existing.textContent = text
    } else {
      const span = document.createElement("span")
      span.className = "fantasy-cart-reason"
      span.textContent = text
      container.appendChild(span)
    }
    // Hide the add button
    const btn = container.querySelector("[data-action*='fantasy-cart#add']")
    if (btn) btn.style.display = "none"
  }
}
