import { Controller } from "@hotwired/stimulus"

// Deck of cards for a single driver, grouped by tier. Renders ALL the user's
// cards for that driver in one stage; data-slot drives the CSS transforms.
//
//   slot values: "front" | "behind-1" | "behind-2" | "hidden"
//
// The "front" card additionally toggles .flipped to show its receipt back face.
//
// State held on the controller (not the DOM):
//   tiersInDeck — ordered rarest→commonest, set once from the markup
//   currentTier — which tier is in the "front" slot
//
// Tier-swap and within-tier-flip are both CSS animations — the controller just
// rewrites data-slot / .flipped, the SCSS does the rotateY.
export default class extends Controller {
  static targets = ["tierGroup", "tierPill"]
  static values = { tier: String }

  connect() {
    this.tiersInDeck = this.tierGroupTargets
      .map(g => g.dataset.tier)
      .filter((t, i, a) => a.indexOf(t) === i)
    if (!this.hasTierValue || !this.tiersInDeck.includes(this.tierValue)) {
      this.tierValue = this.tiersInDeck[0]
    }
    this._applySlots()
  }

  // tier-pill click → swap that tier to the front slot
  selectTier(event) {
    const target = event.currentTarget.dataset.tier
    if (!target || target === this.tierValue) return
    this.tierValue = target
    this._applySlots()
  }

  // active-card click → flip front↔back. Ignore clicks on the pill controls
  // and on behind-slot cards (those are handled below as tier-promotes).
  flip(event) {
    if (event.target.closest(".dc-combine-pill, .dc-tier-pill")) return

    const clickedGroup = event.currentTarget
    // If user clicked a behind-slot group, promote it to front instead.
    if (clickedGroup.dataset.slot !== "front") {
      this.tierValue = clickedGroup.dataset.tier
      this._applySlots()
      return
    }

    const flipNode = clickedGroup.querySelector(".dc-flip")
    if (!flipNode) return
    // Card-tilt sets `transition: none` and overwrites `transform` every frame
    // while hovered, which would kill the flip animation. Clear its inline
    // styles, mark a flipping window, and let card-tilt skip work during it.
    const inner = flipNode.querySelector(".dc-flip-inner")
    if (inner) {
      inner.style.transition = ""
      inner.style.transform  = ""
    }
    flipNode.dataset.flipping = "1"
    flipNode.classList.toggle("flipped")
    setTimeout(() => { delete flipNode.dataset.flipping }, 700)
  }

  _applySlots() {
    // Order tiers so current is index 0, rest follow by rarity desc
    const order = [this.tierValue, ...this.tiersInDeck.filter(t => t !== this.tierValue)]
    this.tierGroupTargets.forEach(group => {
      const idx = order.indexOf(group.dataset.tier)
      let slot = "hidden"
      if (idx === 0) slot = "front"
      else if (idx === 1) slot = "behind-1"
      else if (idx === 2) slot = "behind-2"
      group.dataset.slot = slot
      // Reset flip when a tier rotates off the front slot
      if (slot !== "front") {
        const flipNode = group.querySelector(".dc-flip")
        if (flipNode) flipNode.classList.remove("flipped")
      }
    })
    this.tierPillTargets.forEach(pill => {
      pill.classList.toggle("is-active", pill.dataset.tier === this.tierValue)
    })
  }

  _frontGroup() {
    return this.tierGroupTargets.find(g => g.dataset.slot === "front")
  }
}
