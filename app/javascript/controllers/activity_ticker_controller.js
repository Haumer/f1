import { Controller } from "@hotwired/stimulus"

// Autoscrolling horizontal ticker for the homepage community activity feed.
// The track content is duplicated in the HTML so scrolling can loop
// seamlessly by resetting to 0 once half the track has scrolled by.
// Pauses on hover so users can actually read a row that catches their eye.
export default class extends Controller {
  static targets = ["track"]
  static values  = { speed: { type: Number, default: 40 } } // px/sec

  connect() {
    this.paused = false
    this.lastTs = null
    this.offset = 0
    this.raf = requestAnimationFrame(this.tick)
    this.element.addEventListener("mouseenter", this.pause)
    this.element.addEventListener("mouseleave", this.resume)
    this.element.addEventListener("focusin", this.pause)
    this.element.addEventListener("focusout", this.resume)
  }

  disconnect() {
    if (this.raf) cancelAnimationFrame(this.raf)
    this.element.removeEventListener("mouseenter", this.pause)
    this.element.removeEventListener("mouseleave", this.resume)
    this.element.removeEventListener("focusin", this.pause)
    this.element.removeEventListener("focusout", this.resume)
  }

  pause = () => { this.paused = true }
  resume = () => { this.paused = false }

  tick = (ts) => {
    if (!this.hasTrackTarget) return
    if (this.lastTs === null) this.lastTs = ts
    const dt = (ts - this.lastTs) / 1000
    this.lastTs = ts

    if (!this.paused) {
      this.offset += this.speedValue * dt
      const half = this.trackTarget.scrollWidth / 2
      if (half > 0 && this.offset >= half) this.offset -= half
      this.trackTarget.style.transform = `translateX(-${this.offset}px)`
    }

    this.raf = requestAnimationFrame(this.tick)
  }
}
