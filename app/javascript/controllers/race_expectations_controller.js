import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["body"]

  sort(event) {
    const key = event.target.value
    if (!["finish", "qualifying", "expected", "difference"].includes(key)) return

    const value = (row, field) => {
      const raw = row.dataset[field]
      return raw === undefined || raw === "" ? null : Number(raw)
    }
    const rows = Array.from(this.bodyTarget.rows)
    rows.sort((a, b) => {
      const left = value(a, key)
      const right = value(b, key)
      if (left === null && right !== null) return 1
      if (right === null && left !== null) return -1
      const order = left === null ? 0 : (left - right) * (key === "difference" ? -1 : 1)
      return order || (value(a, "finish") ?? Infinity) - (value(b, "finish") ?? Infinity)
    })
    rows.forEach((row) => this.bodyTarget.appendChild(row))
  }
}
