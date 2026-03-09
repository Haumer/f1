import { Controller } from "@hotwired/stimulus"

// Unified cart for the combined roster + stock market page.
// Handles both roster driver additions and stock long/short orders in one cart.
export default class extends Controller {
  static targets = ["card", "cartEmpty", "cartItems", "cartList",
                     "cartCount", "confirmBtn",
                     "totalCost", "cashRemaining"]
  static values = {
    cash: Number, collateral: Number,                       // unified cash pool
    slots: Number, filled: Number,                          // roster
    stockMax: Number, stockUsed: Number,                    // stocks
    hasStocks: Boolean
  }

  connect() {
    this.rosterCart = []  // [{ id, name, price, cardEl }]
    this.stockCart = []   // [{ id, name, price, direction, quantity, cardEl }]
    this.update()
  }

  // ─── Roster actions ───

  addRoster(event) {
    event.preventDefault()
    const card = event.target.closest("[data-driver-id]")
    if (!card) return

    const id = card.dataset.driverId
    if (this.rosterCart.find(d => d.id === id)) return
    if (this.filledValue + this.rosterCart.length >= this.slotsValue) return

    const name = card.dataset.driverName
    const price = parseFloat(card.dataset.driverPrice)

    this.rosterCart.push({ id, name, price, cardEl: card })
    card.classList.add("in-cart")
    this.update()
  }

  // ─── Stock actions ───

  addLong(event) {
    event.preventDefault()
    this._addStock(event, "long")
  }

  addShort(event) {
    event.preventDefault()
    this._addStock(event, "short")
  }

  _addStock(event, direction) {
    const card = event.target.closest("[data-driver-id]")
    if (!card) return

    const id = card.dataset.driverId
    if (this.stockCart.find(d => d.id === id)) return

    const name = card.dataset.driverName
    const price = parseFloat(card.dataset.stockPrice)
    const qtyInput = card.querySelector(".stock-qty-input")
    const quantity = qtyInput ? Math.max(1, parseInt(qtyInput.value) || 1) : 1

    this.stockCart.push({ id, name, price, direction, quantity, cardEl: card })
    card.classList.add("in-cart")
    this.update()
  }

  // ─── Common actions ───

  remove(event) {
    event.preventDefault()
    const id = event.currentTarget.dataset.driverId
    const type = event.currentTarget.dataset.cartType

    if (type === "roster") {
      const idx = this.rosterCart.findIndex(d => d.id === id)
      if (idx !== -1) {
        this.rosterCart[idx].cardEl.classList.remove("in-cart")
        this.rosterCart.splice(idx, 1)
      }
    } else {
      const idx = this.stockCart.findIndex(d => d.id === id)
      if (idx !== -1) {
        this.stockCart[idx].cardEl.classList.remove("in-cart")
        this.stockCart.splice(idx, 1)
      }
    }
    this.update()
  }

  clear(event) {
    event.preventDefault()
    this.rosterCart.forEach(item => item.cardEl.classList.remove("in-cart"))
    this.stockCart.forEach(item => item.cardEl.classList.remove("in-cart"))
    this.rosterCart = []
    this.stockCart = []
    this.update()
  }

  confirm(event) {
    const total = this.rosterCart.length + this.stockCart.length
    if (total === 0) { event.preventDefault(); return }

    event.preventDefault()
    const parts = []
    if (this.rosterCart.length > 0) {
      parts.push("Roster: " + this.rosterCart.map(d => d.name).join(", "))
    }
    if (this.stockCart.length > 0) {
      parts.push("Stocks: " + this.stockCart.map(d => `${d.quantity}x ${d.name} (${d.direction})`).join(", "))
    }

    const form = this.confirmBtnTarget.closest("form")

    window.Swal.fire({
      text: parts.join("\n"),
      icon: "question",
      showCancelButton: true,
      confirmButtonText: "Confirm Trades",
      cancelButtonText: "Cancel",
      background: "#1a1a1a",
      color: "#e0e0e0",
      confirmButtonColor: "#e10600",
      cancelButtonColor: "#333",
    }).then((result) => {
      if (result.isConfirmed && form) form.requestSubmit()
    })
  }

  // ─── Update UI ───

  update() {
    const rosterCost = this.rosterCart.reduce((s, d) => s + d.price, 0)
    const stockCost = this.stockCart.reduce((s, d) => s + d.price * d.quantity, 0)
    const totalCost = rosterCost + stockCost
    const availableCash = this.cashValue - this.collateralValue
    const remaining = availableCash - totalCost
    const totalItems = this.rosterCart.length + this.stockCart.length
    const hasItems = totalItems > 0
    const slotsLeft = this.slotsValue - this.filledValue - this.rosterCart.length

    // Toggle empty/items
    if (this.hasCartEmptyTarget) this.cartEmptyTarget.style.display = hasItems ? "none" : ""
    if (this.hasCartItemsTarget) this.cartItemsTarget.style.display = hasItems ? "" : "none"

    // Build cart list
    if (this.hasCartListTarget) {
      let html = ""

      if (this.rosterCart.length > 0) {
        html += '<div class="fantasy-cart-section-label">Roster</div>'
        html += this.rosterCart.map(d =>
          `<div class="fantasy-cart-item">
            <span class="fantasy-cart-item-name">${d.name}</span>
            <span class="fantasy-cart-item-price">${Math.round(d.price)}</span>
            <button class="fantasy-cart-remove" data-action="click->unified-cart#remove" data-driver-id="${d.id}" data-cart-type="roster">
              <i class="fa-solid fa-xmark"></i>
            </button>
          </div>`
        ).join("")
      }

      if (this.stockCart.length > 0) {
        html += '<div class="fantasy-cart-section-label">Stocks</div>'
        html += this.stockCart.map(d => {
          const dirClass = d.direction === "long" ? "stock-long" : "stock-short"
          const dirIcon = d.direction === "long" ? "arrow-trend-up" : "arrow-trend-down"
          const cost = Math.round(d.price * d.quantity)
          return `<div class="fantasy-cart-item">
            <span class="stock-direction-badge ${dirClass}" style="font-size:10px; padding:1px 5px;">
              <i class="fa-solid fa-${dirIcon}" style="font-size:8px"></i>
            </span>
            <span class="fantasy-cart-item-name">${d.quantity}x ${d.name}</span>
            <span class="fantasy-cart-item-price">${cost}</span>
            <button class="fantasy-cart-remove" data-action="click->unified-cart#remove" data-driver-id="${d.id}" data-cart-type="stock">
              <i class="fa-solid fa-xmark"></i>
            </button>
          </div>`
        }).join("")
      }

      this.cartListTarget.innerHTML = html
    }

    // Totals
    if (this.hasTotalCostTarget) this.totalCostTarget.textContent = Math.round(totalCost)
    if (this.hasCashRemainingTarget) {
      this.cashRemainingTarget.textContent = Math.round(remaining)
      this.cashRemainingTarget.classList.toggle("text-red", remaining < 0)
      this.cashRemainingTarget.classList.toggle("text-green", remaining >= 0)
    }
    if (this.hasCartCountTarget) this.cartCountTarget.textContent = totalItems

    // Hidden inputs for unified_trade form
    if (this.hasConfirmBtnTarget) {
      const form = this.confirmBtnTarget.closest("form")
      if (form) {
        form.querySelectorAll("input[name='roster_driver_ids[]'], input[name^='stock_orders']").forEach(el => el.remove())

        this.rosterCart.forEach(d => {
          const input = document.createElement("input")
          input.type = "hidden"
          input.name = "roster_driver_ids[]"
          input.value = d.id
          form.appendChild(input)
        })

        this.stockCart.forEach((d, i) => {
          this._addHidden(form, `stock_orders[][driver_id]`, d.id)
          this._addHidden(form, `stock_orders[][direction]`, d.direction)
          this._addHidden(form, `stock_orders[][quantity]`, d.quantity)
        })
      }

      const valid = hasItems && remaining >= 0
      this.confirmBtnTarget.disabled = !valid
    }

    // Update roster add button availability
    this.cardTargets.forEach(card => {
      const actionArea = card.querySelector(".fantasy-market-actions")
      if (!actionArea) return

      const driverId = card.dataset.driverId
      const price = parseFloat(card.dataset.driverPrice)
      const onRoster = card.classList.contains("on-roster")
      const inCart = !!this.rosterCart.find(d => d.id === driverId)

      if (onRoster || inCart) return

      const addBtn = actionArea.querySelector("[data-action*='unified-cart#addRoster']")
      const reason = actionArea.querySelector(".fantasy-cart-reason")

      if (slotsLeft <= 0) {
        if (addBtn) addBtn.style.display = "none"
        this._setReason(actionArea, reason, "Full")
      } else if (remaining < price) {
        if (addBtn) addBtn.style.display = "none"
        this._setReason(actionArea, reason, "Low funds")
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
    const btn = container.querySelector("[data-action*='unified-cart#addRoster']")
    if (btn) btn.style.display = "none"
  }

  _addHidden(form, name, value) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = name
    input.value = value
    form.appendChild(input)
  }
}
