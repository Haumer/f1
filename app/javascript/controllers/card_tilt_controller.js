import { Controller } from "@hotwired/stimulus"

// Pokemon-card mouse-tracking tilt + holographic surface. Three correctness
// rules (learned the hard way in the mockup):
//   1) Bind events to the wrapper, NOT the card. If we bind to the card, the
//      3D rotation can briefly move the card out from under the cursor; the
//      cursor enters a "gap", mouseleave fires, card snaps back, mouseenter
//      fires again — oscillation. The wrapper never transforms.
//   2) Throttle to one update per animation frame; mousemove fires ~120Hz.
//   3) Cache getBoundingClientRect on mouseenter — it doesn't move while hovered.
//
// Composes with card-flip: rotateY adds 180deg when flipped so tilt still
// feels natural on the back face.
//
// The holo surface is driven entirely through CSS custom properties written on
// THIS element (the .dc-flip wrapper). Custom properties inherit, so both faces
// and every layer inside read the same pointer state from one write, and the
// per-tier appearance stays in the stylesheet where it belongs — this
// controller has no idea what a tier is.
export default class extends Controller {
  static targets = ["inner"]

  connect() {
    // No hover on touch: the effect would either never fire or latch on after
    // a tap. Matches the @media (hover: none) guard in the stylesheet.
    if (window.matchMedia("(hover: none), (pointer: coarse)").matches) return
    this.enabled = true

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
    if (!this.enabled) return
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

  // Write pointer state once, on the wrapper. `x` and `y` are 0..1.
  setSurface(x, y, opacity) {
    const st = this.element.style
    st.setProperty("--px", `${(x * 100).toFixed(2)}%`)
    st.setProperty("--py", `${(y * 100).toFixed(2)}%`)
    // Background travels OPPOSITE the pointer and at a shorter throw. That
    // mismatch is the parallax — it reads as a foil layer sitting under glass
    // rather than painted on the surface.
    st.setProperty("--bgx", `${(50 + (0.5 - x) * 40).toFixed(2)}%`)
    st.setProperty("--bgy", `${(50 + (0.5 - y) * 40).toFixed(2)}%`)
    st.setProperty("--holo-opa", opacity.toFixed(3))
  }

  isFlipping() {
    const flip = this.flipNode()
    return !!(flip && flip.dataset.flipping === "1")
  }

  onEnter() {
    if (!this.enabled || this.isFlipping()) return
    const flip = this.flipNode()
    this.rect = flip ? flip.getBoundingClientRect() : this.element.getBoundingClientRect()
    const inner = this.inner()
    if (inner) inner.style.transition = "none"
  }

  onMove(e) {
    if (!this.enabled || this.isFlipping()) return
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

    // Brightest toward the edges, where a real card catches the light as it
    // tilts away from you. Never drops to 0 while hovered, or the surface
    // flickers off every time the pointer crosses the middle.
    //
    // Ceiling is deliberately well under 1. The foil is a surface treatment on
    // top of the driver artwork, and at full strength color-dodge simply eats
    // the portrait — the card stops being a picture of a driver.
    const dx = this.lastX - 0.5
    const dy = this.lastY - 0.5
    const fromCenter = Math.min(1, Math.hypot(dx, dy) / 0.7071)
    this.setSurface(this.lastX, this.lastY, 0.34 + fromCenter * 0.28)
  }

  onLeave() {
    if (!this.enabled) return
    this.rect = null
    const flip = this.flipNode()
    const inner = this.inner()
    if (inner) {
      inner.style.transition = ""
      inner.style.transform = flip && flip.classList.contains("flipped") ? "rotateY(180deg)" : ""
    }
    // Recentre the surface as it fades, so the next hover doesn't start from
    // wherever the pointer happened to exit.
    this.setSurface(0.5, 0.5, 0)
  }
}
