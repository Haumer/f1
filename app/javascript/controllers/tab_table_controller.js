import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { param: String, anchors: Boolean }

  connect() {
    this._keydown = this.keydown.bind(this)
    this.element.addEventListener("keydown", this._keydown)
    this._hashChange = () => {
      const tab = this.tabForHash()
      if (tab) {
        this.select(tab, true)
        this.scrollToHash()
      }
    }
    if (this.anchorsValue) window.addEventListener("hashchange", this._hashChange)
    this.tabTargets.forEach(tab => {
      const key = tab.dataset.tab
      tab.id = `${this.element.id}-${key}-tab`
      tab.setAttribute("role", "tab")
      tab.setAttribute("aria-controls", `${this.element.id}-${key}-panel`)
      tab.disabled = tab.classList.contains("table-tab--disabled")
    })
    this.panelTargets.forEach(panel => {
      panel.id = `${this.element.id}-${panel.dataset.tab}-panel`
      panel.setAttribute("role", "tabpanel")
      panel.setAttribute("aria-labelledby", `${this.element.id}-${panel.dataset.tab}-tab`)
    })

    const requested = this.hasParamValue ? new URL(location.href).searchParams.get(this.paramValue) : null
    const selected = this.enabledTabs.find(tab => tab.dataset.tab === requested) ||
      this.tabForHash() || this.enabledTabs.find(tab => tab.classList.contains("active")) || this.enabledTabs[0]
    if (selected) this.select(selected)
    if (selected && selected === this.tabForHash()) this.scrollToHash()
  }

  disconnect() {
    this.element.removeEventListener("keydown", this._keydown)
    window.removeEventListener("hashchange", this._hashChange)
    cancelAnimationFrame(this._chartFrame)
    cancelAnimationFrame(this._scrollFrame)
  }

  get enabledTabs() {
    return this.tabTargets.filter(tab => !tab.disabled)
  }

  hashTarget() {
    if (!this.anchorsValue || !location.hash) return null
    try {
      return document.getElementById(decodeURIComponent(location.hash.slice(1)))
    } catch {
      return null
    }
  }

  tabForHash() {
    const target = this.hashTarget()
    const panel = target && this.panelTargets.find(panel => panel.contains(target))
    return panel && this.enabledTabs.find(tab => tab.dataset.tab === panel.dataset.tab)
  }

  scrollToHash() {
    cancelAnimationFrame(this._scrollFrame)
    this._scrollFrame = requestAnimationFrame(() => {
      this.hashTarget()?.scrollIntoView({ block: "start", behavior: "instant" })
    })
  }

  switch(event) {
    this.select(event.currentTarget, true)
  }

  keydown(event) {
    if (!this.enabledTabs.includes(event.target)) return
    const tabs = this.enabledTabs
    const index = tabs.indexOf(event.target)
    let next
    if (event.key === "ArrowRight") next = tabs[(index + 1) % tabs.length]
    if (event.key === "ArrowLeft") next = tabs[(index - 1 + tabs.length) % tabs.length]
    if (event.key === "Home") next = tabs[0]
    if (event.key === "End") next = tabs[tabs.length - 1]
    if (!next) return
    event.preventDefault()
    this.select(next, true)
    next.focus({ preventScroll: true })
    next.scrollIntoView({ block: "nearest", inline: "nearest" })
  }

  select(tab, remember = false) {
    if (tab.disabled) return
    const selected = tab.dataset.tab

    this.tabTargets.forEach(t => {
      const active = t === tab
      t.classList.toggle("active", active)
      t.setAttribute("aria-selected", String(active))
      t.tabIndex = active ? 0 : -1
    })

    this.panelTargets.forEach(panel => {
      const active = panel.dataset.tab === selected
      panel.hidden = !active
      panel.style.display = active ? "" : "none"
    })

    if (remember && this.hasParamValue) {
      const url = new URL(location.href)
      url.searchParams.set(this.paramValue, selected)
      const anchoredTab = this.tabForHash()
      if (anchoredTab && anchoredTab !== tab) url.hash = this.element.id
      // Keep Turbo's restoration state, other query parameters and the anchor.
      history.replaceState(history.state, "", url)
    }

    // Charts initialized in a hidden panel have no measurable width. Resize
    // after revealing them, without touching data, tooltips or zoom settings.
    cancelAnimationFrame(this._chartFrame)
    this._chartFrame = requestAnimationFrame(() => {
      this.panelTargets.filter(panel => !panel.hidden).forEach(panel => {
        panel.querySelectorAll("[_echarts_instance_]").forEach(element => {
          window.echarts?.getInstanceByDom(element)?.resize()
        })
      })
    })
  }
}
