// Lazy Loader Controller - Loads content only when visible in viewport
// Replaces jQuery lazy loading patterns with IntersectionObserver
//
// Usage:
//   <div data-controller="lazy-loader" data-lazy-loader-url-value="/api/data" data-lazy-loader-placeholder-value="Loading...">
//     <div data-lazy-loader-target="content">
//       <!-- Content loaded here -->
//     </div>
//   </div>
//
// Or for images:
//   <img data-controller="lazy-loader" data-lazy-loader-target="image" data-src="high-res.jpg" loading="lazy">

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "image", "iframe"]
  static values = {
    url: String,
    threshold: { type: Number, default: 0.1 },
    rootMargin: { type: String, default: "50px" },
    placeholder: { type: String, default: "Loading..." }
  }

  connect() {
    this.setupIntersectionObserver()
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  setupIntersectionObserver() {
    const options = {
      root: null,
      rootMargin: this.rootMarginValue,
      threshold: this.thresholdValue
    }

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          this.loadContent()
          this.observer.unobserve(entry.target)
        }
      })
    }, options)

    this.observer.observe(this.element)
  }

  async loadContent() {
    // Handle lazy-loaded images
    if (this.hasImageTarget) {
      this.imageTargets.forEach(img => {
        const src = img.dataset.src
        if (src) {
          img.src = src
          img.removeAttribute('data-src')
        }
      })
      return
    }

    // Handle lazy-loaded iframes
    if (this.hasIframeTarget) {
      this.iframeTargets.forEach(iframe => {
        const src = iframe.dataset.src
        if (src) {
          iframe.src = src
          iframe.removeAttribute('data-src')
        }
      })
      return
    }

    // Handle AJAX content loading
    if (this.urlValue && this.hasContentTarget) {
      this.contentTarget.innerHTML = `<div class="text-center p-3"><span class="spinner-border spinner-border-sm"></span> ${this.placeholderValue}</div>`

      try {
        const response = await fetch(this.urlValue, {
          headers: {
            'Accept': 'text/html',
            'X-Requested-With': 'XMLHttpRequest'
          }
        })

        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`)
        }

        const html = await response.text()
        this.contentTarget.innerHTML = html

        // Dispatch event for other controllers to hook into
        this.element.dispatchEvent(new CustomEvent('lazy-loaded', {
          bubbles: true,
          detail: { url: this.urlValue }
        }))
      } catch (error) {
        console.error('Lazy loader error:', error)
        this.contentTarget.innerHTML = `<div class="alert alert-danger">Failed to load content. <button class="btn btn-sm btn-link" data-action="click->lazy-loader#retry">Retry</button></div>`
      }
    }
  }

  retry() {
    this.loadContent()
  }
}
