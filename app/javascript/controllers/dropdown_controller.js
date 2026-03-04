import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dropdown"
export default class extends Controller {
  static targets = ["menu", "trigger"]

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    const isOpen = this.menuTarget.classList.contains("open")

    // Close all other dropdowns first
    document.querySelectorAll(".nav-dropdown-menu.open").forEach(menu => {
      if (menu !== this.menuTarget) {
        menu.classList.remove("open")
        menu.closest("[data-controller='dropdown']")
            ?.querySelector("[aria-expanded]")
            ?.setAttribute("aria-expanded", "false")
      }
    })

    this.menuTarget.classList.toggle("open", !isOpen)
    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute("aria-expanded", String(!isOpen))
    }

    // Focus first menu item when opening
    if (!isOpen) {
      const firstItem = this.menuTarget.querySelector("a")
      if (firstItem) firstItem.focus()
    }
  }

  keydown(event) {
    const isOpen = this.menuTarget.classList.contains("open")

    if (event.key === "Escape") {
      this.close()
      if (this.hasTriggerTarget) this.triggerTarget.focus()
    } else if (event.key === "ArrowDown" || event.key === "Enter" || event.key === " ") {
      if (!isOpen) {
        event.preventDefault()
        this.toggle(event)
      }
    }
  }

  close() {
    this.menuTarget.classList.remove("open")
    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute("aria-expanded", "false")
    }
  }

  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  connect() {
    this._outsideClickHandler = this.closeOnClickOutside.bind(this)
    this._turboHandler = this.close.bind(this)
    this._keydownHandler = this._handleMenuKeydown.bind(this)
    document.addEventListener("click", this._outsideClickHandler)
    document.addEventListener("turbo:before-visit", this._turboHandler)
    this.menuTarget.addEventListener("keydown", this._keydownHandler)
  }

  disconnect() {
    document.removeEventListener("click", this._outsideClickHandler)
    document.removeEventListener("turbo:before-visit", this._turboHandler)
    this.menuTarget.removeEventListener("keydown", this._keydownHandler)
  }

  _handleMenuKeydown(event) {
    const items = [...this.menuTarget.querySelectorAll("a")]
    const index = items.indexOf(document.activeElement)

    if (event.key === "ArrowDown") {
      event.preventDefault()
      const next = index < items.length - 1 ? index + 1 : 0
      items[next]?.focus()
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      const prev = index > 0 ? index - 1 : items.length - 1
      items[prev]?.focus()
    } else if (event.key === "Escape") {
      this.close()
      if (this.hasTriggerTarget) this.triggerTarget.focus()
    }
  }
}
