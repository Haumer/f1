import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["links", "toggle", "overlay"]

  toggleMenu() {
    const isOpen = this.element.classList.contains("menu-open")
    if (isOpen) {
      this.closeMenu(true)
    } else {
      this.openMenu()
    }
  }

  openMenu() {
    this._previousOverflow = document.body.style.overflow
    this.element.classList.add("menu-open")
    this.toggleTarget.setAttribute("aria-expanded", "true")
    document.body.style.overflow = "hidden"

    // Stagger animate each nav item
    const items = this.linksTarget.querySelectorAll(".mobile-nav-item")
    items.forEach((item, i) => {
      item.style.animationDelay = `${60 + i * 40}ms`
    })
    this.linksTarget.querySelector("a")?.focus({ preventScroll: true })
  }

  closeMenu(restoreFocus = false) {
    const wasOpen = this.element.classList.contains("menu-open")
    this.element.classList.remove("menu-open")
    this.toggleTarget.setAttribute("aria-expanded", "false")
    if (wasOpen) document.body.style.overflow = this._previousOverflow || ""

    // Close any open mobile accordions
    this.linksTarget.querySelectorAll(".nav-dropdown-menu.open").forEach(m => {
      m.classList.remove("open")
      m.style.maxHeight = null
    })
    this.linksTarget.querySelectorAll("[data-dropdown-target='trigger']").forEach(t => {
      t.setAttribute("aria-expanded", "false")
    })
    if (wasOpen && restoreFocus) this.toggleTarget.focus({ preventScroll: true })
  }

  closeOverlay(event) {
    // Close when clicking the overlay backdrop (not the menu content)
    if (event.target === this.overlayTarget) {
      this.closeMenu(true)
    }
  }

  connect() {
    this._turboHandler = () => this.closeMenu()
    this._escHandler = (e) => {
      if (!this.element.classList.contains("menu-open")) return
      if (e.key === "Escape") this.closeMenu(true)
      if (e.key !== "Tab") return
      const focusable = [this.toggleTarget, ...this.linksTarget.querySelectorAll("a, button")]
        .filter(el => !el.disabled && el.getClientRects().length > 0)
      const first = focusable[0]
      const last = focusable[focusable.length - 1]
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault()
        last.focus()
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault()
        first.focus()
      }
    }
    this._desktop = window.matchMedia("(min-width: 769px)")
    this._resizeHandler = () => { if (this._desktop.matches) this.closeMenu() }
    this._desktop.addEventListener("change", this._resizeHandler)
    document.addEventListener("turbo:before-visit", this._turboHandler)
    document.addEventListener("turbo:before-cache", this._turboHandler)
    document.addEventListener("keydown", this._escHandler)
  }

  disconnect() {
    document.removeEventListener("turbo:before-visit", this._turboHandler)
    document.removeEventListener("turbo:before-cache", this._turboHandler)
    document.removeEventListener("keydown", this._escHandler)
    this._desktop.removeEventListener("change", this._resizeHandler)
    this.closeMenu()
  }
}
