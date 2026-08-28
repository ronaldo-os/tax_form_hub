import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.initLiveToasts();
  }

  initLiveToasts() {
    const toastContainer = document.getElementById("live_notification_toasts");
    if (!toastContainer) return;

    const toasts = toastContainer.querySelectorAll(".toast.live-notification-toast:not(.toast-initialized)");
    toasts.forEach(toastEl => {
      toastEl.classList.add("toast-initialized");
      if (typeof bootstrap !== "undefined" && bootstrap.Toast) {
        const bsToast = new bootstrap.Toast(toastEl, { delay: 7000, autohide: true });
        bsToast.show();
      }
    });
  }

  async markAllRead(event) {
    if (event) {
      event.preventDefault();
      event.stopPropagation();
    }

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');

    // Optimistic UI updates
    this.element.querySelectorAll(".notification-item.unread").forEach(item => {
      item.classList.remove("unread");
      const dot = item.querySelector(".notification-unread-dot");
      if (dot) dot.remove();
    });

    const badgePulse = this.element.querySelector(".notification-badge-pulse");
    const badgeCount = this.element.querySelector(".notification-badge-count");
    if (badgePulse) badgePulse.classList.add("d-none");
    if (badgeCount) {
      badgeCount.classList.add("d-none");
      badgeCount.textContent = "0";
    }

    const headerPill = document.getElementById("dropdown_unread_badge_pill");
    if (headerPill) {
      headerPill.textContent = "All read";
      headerPill.className = "badge bg-secondary-subtle text-muted rounded-pill px-2 py-0.5 fs-9 fw-semibold border";
    }

    const unreadTabBadge = document.querySelector("#notif-unread-tab .badge");
    if (unreadTabBadge) {
      unreadTabBadge.textContent = "0";
    }

    const markAllBtn = this.element.querySelector(".mark-all-read-btn");
    if (markAllBtn) markAllBtn.remove();

    try {
      await fetch("/notifications/mark_all_as_read", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": csrfToken
        }
      });
    } catch (error) {
      console.error("[Notifications] Error marking all as read:", error);
    }
  }

  markItemRead(event) {
    const item = event.currentTarget.closest(".notification-item");
    if (!item) return;

    const notifId = item.dataset.notificationId;
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');

    if (item.classList.contains("unread")) {
      item.classList.remove("unread");
      const dot = item.querySelector(".notification-unread-dot");
      if (dot) dot.remove();

      // Decrement badge count
      const badgeCount = document.getElementById("notification_unread_badge_count");
      if (badgeCount) {
        let count = parseInt(badgeCount.textContent) || 0;
        if (count > 1) {
          badgeCount.textContent = (count - 1).toString();
        } else {
          badgeCount.classList.add("d-none");
          badgeCount.textContent = "0";
          const badgePulse = document.querySelector(".notification-badge-pulse");
          if (badgePulse) badgePulse.classList.add("d-none");
        }
      }

      const unreadTabBadge = document.querySelector("#notif-unread-tab .badge");
      if (unreadTabBadge) {
        let count = parseInt(unreadTabBadge.textContent) || 0;
        unreadTabBadge.textContent = Math.max(0, count - 1).toString();
      }

      if (notifId && csrfToken) {
        fetch(`/notifications/${notifId}/mark_as_read`, {
          method: "PATCH",
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
            "X-CSRF-Token": csrfToken
          }
        }).catch(err => console.error("[Notifications] Error marking item read:", err));
      }
    }
  }
}
