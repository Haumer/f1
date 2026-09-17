import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const date = new Date(this.element.dateTime)
    if (!Number.isFinite(date.getTime())) return
    this.element.textContent = new Intl.DateTimeFormat(undefined, {
      month: "short", day: "numeric", hour: "2-digit", minute: "2-digit", timeZoneName: "short"
    }).format(date)
    this.element.title = `${date.toUTCString()} · shown in your local time zone`
  }
}
