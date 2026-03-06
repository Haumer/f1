import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["links", "toggle", "overlay"]

  toggleMenu() {
    const isOpen = this.element.classList.contains("menu-open")
    if (isOpen) {
      this.closeMenu()
    } else {
      this.openMenu()
    }
  }

  openMenu() {
    this.element.classList.add("menu-open")
    this.toggleTarget.setAttribute("aria-expanded", "true")
    document.body.style.overflow = "hidden"

    // Stagger animate each nav item
    const items = this.linksTarget.querySelectorAll(".mobile-nav-item")
    items.forEach((item, i) => {
      item.style.animationDelay = `${60 + i * 40}ms`
    })
  }

  closeMenu() {
    this.element.classList.remove("menu-open")
    this.toggleTarget.setAttribute("aria-expanded", "false")
    document.body.style.overflow = ""

    // Close any open mobile accordions
    this.linksTarget.querySelectorAll(".nav-dropdown-menu.open").forEach(m => {
      m.classList.remove("open")
      m.style.maxHeight = null
    })
    this.linksTarget.querySelectorAll(".nav-dropdown-toggle").forEach(t => {
      t.setAttribute("aria-expanded", "false")
    })
  }

  closeOverlay(event) {
    // Close when clicking the overlay backdrop (not the menu content)
    if (event.target === this.overlayTarget) {
      this.closeMenu()
    }
  }

  connect() {
    this._turboHandler = () => this.closeMenu()
    this._escHandler = (e) => { if (e.key === "Escape") this.closeMenu() }
    document.addEventListener("turbo:before-visit", this._turboHandler)
    document.addEventListener("keydown", this._escHandler)
  }

  disconnect() {
    document.removeEventListener("turbo:before-visit", this._turboHandler)
    document.removeEventListener("keydown", this._escHandler)
    document.body.style.overflow = ""
  }
}
