import { Controller } from "@hotwired/stimulus"
import debounce from 'debounce';

// Connects to data-controller="search-form"
export default class extends Controller {
  static targets = [ "form" ]

  initialize() {
    this.submit = debounce(this.submit.bind(this), 250)
  }

  submit() {
    this.element.requestSubmit()
  }
}
