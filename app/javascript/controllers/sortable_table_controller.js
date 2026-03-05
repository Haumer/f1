import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["header"]

  connect() {
    this.tbody = this.element.querySelector("tbody")
    this.headers = this.element.querySelectorAll("th[data-sort]")
    this.currentCol = null
    this.ascending = true

    this.headers.forEach((th) => {
      th.style.cursor = "pointer"
      th.addEventListener("click", () => this.sort(th))
    })
  }

  sort(th) {
    const col = th.cellIndex
    const type = th.dataset.sort // "num" or "text"

    if (this.currentCol === col) {
      this.ascending = !this.ascending
    } else {
      this.currentCol = col
      this.ascending = type === "text" // text defaults asc, numbers desc
    }

    // Clear sort indicators
    this.headers.forEach((h) => h.classList.remove("sort-asc", "sort-desc"))
    th.classList.add(this.ascending ? "sort-asc" : "sort-desc")

    const rows = Array.from(this.tbody.querySelectorAll("tr"))

    rows.sort((a, b) => {
      const aText = a.cells[col]?.textContent.trim() || ""
      const bText = b.cells[col]?.textContent.trim() || ""

      let result
      if (type === "num") {
        const aNum = parseFloat(aText.replace(/[^0-9.\-]/g, "")) || 0
        const bNum = parseFloat(bText.replace(/[^0-9.\-]/g, "")) || 0
        result = aNum - bNum
      } else {
        result = aText.localeCompare(bText)
      }

      return this.ascending ? result : -result
    })

    // Re-append sorted rows and update position cells
    rows.forEach((row, idx) => {
      this.tbody.appendChild(row)
      // Update position/rank column if it has .position-cell
      const posCell = row.querySelector(".position-cell")
      if (posCell) posCell.textContent = idx + 1

      // Update podium styling
      row.className = row.className.replace(/podium-row podium-p\d/g, "").trim()
      if (idx < 3) row.classList.add("podium-row", `podium-p${idx + 1}`)
    })
  }
}
