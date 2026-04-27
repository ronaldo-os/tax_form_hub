// AJAX/Turbo updates for invoice actions
document.addEventListener('turbo:load', function() {
  // Handle invoice status updates without page reload
  function updateInvoiceStatus(invoiceId, newStatus, tab = null) {
    const url = `/invoices/${invoiceId}/update_status`;
    const data = { status: newStatus, tab: tab };
    
    fetch(url, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify(data)
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        // Update the status badge
        const statusBadge = document.querySelector(`#invoice-${invoiceId} .status-badge`);
        if (statusBadge) {
          statusBadge.textContent = data.status;
          statusBadge.className = `status-badge badge ${data.status_class}`;
        }
        
        // Update actions dropdown
        const actionsDropdown = document.querySelector(`#invoice-${invoiceId} .actions-dropdown`);
        if (actionsDropdown) {
          actionsDropdown.innerHTML = data.actions_html;
        }
        
        // Show success message
        showNotification(data.message, 'success');
      } else {
        showNotification(data.message || 'Error updating invoice', 'error');
      }
    })
    .catch(error => {
      console.error('Error:', error);
      showNotification('Network error occurred', 'error');
    });
  }
  
  // Handle invoice archiving without page reload
  function archiveInvoice(invoiceId, tab = null) {
    const url = `/invoices/${invoiceId}/archive`;
    const data = { tab: tab };
    
    fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify(data)
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        // Remove invoice from current table
        const invoiceRow = document.querySelector(`#invoice-${invoiceId}`);
        if (invoiceRow) {
          invoiceRow.style.transition = 'opacity 0.3s';
          invoiceRow.style.opacity = '0';
          setTimeout(() => invoiceRow.remove(), 300);
        }
        
        // Update counts if available
        updateInvoiceCounts();
        
        showNotification(data.message, 'success');
      } else {
        showNotification(data.message || 'Error archiving invoice', 'error');
      }
    })
    .catch(error => {
      console.error('Error:', error);
      showNotification('Network error occurred', 'error');
    });
  }
  
  // Show notification toast
  function showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `alert alert-${type === 'error' ? 'danger' : type} notification-toast`;
    notification.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      z-index: 9999;
      min-width: 300px;
      opacity: 0;
      transform: translateX(100%);
      transition: all 0.3s ease;
    `;
    notification.textContent = message;
    
    document.body.appendChild(notification);
    
    // Animate in
    setTimeout(() => {
      notification.style.opacity = '1';
      notification.style.transform = 'translateX(0)';
    }, 10);
    
    // Auto remove after 3 seconds
    setTimeout(() => {
      notification.style.opacity = '0';
      notification.style.transform = 'translateX(100%)';
      setTimeout(() => notification.remove(), 300);
    }, 3000);
  }
  
  // Update invoice counts
  function updateInvoiceCounts() {
    const counts = document.querySelectorAll('.invoice-count');
    counts.forEach(count => {
      const current = parseInt(count.textContent);
      if (!isNaN(current) && current > 0) {
        count.textContent = current - 1;
      }
    });
  }
  
  // Attach event listeners to action buttons
  function attachActionListeners() {
    // Status update buttons
    document.querySelectorAll('[data-action="update-status"]').forEach(button => {
      button.addEventListener('click', function(e) {
        e.preventDefault();
        const invoiceId = this.dataset.invoiceId;
        const newStatus = this.dataset.status;
        const tab = this.dataset.tab;
        updateInvoiceStatus(invoiceId, newStatus, tab);
      });
    });
    
    // Archive buttons
    document.querySelectorAll('[data-action="archive"]').forEach(button => {
      button.addEventListener('click', function(e) {
        e.preventDefault();
        const invoiceId = this.dataset.invoiceId;
        const tab = this.dataset.tab;
        if (confirm('Are you sure you want to archive this invoice?')) {
          archiveInvoice(invoiceId, tab);
        }
      });
    });
  }
  
  // Initialize listeners
  attachActionListeners();
  
  // Re-attach listeners after Turbo navigation
  document.addEventListener('turbo:render', attachActionListeners);
});

// Stimulus controller for invoice actions
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "actions"]
  
  updateStatus(event) {
    event.preventDefault();
    const invoiceId = this.element.dataset.invoiceId;
    const newStatus = event.params.status;
    const tab = event.params.tab;
    
    // Dispatch custom event for the main handler
    this.dispatch('statusUpdate', {
      detail: { invoiceId, newStatus, tab }
    });
  }
  
  archive(event) {
    event.preventDefault();
    const invoiceId = this.element.dataset.invoiceId;
    const tab = event.params.tab;
    
    if (confirm('Are you sure you want to archive this invoice?')) {
      // Dispatch custom event for the main handler
      this.dispatch('archive', {
        detail: { invoiceId, tab }
      });
    }
  }
}
