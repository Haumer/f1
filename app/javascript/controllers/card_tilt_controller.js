import { Controller } from "@hotwired/stimulus"

// Pokemon-card mouse-tracking tilt + sheen sweep. Three correctness rules
// (learned the hard way in the mockup):
//   1) Bind events to the wrapper, NOT the card. If we bind to the card, the
//      3D rotation can briefly move the card out from under the cursor; the
//      cursor enters a "gap", mouseleave fires, card snaps back, mouseenter
//      fires again — oscillation. The wrapper never transforms.
//   2) Throttle to one update per animation frame; mousemove fires ~120Hz.
//   3) Cache getBoundingClientRect on mouseenter — it doesn't move while hovered.
//
// Composes with card-flip: rotateY adds 180deg when flipped so tilt still
// feels natural on the back face.
export default class extends Controller {
  static targets = ["inner", "sheen"]

  connect() {
    this.MAX_TILT = 12
    this.rect = null
    this.lastX = 0.5
    this.lastY = 0.5
    this.rafPending = false

    this.onEnter = this.onEnter.bind(this)
    this.onMove  = this.onMove.bind(this)
    this.onLeave = this.onLeave.bind(this)

    this.element.addEventListener("mouseenter", this.onEnter)
    this.element.addEventListener("mousemove",  this.onMove)
    this.element.addEventListener("mouseleave", this.onLeave)
  }

  disconnect() {
    this.element.removeEventListener("mouseenter", this.onEnter)
    this.element.removeEventListener("mousemove",  this.onMove)
    this.element.removeEventListener("mouseleave", this.onLeave)
  }

  flipNode() {
    // The tilt controller sits on the wrapper around the flip. The first
    // descendant with .dc-flip carries the flipped class.
    return this.element.classList.contains("dc-flip") ? this.element : this.element.querySelector(".dc-flip")
  }

  inner() {
    if (this.hasInnerTarget) return this.innerTarget
    return this.element.querySelector(".dc-flip-inner")
  }

  sheen() {
    if (this.hasSheenTarget) return this.sheenTarget
    return this.element.querySelector(".dc-card .sheen")
  }

  isFlipping() {
    const flip = this.flipNode()
    return !!(flip && flip.dataset.flipping === "1")
  }

  onEnter() {
    if (this.isFlipping()) return
    const flip = this.flipNode()
    this.rect = flip ? flip.getBoundingClientRect() : this.element.getBoundingClientRect()
    const inner = this.inner()
    if (inner) inner.style.transition = "none"
    const sheen = this.sheen()
    if (sheen) sheen.style.opacity = "1"
  }

  onMove(e) {
    if (this.isFlipping()) return
    const flip = this.flipNode()
    if (!this.rect) this.rect = flip ? flip.getBoundingClientRect() : this.element.getBoundingClientRect()
    this.lastX = Math.max(0, Math.min(1, (e.clientX - this.rect.left) / this.rect.width))
    this.lastY = Math.max(0, Math.min(1, (e.clientY - this.rect.top)  / this.rect.height))
    if (!this.rafPending) {
      this.rafPending = true
      requestAnimationFrame(() => this.tick())
    }
  }

  tick() {
    this.rafPending = false
    if (this.isFlipping()) return
    const flip = this.flipNode()
    const inner = this.inner()
    if (!inner) return
    const rx = (0.5 - this.lastY) * this.MAX_TILT
    const ry = (this.lastX - 0.5) * this.MAX_TILT
    const flipY = flip && flip.classList.contains("flipped") ? 180 : 0
    inner.style.transition = "none"
    inner.style.transform =
      `rotateX(${rx.toFixed(2)}deg) rotateY(${(ry + flipY).toFixed(2)}deg)`
    const sheen = this.sheen()
    if (sheen) {
      const sx = (this.lastX - 0.5) * 50
      sheen.style.transform = `translate3d(${sx}%, 0, 0)`
    }
  }

  onLeave() {
    this.rect = null
    const flip = this.flipNode()
    const inner = this.inner()
    if (inner) {
      inner.style.transition = ""
      inner.style.transform = flip && flip.classList.contains("flipped") ? "rotateY(180deg)" : ""
    }
    const sheen = this.sheen()
    if (sheen) sheen.style.opacity = "0"
  }
}
