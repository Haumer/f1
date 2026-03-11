import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Interactive race pick builder.
// Users click driver cards to place them into ranked slots (1st, 2nd, …).
// Placed picks can be reordered via SortableJS drag-and-drop.
export default class extends Controller {
  static targets = ["card", "slot", "picksInput", "counter", "randomiseBtn", "clearBtn", "submitBtn", "formToggle", "sortGroup", "slotList"]
  static values = { total: Number }

  connect() {
    this.picks = [] // [{ driverId, position, source }]

    // Restore existing picks from hidden input
    const existing = this.picksInputTarget.value
    if (existing) {
      try {
        const parsed = JSON.parse(existing)
        if (Array.isArray(parsed) && parsed.length > 0) {
          this.picks = parsed.map(p => ({
            driverId: String(p.driver_id),
            position: p.position,
            source: p.source || "manual"
          }))
        }
      } catch (e) { /* ignore */ }
    }

    this.showForm = false
    this.render()
    this.initSortable()
  }

  disconnect() {
    if (this.sortable) this.sortable.destroy()
  }

  toggleForm(event) {
    event.preventDefault()
    event.stopPropagation()
    this.showForm = !this.showForm
    this.element.classList.toggle("show-form", this.showForm)
    if (this.hasFormToggleTarget) {
      this.formToggleTarget.classList.toggle("active", this.showForm)
    }
  }

  sort(event) {
    event.preventDefault()
    event.stopPropagation()
    const key = event.currentTarget.dataset.sort

    // Update active button
    if (this.hasSortGroupTarget) {
      this.sortGroupTarget.querySelectorAll(".picks-sort-btn").forEach(b => b.classList.remove("active"))
      event.currentTarget.classList.add("active")
    }

    const grid = this.cardTargets[0]?.parentElement
    if (!grid) return

    const cards = [...this.cardTargets]
    cards.sort((a, b) => {
      switch (key) {
        case "elo":
          return parseInt(b.dataset.driverElo) - parseInt(a.dataset.driverElo)
        case "team":
          return (a.dataset.driverTeam || "").localeCompare(b.dataset.driverTeam || "") ||
                 parseInt(b.dataset.driverElo) - parseInt(a.dataset.driverElo)
        case "form":
          return parseInt(a.dataset.driverLastPos) - parseInt(b.dataset.driverLastPos)
        case "alpha":
          return (a.dataset.driverSurname || "").localeCompare(b.dataset.driverSurname || "")
        default:
          return 0
      }
    })

    cards.forEach(card => grid.appendChild(card))
  }

  // Click a driver card to place them in next available slot
  place(event) {
    event.preventDefault()
    const card = event.currentTarget.closest("[data-driver-id]")
    if (!card) return

    const driverId = card.dataset.driverId
    if (this.picks.find(p => p.driverId === driverId)) return

    const nextPosition = this.nextAvailablePosition()
    if (!nextPosition) return

    this.picks.push({ driverId, position: nextPosition, source: "manual" })
    this.render()
  }

  // Remove a driver from picks (click the × on a placed row)
  remove(event) {
    event.preventDefault()
    const driverId = event.currentTarget.dataset.driverId
    this.picks = this.picks.filter(p => p.driverId !== driverId)
    // Re-number positions sequentially
    this.picks.sort((a, b) => a.position - b.position)
    this.picks.forEach((p, i) => p.position = i + 1)
    this.render()
  }

  // Fill remaining slots randomly
  randomise(event) {
    event.preventDefault()
    const placedIds = new Set(this.picks.map(p => p.driverId))
    const available = this.cardTargets
      .map(c => c.dataset.driverId)
      .filter(id => !placedIds.has(id))

    // Shuffle
    for (let i = available.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [available[i], available[j]] = [available[j], available[i]]
    }

    available.forEach(driverId => {
      const pos = this.nextAvailablePosition()
      if (pos) {
        this.picks.push({ driverId, position: pos, source: "random" })
      }
    })

    this.render()
  }

  // Clear all picks
  clear(event) {
    event.preventDefault()
    this.picks = []
    this.render()
  }

  render() {
    const placedIds = new Set(this.picks.map(p => p.driverId))

    // Update driver cards — dim placed ones
    this.cardTargets.forEach(card => {
      const id = card.dataset.driverId
      card.classList.toggle("pick-placed", placedIds.has(id))
    })

    // Build the sortable list from picks data
    const container = this.slotListTarget
    const sorted = [...this.picks].sort((a, b) => a.position - b.position)

    container.innerHTML = ""

    sorted.forEach(pick => {
      const card = this.cardTargets.find(c => c.dataset.driverId === pick.driverId)
      const name = card?.dataset.driverName || "Unknown"
      const team = card?.dataset.driverTeam || ""
      const teamColor = card?.dataset.driverTeamColor || "#555"
      const elo = card?.dataset.driverElo || ""
      const isRandom = pick.source === "random"

      const row = document.createElement("div")
      row.className = "pick-slot-filled"
      row.dataset.driverId = pick.driverId
      row.style.setProperty("--constructor-color", teamColor)
      row.innerHTML = `
        <span class="pick-slot-pos place-${pick.position <= 3 ? pick.position : ''}">${pick.position}</span>
        <span class="pick-slot-name">${name}</span>
        <span class="pick-slot-team">${team}</span>
        <span class="pick-slot-elo">${elo}</span>
        ${isRandom ? '<span class="pick-slot-badge random">random</span>' : ''}
        <button class="pick-slot-remove" data-action="click->race-picks#remove" data-driver-id="${pick.driverId}">
          <i class="fa-solid fa-xmark"></i>
        </button>
      `
      container.appendChild(row)
    })

    // Counter
    if (this.hasCounterTarget) {
      this.counterTarget.textContent = `${this.picks.length}/${this.totalValue}`
    }

    // Show/hide buttons
    const hasEmpty = this.picks.length < this.totalValue
    const hasAny = this.picks.length > 0
    if (this.hasRandomiseBtnTarget) this.randomiseBtnTarget.style.display = hasEmpty ? "" : "none"
    if (this.hasClearBtnTarget) this.clearBtnTarget.style.display = hasAny ? "" : "none"
    if (this.hasSubmitBtnTarget) this.submitBtnTarget.disabled = !hasAny

    // Sync hidden input
    this.picksInputTarget.value = JSON.stringify(
      this.picks.map(p => ({ driver_id: parseInt(p.driverId), position: p.position, source: p.source }))
    )
  }

  nextAvailablePosition() {
    const taken = new Set(this.picks.map(p => p.position))
    for (let i = 1; i <= this.totalValue; i++) {
      if (!taken.has(i)) return i
    }
    return null
  }

  initSortable() {
    this.sortable = Sortable.create(this.slotListTarget, {
      animation: 150,
      delay: 150,
      delayOnTouchOnly: true,
      touchStartThreshold: 5,
      filter: ".pick-slot-remove",
      preventOnFilter: false,
      ghostClass: "pick-slot-ghost",
      chosenClass: "pick-slot-chosen",
      dragClass: "pick-slot-drag",
      onEnd: (evt) => {
        // Read new order from DOM
        const rows = this.slotListTarget.querySelectorAll(".pick-slot-filled")
        rows.forEach((row, i) => {
          const driverId = row.dataset.driverId
          const pick = this.picks.find(p => p.driverId === driverId)
          if (pick) pick.position = i + 1
        })
        this.render()
      }
    })
  }
}
