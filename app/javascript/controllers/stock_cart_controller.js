import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "cartEmpty", "cartItems", "cartList", "cartTotal", "cartCount",
    "cartRemaining", "confirmBtn", "drawer", "toggle", "status", "mobileSummary", "form", "cashSpent", "margin", "sidebar"]
  static values = { cash: Number, maxPositions: Number, usedPositions: Number, portfolio: String,
    race: String, closesAt: String, open: Boolean, collateral: Number, quoteUrl: String }

  connect() {
    this.cart = []
    this.submitting = false
    this.checking = false
    this.quotes = new Map(this.cardTargets.map(card => [card.dataset.driverId, {
      id: card.dataset.driverId, name: card.dataset.driverName, price: Number(card.dataset.driverPrice),
      owned: JSON.parse(card.dataset.driverOwned || "[]")
    }]))
    // Keep these in sync with the market layout/row breakpoints in Sass.
    this.mobile = window.matchMedia("(max-width: 1199px)")
    this.compactRows = window.matchMedia("(max-width: 767px)")
    this.expanded = false
    this.onResize = () => { this.collapseTrades(); this.renderDrawer() }
    this.mobile.addEventListener("change", this.onResize)
    this.compactRows.addEventListener("change", this.onResize)
    this.restore()
    this.update()
    this.timer = setInterval(() => {
      if (this.openValue && this.isClosed) {
        this.openValue = false
        this.message("Trading has closed. Your draft was not submitted.")
        this.update()
      }
    }, 1000)
  }

  disconnect() {
    clearInterval(this.timer)
    this.mobile.removeEventListener("change", this.onResize)
    this.compactRows.removeEventListener("change", this.onResize)
    this.request?.abort()
  }

  get storageKey() { return `f1elo:stock-cart:${this.portfolioValue}` }
  get isClosed() { return !this.openValue || !this.closesAtValue || Date.now() >= Date.parse(this.closesAtValue) }
  get totals() {
    const spent = this.cart.filter(d => d.direction === "long").reduce((sum, d) => sum + d.price * d.quantity, 0)
    const margin = this.cart.filter(d => d.direction === "short").reduce((sum, d) => sum + d.price * d.quantity * this.collateralValue, 0)
    return { spent, margin, required: spent + margin, remaining: this.cashValue - spent - margin }
  }
  money(value) { return new Intl.NumberFormat(undefined, { maximumFractionDigits: 2 }).format(value) }
  message(text) { this.statusTarget.textContent = text }

  restore() {
    try {
      const draft = JSON.parse(sessionStorage.getItem(this.storageKey))
      if (!draft) return
      if (String(draft.race) !== this.raceValue || this.isClosed) {
        sessionStorage.removeItem(this.storageKey)
        return
      }
      if (!Array.isArray(draft.orders)) return
      let removed = false
      for (const order of draft.orders.slice(0, this.maxPositionsValue)) {
        const quote = this.quotes.get(String(order.id))
        if (!quote || !this.allowed(quote, order.direction) || !Number.isSafeInteger(order.quantity) || order.quantity <= 0 || this.cart.some(d => d.id === String(order.id))) {
          removed = true
          continue
        }
        this.cart.push({ ...quote, id: String(quote.id), direction: order.direction, quantity: order.quantity })
      }
      if (this.cart.length || removed) this.message(removed ? "Draft restored; unavailable trades were removed. Review before submitting." : "Draft restored. Prices will be checked before you confirm; nothing is submitted.")
    } catch { /* Storage may be unavailable or an older draft malformed. */ }
  }

  save() {
    try {
      if (!this.cart.length || this.isClosed) sessionStorage.removeItem(this.storageKey)
      else sessionStorage.setItem(this.storageKey, JSON.stringify({ race: this.raceValue,
        orders: this.cart.map(({ id, direction, quantity }) => ({ id, direction, quantity })) }))
    } catch { /* Trading still works without browser storage. */ }
  }

  allowed(quote, direction) {
    return ["long", "short"].includes(direction) && Number.isFinite(quote.price) && quote.price > 0 && !quote.owned.some(d => d !== direction)
  }

  addLong(event) { this.add(event, "long") }
  addShort(event) { this.add(event, "short") }
  add(event, direction) {
    event.preventDefault()
    if (this.isClosed) return
    const card = event.currentTarget.closest("[data-driver-id]")
    const quote = this.quotes.get(card.dataset.driverId)
    if (!quote || !this.allowed(quote, direction) || this.cart.some(d => d.id === String(quote.id))) return
    const quantity = this.compactRows.matches ? 1 : Math.max(1, Number(card.querySelector(".stock-qty-input")?.value) || 1)
    this.cart.push({ ...quote, id: String(quote.id), direction, quantity })
    if (this.compactRows.matches) this.expanded = false
    this.message(`${quote.name} added ${direction}. Review your draft to change quantity or submit.`)
    this.update()
    if (this.compactRows.matches) {
      this.collapseTrades()
      card.querySelector(".market-trade-toggle").focus({ preventScroll: true })
    }
  }

  remove(event) {
    this.cart = this.cart.filter(d => d.id !== event.currentTarget.dataset.driverId)
    this.message("Trade removed from draft.")
    this.update()
  }
  quantity(event) {
    const item = this.cart.find(d => d.id === event.currentTarget.dataset.driverId)
    if (!item) return
    const value = Number(event.currentTarget.value)
    if (!Number.isSafeInteger(value) || value < 1) {
      event.currentTarget.value = item.quantity
      this.message("Quantity must be a whole number of at least one.")
      return
    }
    item.quantity = value
    this.update(false)
  }
  clear() {
    this.cart = []
    this.message("Draft cleared. No trades submitted.")
    this.update()
  }
  toggleTrade(event) {
    const card = event.currentTarget.closest("[data-driver-id]")
    if (this.cart.some(d => d.id === card.dataset.driverId)) {
      this.expanded = true
      this.renderDrawer()
      this.drawerTarget.querySelector(`input[data-driver-id="${card.dataset.driverId}"]`)?.focus({ preventScroll: true })
      return
    }
    const expand = !card.classList.contains("trade-options-open")
    this.collapseTrades()
    card.classList.toggle("trade-options-open", expand)
    event.currentTarget.setAttribute("aria-expanded", String(expand))
  }
  collapseTrades() {
    this.cardTargets.forEach(card => {
      card.classList.remove("trade-options-open")
      card.querySelector(".market-trade-toggle")?.setAttribute("aria-expanded", "false")
    })
  }
  toggle() { this.expanded = !this.expanded; this.renderDrawer() }
  close(event) {
    if (event.key === "Escape" && this.compactRows.matches) {
      const card = this.element.querySelector(".trade-options-open")
      if (card) { this.collapseTrades(); card.querySelector(".market-trade-toggle").focus(); return }
    }
    if (event.key !== "Escape" || !this.mobile.matches || !this.expanded) return
    this.expanded = false
    this.renderDrawer()
    this.toggleTarget.focus()
  }
  renderDrawer() {
    const hadFocus = this.sidebarTarget.contains(document.activeElement)
    const empty = !this.cart.length
    if (empty) this.expanded = false
    this.sidebarTarget.hidden = this.mobile.matches && empty
    this.element.classList.toggle("has-trade-draft", !empty)
    const visible = !this.mobile.matches || this.expanded
    this.drawerTarget.hidden = !visible
    this.toggleTarget.setAttribute("aria-expanded", String(visible))
    this.cardTargets.filter(card => card.classList.contains("in-cart")).forEach(card => {
      card.querySelector(".market-trade-toggle")?.setAttribute("aria-expanded", String(visible))
    })
    this.toggleTarget.querySelector(".cart-review-label").textContent = this.expanded ? "Close" : "Review"
    if (this.sidebarTarget.hidden && hadFocus) this.focusTradeButton()
  }
  focusTradeButton() {
    const selector = this.compactRows.matches ? ".market-trade-toggle" : ".stock-trade-btn:not(:disabled)"
    this.element.querySelector(selector)?.focus({ preventScroll: true })
  }

  async confirm(event) {
    event.preventDefault()
    if (this.checking || !this.cart.length || this.isClosed) return
    this.checking = true
    this.update(false)
    this.message("Checking current prices and availability…")
    try {
      this.request = new AbortController()
      const response = await fetch(this.quoteUrlValue, { headers: { Accept: "application/json" }, cache: "no-store", signal: this.request.signal })
      if (!response.ok || !response.headers.get("content-type")?.includes("application/json")) throw new Error("quote unavailable")
      const quote = await response.json()
      quote.drivers.forEach(driver => { driver.price = Number(driver.price) })
      this.openValue = quote.can_trade && String(quote.race_id) === this.raceValue
      this.closesAtValue = quote.closes_at || ""
      this.cashValue = Number(quote.cash)
      this.usedPositionsValue = quote.used_positions
      this.quotes = new Map(quote.drivers.map(d => [String(d.id), d]))
      const previousCount = this.cart.length
      this.cart = this.cart.filter(d => {
        const current = this.quotes.get(d.id)
        if (!current || !this.allowed(current, d.direction)) return false
        Object.assign(d, current, { id: String(current.id) })
        return true
      })
      this.update()
      if (this.isClosed) { this.message("Trading has closed. No trades were submitted."); return }
      if (previousCount !== this.cart.length) { this.message("Some trades are no longer available. Review your updated draft."); return }
      if (!this.valid) { this.message(this.validationMessage); return }

      const totals = this.totals
      const summary = this.cart.map(d => `${d.quantity} × ${d.name} — ${d.direction}, ${this.money(d.price)} per share`).join("\n")
      const result = await window.Swal.fire({
        title: "Review trades", text: `${summary}\nSpend: ${this.money(totals.spent)} credits · Reserve as margin: ${this.money(totals.margin)}\nAvailable after: ${this.money(totals.remaining)}`,
        icon: "question", showCancelButton: true, confirmButtonText: "Execute trades", cancelButtonText: "Keep editing",
        background: getComputedStyle(this.drawerTarget).backgroundColor, color: getComputedStyle(this.element).color,
        confirmButtonColor: getComputedStyle(document.body).getPropertyValue("--page-accent").trim() || "#e10600"
      })
      if (result.isConfirmed && !this.isClosed) {
        // POST checks quoted prices again. Only success clears the draft.
        this.submitting = true
        this.formTarget.requestSubmit()
      } else this.message("Draft kept. No trades submitted.")
    } catch (error) {
      if (error.name !== "AbortError") this.message("Could not check current prices. Your draft is safe; try again.")
    } finally {
      this.checking = false
      if (this.element.isConnected) this.update(false)
    }
  }

  get validationMessage() {
    if (this.isClosed) return "Market closed. No trades can be submitted."
    if (this.totals.remaining < -0.000001) return "Not enough available credits. Reduce quantity or remove a trade."
    const newPositions = this.cart.filter(d => !d.owned.includes(d.direction)).length
    if (this.usedPositionsValue + newPositions > this.maxPositionsValue) return `Maximum ${this.maxPositionsValue} positions. Reduce your draft.`
    return ""
  }
  get valid() { return this.cart.length > 0 && !this.validationMessage }

  update(renderItems = true) {
    // Capture focus before replacing/removing the last focused cart item.
    const returnFocus = this.mobile.matches && !this.cart.length && this.sidebarTarget.contains(document.activeElement)
    const totals = this.totals
    this.cartEmptyTarget.hidden = this.cart.length > 0
    this.cartItemsTarget.hidden = this.cart.length === 0
    if (renderItems) {
      this.cartListTarget.replaceChildren(...this.cart.map(d => {
        // Never interpret stored/quoted names as HTML.
        const row = document.createElement("div")
        row.className = "fantasy-cart-item"
        const name = document.createElement("span")
        name.className = "fantasy-cart-item-name"
        name.textContent = `${d.name} · ${d.direction === "long" ? "Long" : "Short"}`
        const label = document.createElement("label")
        label.textContent = "Quantity"
        const input = document.createElement("input")
        Object.assign(input, { type: "number", min: "1", step: "1", value: d.quantity, inputMode: "numeric" })
        input.dataset.driverId = d.id
        input.dataset.action = "change->stock-cart#quantity"
        input.setAttribute("aria-label", `Quantity for ${d.name}`)
        label.append(input)
        const remove = document.createElement("button")
        Object.assign(remove, { type: "button", textContent: "Remove", className: "fantasy-cart-remove" })
        remove.dataset.driverId = d.id
        remove.dataset.action = "click->stock-cart#remove"
        remove.setAttribute("aria-label", `Remove ${d.name}`)
        row.append(name, label, remove)
        return row
      }))
    }
    this.cartTotalTarget.textContent = this.money(totals.required)
    this.cashSpentTarget.textContent = this.money(totals.spent)
    this.marginTarget.textContent = this.money(totals.margin)
    this.cartRemainingTarget.textContent = this.money(totals.remaining)
    this.cartCountTarget.textContent = this.cart.length
    this.mobileSummaryTarget.textContent = this.cart.length ? `${this.cart.length} trade${this.cart.length === 1 ? "" : "s"} · ${this.money(totals.required)} credits` : "No trades selected"
    this.confirmBtnTarget.disabled = !this.valid || this.checking || this.submitting
    this.element.querySelector(".fantasy-cart-validation").textContent = this.validationMessage
    this.formTarget.querySelectorAll("input[name^='orders']").forEach(el => el.remove())
    this.cart.forEach(d => {
      Object.entries({ driver_id: d.id, direction: d.direction, quantity: d.quantity, quoted_price: d.price }).forEach(([key, value]) => {
        const input = document.createElement("input")
        Object.assign(input, { type: "hidden", name: `orders[][${key}]`, value })
        this.formTarget.append(input)
      })
    })
    this.cardTargets.forEach(card => {
      const inCart = this.cart.some(d => d.id === card.dataset.driverId)
      card.classList.toggle("in-cart", inCart)
      const toggle = card.querySelector(".market-trade-toggle")
      if (toggle) {
        toggle.textContent = inCart ? "In draft" : "Trade"
        toggle.setAttribute("aria-label", `${inCart ? "Review trade for" : "Trade"} ${card.dataset.driverName}`)
        toggle.setAttribute("aria-controls", inCart ? "trade-draft" : `trade-options-${card.dataset.driverId}`)
      }
      card.querySelectorAll(".stock-trade-btn").forEach(button => {
        const quote = this.quotes.get(card.dataset.driverId)
        const quantity = this.compactRows.matches ? 1 : Math.max(1, Number(card.querySelector(".stock-qty-input")?.value) || 1)
        const cost = (quote?.price || 0) * quantity * (button.dataset.tradeDirection === "short" ? this.collateralValue : 1)
        button.disabled = inCart || this.isClosed || button.classList.contains("slot-hidden") || cost > this.cashValue
      })
    })
    this.save()
    this.renderDrawer()
    if (returnFocus) this.focusTradeButton()
  }
}
