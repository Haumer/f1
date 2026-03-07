import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  switch(event) {
    const tab = event.currentTarget
    if (tab.classList.contains("table-tab--disabled")) return

    const selected = tab.dataset.tab

    this.tabTargets.forEach(t => {
      t.classList.toggle("active", t.dataset.tab === selected)
    })

    this.panelTargets.forEach(panel => {
      panel.style.display = panel.dataset.tab === selected ? "" : "none"
    })
  }
}
