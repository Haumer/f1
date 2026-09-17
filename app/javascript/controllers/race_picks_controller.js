import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Picks are a local draft until an explicit save. Scoring stays server-owned.
export default class extends Controller {
  static targets = ["card", "picksInput", "counter", "randomiseBtn", "clearBtn", "submitBtn",
    "formToggle", "sortGroup", "slotList", "undoBtn", "goalReady", "optionalBtn",
    "empty", "message", "summary", "saveState"]
  static values = { total: Number, goal: Number, storageKey: String, version: String, saved: Boolean, closesAt: String, open: Boolean }

  connect() {
    this.cards = new Map(this.cardTargets.map(card => [card.dataset.driverId, card]))
    this.baseline = this.parse(this.picksInputTarget.value) || []
    this.picks = structuredClone(this.baseline)
    this.history = []
    this.submitting = false
    this.showForm = false
    this.storageFailed = false
    this.restore()
    this.optional = this.picks.length > this.goalValue
    this.render()
    this.initSortable()
    this.checkDeadline()
    this.deadlineTimer = setInterval(() => this.checkDeadline(), 1000)
  }

  disconnect() {
    clearInterval(this.deadlineTimer)
    this.sortable?.destroy()
  }

  get closed() {
    const deadline = Date.parse(this.closesAtValue)
    return !this.openValue || (Number.isFinite(deadline) && Date.now() >= deadline)
  }

  get dirty() { return JSON.stringify(this.picks) !== JSON.stringify(this.baseline) }
  get limit() { return this.optional ? this.totalValue : this.goalValue }

  parse(raw) {
    try {
      const rows = typeof raw === "string" ? JSON.parse(raw) : raw
      if (!Array.isArray(rows) || rows.length > this.totalValue) return null
      const ids = new Set()
      const sorted = [...rows].sort((a, b) => a.position - b.position)
      if (!sorted.every((row, i) => {
        if (!row || row.position !== i + 1 || !this.cards.has(String(row.driver_id)) ||
            !["manual", "random"].includes(row.source || "manual") || ids.has(String(row.driver_id))) return false
        ids.add(String(row.driver_id))
        return true
      })) return null
      return sorted.map(row => ({ driver_id: Number(row.driver_id), position: row.position, source: row.source || "manual" }))
    } catch { return null }
  }

  restore() {
    try {
      const raw = sessionStorage.getItem(this.storageKeyValue)
      if (!raw) return
      const draft = JSON.parse(raw)
      const picks = this.parse(draft.picks)
      if (!picks || draft.version !== this.versionValue || this.closed) {
        sessionStorage.removeItem(this.storageKeyValue)
        this.announce("An outdated draft was discarded. Showing your latest saved picks.")
        return
      }
      this.picks = picks
      this.announce("Draft restored on this device. Nothing has been submitted.")
    } catch {
      // A malformed or inaccessible draft must not prevent picking.
      this.announce("Could not restore the draft. Showing your saved picks.")
    }
  }

  persist() {
    try {
      if (this.closed || !this.dirty) sessionStorage.removeItem(this.storageKeyValue)
      else sessionStorage.setItem(this.storageKeyValue, JSON.stringify({ version: this.versionValue, picks: this.picks }))
    } catch {
      this.storageFailed = true
      this.announce("Draft storage is unavailable. Keep this page open until you save.")
    }
  }

  remember() {
    this.history.push(structuredClone(this.picks))
    if (this.history.length > 30) this.history.shift()
  }

  changed(message, focus) {
    this.picks.forEach((pick, index) => pick.position = index + 1)
    this.persist()
    this.render()
    this.announce(message)
    if (focus) this.slotListTarget.querySelector(focus)?.focus({ preventScroll: true })
  }

  announce(message) { this.messageTarget.textContent = message }

  checkDeadline() {
    if (!this.closed || this.deadlineHandled) return
    this.deadlineHandled = true
    this.persist()
    this.render()
    this.sortable?.option("disabled", true)
    this.announce("Picks are locked. Unsaved changes were not submitted.")
  }

  toggleForm() {
    this.showForm = !this.showForm
    this.element.classList.toggle("show-form", this.showForm)
    this.formToggleTarget.classList.toggle("active", this.showForm)
    this.formToggleTarget.setAttribute("aria-pressed", this.showForm)
  }

  sort(event) {
    const key = event.currentTarget.dataset.sort
    this.sortGroupTarget.querySelectorAll("button").forEach(button => {
      const selected = button === event.currentTarget
      button.classList.toggle("active", selected)
      button.setAttribute("aria-pressed", selected)
    })
    const cards = [...this.cardTargets]
    cards.sort((a, b) => {
      if (key === "elo") return Number(b.dataset.driverElo) - Number(a.dataset.driverElo)
      if (key === "team") return a.dataset.driverTeam.localeCompare(b.dataset.driverTeam) || Number(b.dataset.driverElo) - Number(a.dataset.driverElo)
      if (key === "alpha") return a.dataset.driverSurname.localeCompare(b.dataset.driverSurname)
      return Number(a.dataset.driverLastPos) - Number(b.dataset.driverLastPos)
    })
    cards.forEach(card => this.cardTargets[0].parentElement.appendChild(card))
  }

  place(event) {
    if (this.closed || this.submitting || this.picks.length >= this.limit) return
    const card = event.currentTarget
    const id = Number(card.dataset.driverId)
    if (this.picks.some(pick => pick.driver_id === id)) return
    this.remember()
    this.picks.push({ driver_id: id, position: this.picks.length + 1, source: "manual" })
    this.changed(card.dataset.driverName + " placed at P" + this.picks.length + ".")
    if (this.picks.length === this.goalValue) this.announce("Your top " + this.goalValue + " is ready. Review your order and press Save.")
  }

  remove(event) {
    if (this.closed || this.submitting) return
    const index = this.picks.findIndex(pick => pick.driver_id === Number(event.currentTarget.dataset.driverId))
    if (index < 0) return
    this.remember()
    const removed = this.picks.splice(index, 1)[0]
    const next = this.picks[Math.min(index, this.picks.length - 1)]
    this.changed(this.cards.get(String(removed.driver_id)).dataset.driverName + " removed. Undo is available.",
      next && '[data-driver-id="' + next.driver_id + '"] .pick-slot-remove')
    if (!next) this.undoBtnTarget.focus({ preventScroll: true })
  }

  move(event) {
    if (this.closed || this.submitting) return
    const id = Number(event.currentTarget.dataset.driverId)
    const index = this.picks.findIndex(pick => pick.driver_id === id)
    const direction = Number(event.currentTarget.dataset.direction)
    const target = index + direction
    if (index < 0 || target < 0 || target >= this.picks.length) return
    this.remember()
    ;[this.picks[index], this.picks[target]] = [this.picks[target], this.picks[index]]
    this.changed(this.cards.get(String(id)).dataset.driverName + " moved to P" + (target + 1) + ".",
      '[data-driver-id="' + id + '"] [data-direction="' + direction + '"]:not(:disabled)')
    // At the end of the list the same arrow is disabled; keep focus on this row.
    if (document.activeElement === document.body) this.slotListTarget.querySelector('[data-driver-id="' + id + '"] button:not(:disabled)')?.focus({ preventScroll: true })
  }

  undo() {
    if (this.closed || this.submitting || !this.history.length) return
    this.picks = this.history.pop()
    if (this.picks.length > this.goalValue) this.optional = true
    this.changed("Last change undone.")
    if (!this.history.length) this.review()
  }

  clear() {
    if (this.closed || this.submitting || !this.picks.length) return
    this.remember()
    this.picks = []
    this.optional = false
    this.changed("Draft cleared. Your saved picks have not changed. Undo is available.")
    this.undoBtnTarget.focus({ preventScroll: true })
  }

  randomise() {
    if (this.closed || this.submitting) return
    this.remember()
    const placed = new Set(this.picks.map(pick => String(pick.driver_id)))
    const available = [...this.cards.keys()].filter(id => !placed.has(id))
    for (let i = available.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1))
      ;[available[i], available[j]] = [available[j], available[i]]
    }
    available.slice(0, this.limit - this.picks.length).forEach(id =>
      this.picks.push({ driver_id: Number(id), position: this.picks.length + 1, source: "random" }))
    this.changed("Remaining positions filled randomly. Review before saving.")
  }

  rankRest() {
    if (this.closed || this.submitting) return
    this.optional = true
    this.render()
    this.announce("Optional positions do not score. Your top " + this.goalValue + " is ready to save.")
    this.chooseMore()
  }

  review() { this.jumpTo("pick-order") }
  chooseMore() { this.jumpTo("pick-drivers") }
  jumpTo(id) {
    const target = this.element.querySelector("#" + id)
    target.focus({ preventScroll: true })
    target.scrollIntoView({ block: "start", behavior: "instant" })
  }

  submit(event) {
    if (this.closed || this.submitting || !this.picks.length) {
      event.preventDefault()
      this.checkDeadline()
      return
    }
    this.submitting = true
    this.render()
  }

  submitEnd(event) {
    this.submitting = false
    if (!event.detail.success) {
      this.render()
      this.announce("Picks were not saved. Your draft is still here; please try again.")
    }
    // Only a successful server response clears storage (via the success flash).
  }

  node(tag, className, text) {
    const element = document.createElement(tag)
    element.className = className
    if (text != null) element.textContent = text
    return element
  }

  control(pick, label, text, action, direction, disabled = false) {
    const button = this.node("button", action === "remove" ? "pick-slot-remove" : "pick-slot-move", text)
    button.type = "button"
    button.dataset.action = "race-picks#" + action
    button.dataset.driverId = pick.driver_id
    if (direction) button.dataset.direction = direction
    button.setAttribute("aria-label", label)
    button.disabled = disabled || this.closed || this.submitting
    return button
  }

  render() {
    const placed = new Set(this.picks.map(pick => String(pick.driver_id)))
    this.cardTargets.forEach(card => {
      const selected = placed.has(card.dataset.driverId)
      card.classList.toggle("pick-placed", selected)
      card.setAttribute("aria-pressed", selected)
      card.disabled = selected || this.closed || this.submitting || this.picks.length >= this.limit
    })

    const fragment = document.createDocumentFragment()
    this.picks.forEach((pick, index) => {
      if (index === this.goalValue) {
        fragment.appendChild(this.node("p", "picks-card-cutoff", "Optional positions · no points or cards"))
      }
      const card = this.cards.get(String(pick.driver_id))
      const name = card.dataset.driverName
      const row = this.node("div", "pick-slot-filled" + (index >= this.goalValue ? " pick-slot-no-card" : ""))
      row.dataset.driverId = pick.driver_id
      row.style.setProperty("--constructor-color", card.dataset.driverTeamColor)
      row.appendChild(this.node("span", "pick-slot-pos place-" + pick.position, "P" + pick.position))
      row.appendChild(this.node("span", "pick-slot-name", name))
      row.appendChild(this.node("span", "pick-slot-team", card.dataset.driverTeam))
      row.appendChild(this.node("span", "pick-slot-elo", card.dataset.driverElo))
      if (pick.source === "random") row.appendChild(this.node("span", "pick-slot-badge random", "random"))
      const controls = this.node("span", "pick-slot-controls")
      controls.append(
        this.control(pick, "Move " + name + " up", "↑", "move", -1, index === 0),
        this.control(pick, "Move " + name + " down", "↓", "move", 1, index === this.picks.length - 1),
        this.control(pick, "Remove " + name, "×", "remove"))
      row.appendChild(controls)
      fragment.appendChild(row)
    })
    this.slotListTarget.replaceChildren(fragment)

    const count = Math.min(this.picks.length, this.goalValue)
    const complete = count === this.goalValue && count > 0
    this.counterTarget.textContent = count + "/" + this.goalValue
    this.summaryTarget.textContent = complete ? "Top " + this.goalValue + " ready" : count + "/" + this.goalValue + " picked"
    if (this.picks.length > this.goalValue) this.summaryTarget.textContent += " · " + (this.picks.length - this.goalValue) + " optional"
    this.saveStateTarget.textContent = this.closed ? "Locked" : this.submitting ? "Saving…" :
      this.dirty ? (this.storageFailed ? "Unsaved · keep this page open" : "Unsaved changes") :
      this.baseline.length ? (this.savedValue ? "Saved · editable" : "Sign up to save") : "Not saved"
    this.emptyTarget.hidden = this.picks.length > 0
    this.goalReadyTarget.hidden = !complete || this.closed
    if (this.hasOptionalBtnTarget) this.optionalBtnTarget.hidden = this.optional
    this.randomiseBtnTarget.hidden = this.picks.length >= this.limit
    this.randomiseBtnTarget.disabled = this.closed || this.submitting
    this.clearBtnTarget.hidden = !this.picks.length
    this.clearBtnTarget.disabled = this.closed || this.submitting
    this.undoBtnTarget.hidden = !this.history.length
    this.undoBtnTarget.disabled = this.closed || this.submitting
    this.submitBtnTarget.disabled = !this.picks.length || this.closed || this.submitting
    this.picksInputTarget.value = JSON.stringify(this.picks)
  }

  initSortable() {
    this.sortable = Sortable.create(this.slotListTarget, {
      animation: matchMedia("(prefers-reduced-motion: reduce)").matches ? 0 : 150,
      delay: 150, delayOnTouchOnly: true, touchStartThreshold: 5,
      draggable: ".pick-slot-filled", filter: "button", preventOnFilter: false,
      ghostClass: "pick-slot-ghost", chosenClass: "pick-slot-chosen", dragClass: "pick-slot-drag",
      onEnd: () => {
        if (this.closed || this.submitting) { this.render(); return }
        this.remember()
        this.picks = [...this.slotListTarget.querySelectorAll(".pick-slot-filled")].map(row =>
          this.picks.find(pick => pick.driver_id === Number(row.dataset.driverId)))
        this.changed("Pick order updated. Undo is available.")
      }
    })
  }
}
