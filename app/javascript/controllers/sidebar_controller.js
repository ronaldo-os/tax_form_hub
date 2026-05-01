// Sidebar Controller - Replaces jQuery sidebar toggle functionality
// Handles desktop and mobile sidebar toggling with proper ARIA attributes
//
// Usage:
//   <div data-controller="sidebar">
//     <button data-action="click->sidebar#toggleDesktop" data-sidebar-target="desktopToggle">Toggle Desktop</button>
//     <button data-action="click->sidebar#toggleMobile" data-sidebar-target="mobileToggle">Toggle Mobile</button>
//     <aside data-sidebar-target="sidebar" role="navigation" aria-label="Main navigation">
//       <ul>
//         <li data-action="click->sidebar#activateItem" data-sidebar-target="menuItem">...</li>
//       </ul>
//     </aside>
//   </div>

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "desktopToggle", "mobileToggle", "menuItem"]
  static classes = ["active"]

  connect() {
    this.isDesktopOpen = false
    this.isMobileOpen = false
    this.boundHandleResize = this.handleResize.bind(this)
    window.addEventListener('resize', this.boundHandleResize)
  }

  disconnect() {
    window.removeEventListener('resize', this.boundHandleResize)
  }

  toggleDesktop() {
    this.isDesktopOpen = !this.isDesktopOpen
    this.updateSidebarState()
    this.updateToggleStates()
  }

  toggleMobile() {
    this.isMobileOpen = !this.isMobileOpen
    this.updateSidebarState()
    this.updateToggleStates()
  }

  updateSidebarState() {
    if (!this.hasSidebarTarget) return

    const sidebar = this.sidebarTarget
    const isMobile = window.innerWidth <= 768

    if (isMobile) {
      // Mobile: only mobile toggle controls it
      sidebar.classList.toggle(this.activeClass, this.isMobileOpen)
      sidebar.setAttribute("aria-hidden", !this.isMobileOpen)
    } else {
      // Desktop: only desktop toggle controls it
      sidebar.classList.toggle(this.activeClass, this.isDesktopOpen)
      sidebar.setAttribute("aria-hidden", !this.isDesktopOpen)
    }
  }

  updateToggleStates() {
    const isMobile = window.innerWidth <= 768

    if (this.hasDesktopToggleTarget) {
      this.desktopToggleTarget.setAttribute("aria-expanded", this.isDesktopOpen)
      this.desktopToggleTarget.classList.toggle(this.activeClass, this.isDesktopOpen)
    }

    if (this.hasMobileToggleTarget) {
      this.mobileToggleTarget.setAttribute("aria-expanded", this.isMobileOpen)
      this.mobileToggleTarget.classList.toggle(this.activeClass, this.isMobileOpen)
    }
  }

  handleResize() {
    const isMobile = window.innerWidth <= 768

    // Auto-close mobile sidebar when resizing to desktop
    if (!isMobile && this.isMobileOpen) {
      this.isMobileOpen = false
      this.updateSidebarState()
    }

    // Update toggle states based on new screen size
    this.updateToggleStates()
  }

  activateItem(event) {
    if (!this.hasMenuItemTarget) return

    // Remove active class from all items
    this.menuItemTargets.forEach(item => {
      item.classList.remove(this.activeClass)
    })

    // Add active class to clicked item
    event.currentTarget.classList.add(this.activeClass)

    // On mobile, close sidebar after selection
    if (window.innerWidth <= 768 && this.isMobileOpen) {
      this.isMobileOpen = false
      this.updateSidebarState()
      this.updateToggleStates()
    }
  }

  close() {
    const isMobile = window.innerWidth <= 768
    if (isMobile) {
      this.isMobileOpen = false
    } else {
      this.isDesktopOpen = false
    }
    this.updateSidebarState()
    this.updateToggleStates()
  }
}
