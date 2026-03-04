import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { target: String, label: String, format: { type: String, default: "inline" } }

  connect() {
    this.update()
    this.timer = setInterval(() => this.update(), 1000)
  }

  disconnect() {
    if (this.timer) clearInterval(this.timer)
  }

  update() {
    const target = new Date(this.targetValue)
    const now = new Date()
    const diff = target - now

    if (diff <= 0) {
      if (this.formatValue === "blocks") {
        this.element.innerHTML = this.buildBlocks(0, 0, 0, 0)
      } else {
        this.element.innerHTML = this.buildDisplay(this.labelValue || "Now", "0:00:00")
      }
      clearInterval(this.timer)
      return
    }

    const days = Math.floor(diff / 86400000)
    const hours = Math.floor((diff % 86400000) / 3600000)
    const minutes = Math.floor((diff % 3600000) / 60000)
    const seconds = Math.floor((diff % 60000) / 1000)

    if (this.formatValue === "blocks") {
      this.element.innerHTML = this.buildBlocks(days, hours, minutes, seconds)
    } else {
      let timeStr
      if (days > 0) {
        timeStr = `${days}d ${hours}h ${minutes}m`
      } else {
        timeStr = `${hours}:${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`
      }
      this.element.innerHTML = this.buildDisplay(this.labelValue || "Starts in", timeStr)
    }
  }

  buildDisplay(label, time) {
    return `<span class="countdown-timer-label">${label}</span><span class="countdown-timer-value">${time}</span>`
  }

  buildBlocks(days, hours, minutes, seconds) {
    const block = (value, unit) =>
      `<div class="countdown-block"><span class="countdown-number">${String(value).padStart(2, "0")}</span><span class="countdown-unit">${unit}</span></div>`
    const sep = `<span class="countdown-separator">:</span>`

    return block(days, "days") + sep + block(hours, "hrs") + sep + block(minutes, "min") + sep + block(seconds, "sec")
  }
}
