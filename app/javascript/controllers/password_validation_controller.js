import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "password",
    "confirmation",
    "lengthCheck",
    "uppercaseCheck",
    "lowercaseCheck",
    "numberCheck",
    "specialCheck",
    "meter",
    "meterText",
    "matchError"
  ]

  connect() {
    this.validatePassword()
    if (this.hasConfirmationTarget) {
      this.validateConfirmation()
    }
  }

  validatePassword() {
    if (!this.hasPasswordTarget) return;
    const pwd = this.passwordTarget.value

    // Check criteria
    const hasLength = pwd.length >= 12
    const hasUpper = /[A-Z]/.test(pwd)
    const hasLower = /[a-z]/.test(pwd)
    const hasNumber = /[0-9]/.test(pwd)
    const hasSpecial = /[^A-Za-z0-9]/.test(pwd)

    // Update checklist UI
    if (this.hasLengthCheckTarget) this.updateCheckmark(this.lengthCheckTarget, hasLength)
    if (this.hasUppercaseCheckTarget) this.updateCheckmark(this.uppercaseCheckTarget, hasUpper)
    if (this.hasLowercaseCheckTarget) this.updateCheckmark(this.lowercaseCheckTarget, hasLower)
    if (this.hasNumberCheckTarget) this.updateCheckmark(this.numberCheckTarget, hasNumber)
    if (this.hasSpecialCheckTarget) this.updateCheckmark(this.specialCheckTarget, hasSpecial)

    // Calculate strength
    let score = 0
    if (pwd.length > 0) {
      if (hasLength) score += 1
      if (pwd.length >= 16) score += 1
      if (hasUpper) score += 1
      if (hasLower) score += 1
      if (hasNumber) score += 1
      if (hasSpecial) score += 1
    }

    this.updateMeter(score)
    if (this.hasConfirmationTarget) {
      this.validateConfirmation()
    }
  }

  validateConfirmation() {
    if (!this.hasConfirmationTarget || !this.hasMatchErrorTarget) return

    const pwd = this.passwordTarget.value
    const conf = this.confirmationTarget.value

    if (conf.length > 0 && pwd !== conf) {
      this.matchErrorTarget.style.display = "block"
      this.matchErrorTarget.textContent = "Passwords do not match."
    } else {
      this.matchErrorTarget.style.display = "none"
    }
  }

  updateCheckmark(target, isMet) {
    if (isMet) {
      target.classList.remove("text-muted", "text-danger")
      target.classList.add("text-success")
      target.innerHTML = "✓ " + target.dataset.text
    } else {
      target.classList.remove("text-success", "text-danger")
      target.classList.add("text-muted")
      target.innerHTML = "○ " + target.dataset.text
    }
  }

  updateMeter(score) {
    if (!this.hasMeterTarget || !this.hasMeterTextTarget) return

    let strength = "Weak"
    let width = "0%"
    let colorClass = "bg-danger"

    if (score === 0) {
      width = "0%"
      strength = ""
    } else if (score <= 3) {
      strength = "Weak"
      width = "25%"
      colorClass = "bg-danger"
    } else if (score === 4) {
      strength = "Fair"
      width = "50%"
      colorClass = "bg-warning"
    } else if (score === 5) {
      strength = "Strong"
      width = "75%"
      colorClass = "bg-info"
    } else if (score >= 6) {
      strength = "Very Strong"
      width = "100%"
      colorClass = "bg-success"
    }

    this.meterTextTarget.textContent = strength
    this.meterTarget.className = `progress-bar ${colorClass}`
    this.meterTarget.style.width = width
  }
}
