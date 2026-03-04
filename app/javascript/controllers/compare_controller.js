import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="compare"
export default class extends Controller {
  static targets = ["input", "suggestions", "chips", "chart", "stats", "emptyState"]
  static values = { searchUrl: String, selectedIds: { type: Array, default: [] } }

  connect() {
    this._drivers = new Map()
    this._debounceTimer = null
    this._outsideClickHandler = this._closeOnClickOutside.bind(this)
    document.addEventListener("click", this._outsideClickHandler)

    // Restore chips from pre-rendered data attributes
    this.element.querySelectorAll("[data-preloaded-id]").forEach(el => {
      const id = parseInt(el.dataset.preloadedId)
      const name = el.dataset.preloadedName
      const peakElo = el.dataset.preloadedPeakElo
      this._drivers.set(id, { name, peak_elo: peakElo })
      if (!this.selectedIdsValue.includes(id)) {
        this.selectedIdsValue = [...this.selectedIdsValue, id]
      }
    })
  }

  disconnect() {
    document.removeEventListener("click", this._outsideClickHandler)
  }

  search() {
    clearTimeout(this._debounceTimer)
    const query = this.inputTarget.value.trim()
    if (query.length < 2) {
      this.suggestionsTarget.innerHTML = ""
      this.suggestionsTarget.classList.remove("open")
      return
    }
    this._debounceTimer = setTimeout(() => this._fetchResults(query), 250)
  }

  async _fetchResults(query) {
    try {
      const url = `${this.searchUrlValue}?q=${encodeURIComponent(query)}`
      const response = await fetch(url)
      if (!response.ok) return

      const drivers = await response.json()
      const filtered = drivers.filter(d => !this.selectedIdsValue.includes(d.id))

      if (filtered.length === 0) {
        this.suggestionsTarget.innerHTML = `<div class="suggestion-item" style="color: var(--text-secondary, #6c757d); pointer-events: none;">No drivers found</div>`
      } else {
        this.suggestionsTarget.innerHTML = filtered.map(d =>
          `<div class="suggestion-item" data-action="click->compare#select"
                data-id="${d.id}" data-name="${this._escapeHtml(d.name)}" data-peak-elo="${d.peak_elo}">
            ${this._escapeHtml(d.name)} <span class="suggestion-elo">${d.peak_elo || ''}</span>
          </div>`
        ).join("")
      }
      this.suggestionsTarget.classList.add("open")
    } catch (error) {
      // Network error — silently close suggestions
      this.suggestionsTarget.classList.remove("open")
    }
  }

  _escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  select(event) {
    const el = event.currentTarget
    const id = parseInt(el.dataset.id)
    const name = el.dataset.name
    const peakElo = el.dataset.peakElo

    if (this.selectedIdsValue.length >= 7) {
      this.inputTarget.placeholder = "Maximum 7 drivers selected"
      return
    }

    this.selectedIdsValue = [...this.selectedIdsValue, id]
    this._drivers.set(id, { name, peak_elo: peakElo })

    this.inputTarget.value = ""
    this.suggestionsTarget.innerHTML = ""
    this.suggestionsTarget.classList.remove("open")

    this._renderChips()
    this._reloadComparison()
  }

  remove(event) {
    const id = parseInt(event.currentTarget.dataset.id)
    this.selectedIdsValue = this.selectedIdsValue.filter(i => i !== id)
    this._drivers.delete(id)
    this._renderChips()
    this._reloadComparison()
  }

  _renderChips() {
    this.chipsTarget.innerHTML = this.selectedIdsValue.map(id => {
      const d = this._drivers.get(id)
      return `<span class="compare-chip">
        ${d.name}
        <button data-action="click->compare#remove" data-id="${id}">&times;</button>
      </span>`
    }).join("")
  }

  _reloadComparison() {
    if (this.selectedIdsValue.length >= 2) {
      const ids = this.selectedIdsValue.join(",")
      const url = `${window.location.pathname}?driver_ids=${ids}`
      Turbo.visit(url, { action: "replace" })
    } else if (this.selectedIdsValue.length < 2) {
      const url = this.selectedIdsValue.length === 1
        ? `${window.location.pathname}?driver_ids=${this.selectedIdsValue[0]}`
        : window.location.pathname
      Turbo.visit(url, { action: "replace" })
    }
  }

  _closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.suggestionsTarget.classList.remove("open")
    }
  }
}
