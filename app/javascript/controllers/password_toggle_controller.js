// Password Toggle Controller - Replaces jQuery password toggle functionality
// Usage:
//   <div data-controller="password-toggle">
//     <input type="password" data-password-toggle-target="input">
//     <button type="button" data-action="click->password-toggle#toggle" data-password-toggle-target="button">
//       <i data-password-toggle-target="icon" class="fa fa-eye"></i>
//     </button>
//   </div>

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button", "icon"]

  connect() {
    this.isVisible = false
  }

  toggle() {
    this.isVisible = !this.isVisible

    if (this.hasInputTarget) {
      this.inputTarget.type = this.isVisible ? "text" : "password"
    }

    if (this.hasIconTarget) {
      const icon = this.iconTarget
      if (this.isVisible) {
        icon.classList.remove("fa-eye")
        icon.classList.add("fa-eye-slash")
      } else {
        icon.classList.remove("fa-eye-slash")
        icon.classList.add("fa-eye")
      }
    }

    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-pressed", this.isVisible)
      this.buttonTarget.setAttribute("aria-label", this.isVisible ? "Hide password" : "Show password")
    }
  }
}
