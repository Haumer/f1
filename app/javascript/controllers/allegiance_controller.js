import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["picker", "display"]

  confirm(event) {
    const name = event.currentTarget.dataset.teamName
    if (!confirm(`Support ${name}? This is locked until mid-season. You'll receive a 50 cash bonus!`)) {
      event.preventDefault()
    }
  }
}
