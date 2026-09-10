import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "f1elo.analytics-consent"

export default class extends Controller {
  static targets = ["banner"]
  static values = { measurementId: String }

  connect() {
    const choice = this.readChoice()

    if (choice === "granted") this.enableAnalytics()
    this.bannerTarget.hidden = choice === "granted" || choice === "denied"
  }

  accept() {
    this.writeChoice("granted")
    this.bannerTarget.hidden = true
    this.enableAnalytics()
  }

  decline() {
    const wasLoaded = window.f1EloAnalyticsLoaded === true

    this.writeChoice("denied")
    this.bannerTarget.hidden = true

    // Once Google's script is active it cannot be reliably unloaded. Reloading
    // honors the new choice immediately and future pages do not load it.
    if (wasLoaded) window.location.reload()
  }

  open() {
    this.bannerTarget.hidden = false
    this.bannerTarget.querySelector("button")?.focus()
  }

  enableAnalytics() {
    if (window.f1EloAnalyticsLoaded || !this.measurementIdValue) return

    window.f1EloAnalyticsLoaded = true
    window.dataLayer = window.dataLayer || []
    window.gtag = function () { window.dataLayer.push(arguments) }
    window.gtag("js", new Date())
    window.gtag("config", this.measurementIdValue, { anonymize_ip: true })

    const script = document.createElement("script")
    script.async = true
    script.src = `https://www.googletagmanager.com/gtag/js?id=${encodeURIComponent(this.measurementIdValue)}`
    document.head.appendChild(script)
  }

  readChoice() {
    try {
      return window.localStorage.getItem(STORAGE_KEY)
    } catch (_error) {
      return null
    }
  }

  writeChoice(choice) {
    try {
      window.localStorage.setItem(STORAGE_KEY, choice)
    } catch (_error) {
      // Browsers that disable local storage will ask again next visit.
    }
  }
}
