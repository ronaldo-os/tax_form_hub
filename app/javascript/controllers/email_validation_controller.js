import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["input", "error"]

    connect() {
        this.validate()
    }

    validate() {
        const value = this.element.value
        // Regex allowing only standard ASCII alphanumeric and email symbols
        // Blocks emojis and extended unicode characters
        const validCharsRegex = /^[a-zA-Z0-9._%+\-@]*$/

        if (!validCharsRegex.test(value)) {
            this.element.value = value.replace(/[^a-zA-Z0-9._%+\-@]/g, '')
            this.showError("Unsupported characters removed")
        } else {
            this.hideError()
        }
    }

    showError(message) {
        if (this.hasErrorTarget) {
            this.errorTarget.textContent = message
            this.errorTarget.style.display = "block"

            // Hide after 2 seconds
            setTimeout(() => {
                this.hideError()
            }, 2000)
        }
    }

    hideError() {
        if (this.hasErrorTarget) {
            this.errorTarget.style.display = "none"
        }
    }
}
