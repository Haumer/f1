import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "status"]
  static values = { url: String }

  connect() {
    this.timeout = null
  }

  check() {
    clearTimeout(this.timeout)
    const username = this.inputTarget.value.trim().toLowerCase()
    const status = this.statusTarget

    if (username.length === 0) {
      status.textContent = ""
      status.className = "devise-username-status"
      return
    }

    if (username.length < 3) {
      status.textContent = "At least 3 characters"
      status.className = "devise-username-status devise-username-short"
      return
    }

    if (!/^[a-zA-Z0-9][a-zA-Z0-9_-]*$/.test(username)) {
      status.textContent = "Letters, numbers, hyphens, underscores only"
      status.className = "devise-username-status devise-username-taken"
      return
    }

    status.textContent = "Checking..."
    status.className = "devise-username-status devise-username-checking"

    this.timeout = setTimeout(() => {
      fetch(`${this.urlValue}?username=${encodeURIComponent(username)}`)
        .then(r => r.json())
        .then(data => {
          if (this.inputTarget.value.trim().toLowerCase() !== username) return
          if (data.available) {
            status.textContent = "Available"
            status.className = "devise-username-status devise-username-available"
          } else {
            status.textContent = "Already taken"
            status.className = "devise-username-status devise-username-taken"
          }
        })
        .catch(() => {
          status.textContent = ""
          status.className = "devise-username-status"
        })
    }, 300)
  }
}
