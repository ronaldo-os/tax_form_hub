// PDF Preview Auto-fit, Scaling & Zoom Manager for Invoices / Quotes / Credit Notes

let currentZoomMode = 'fit';
let userScaleFactor = 1.0;
let animationFrameId = null;
let containerResizeObserver = null;
let cardResizeObserver = null;

/**
 * Calculates and applies the scale transform to center and fit the preview card.
 */
export function doUpdateScale() {
  const modalEl = document.getElementById('invoicePreviewModal');
  if (!modalEl) return;

  const container = modalEl.querySelector('.pdf-preview-container');
  const wrapper = modalEl.querySelector('.pdf-preview-wrapper');
  const card = modalEl.querySelector('#invoice_card');
  const zoomLevel = modalEl.querySelector('.pdf-zoom-level');
  let scaler = modalEl.querySelector('.pdf-preview-scaler');

  if (!container || !wrapper || !card) return;

  // Ensure scaler wrapper exists
  if (!scaler && wrapper.parentElement === container) {
    scaler = document.createElement('div');
    scaler.className = 'pdf-preview-scaler';
    container.insertBefore(scaler, wrapper);
    scaler.appendChild(wrapper);
  }

  // Calculate available container width (excluding horizontal padding and scrollbars)
  const computedStyle = window.getComputedStyle(container);
  const paddingX = parseFloat(computedStyle.paddingLeft || '0') + parseFloat(computedStyle.paddingRight || '0');
  const availableWidth = Math.floor(container.clientWidth - paddingX);

  if (availableWidth <= 0) return;

  const cardWidth = 800; // Fixed canvas width for standard paper sheet

  // Calculate base scale to fit available viewport width (capped at 1.0)
  let baseScale = availableWidth / cardWidth;
  if (baseScale > 1) baseScale = 1;
  baseScale = Math.max(0.2, baseScale);

  let finalScale = baseScale;
  if (currentZoomMode === 'fit') {
    finalScale = baseScale;
    if (zoomLevel) {
      zoomLevel.textContent = `${Math.round(baseScale * 100)}% (Fit)`;
    }
  } else {
    finalScale = userScaleFactor;
    if (zoomLevel) {
      zoomLevel.textContent = `${Math.round(finalScale * 100)}%`;
    }
  }

  finalScale = Math.round(finalScale * 1000) / 1000;

  // Measure card height accurately
  const cardHeight = card.offsetHeight || 1000;
  const scaledWidth = Math.round(cardWidth * finalScale);
  const scaledHeight = Math.round(cardHeight * finalScale);

  // Apply scale transform to wrapper
  wrapper.style.transform = `scale(${finalScale})`;
  wrapper.style.transformOrigin = 'top left';
  wrapper.style.width = `${cardWidth}px`;
  wrapper.style.height = `${cardHeight}px`;

  // Apply scaled dimensions to scaler
  scaler.style.width = `${scaledWidth}px`;
  scaler.style.height = `${scaledHeight}px`;

  // Align left if sheet overflows available width to allow smooth horizontal panning
  // Otherwise remain centered with auto margins
  const isOverflowing = scaledWidth > availableWidth;
  if (isOverflowing) {
    container.classList.add('is-overflowing');
    container.classList.add('is-zoomed');
  } else {
    container.classList.remove('is-overflowing');
    container.classList.remove('is-zoomed');
  }
}

/**
 * Debounced scale update using requestAnimationFrame.
 */
export function scheduleScaleUpdate() {
  if (animationFrameId) {
    cancelAnimationFrame(animationFrameId);
  }
  animationFrameId = requestAnimationFrame(() => {
    doUpdateScale();
  });
}

/**
 * Public trigger to update scale and reset mode to 'fit'.
 */
export function updatePdfPreviewScale() {
  currentZoomMode = 'fit';
  userScaleFactor = 1.0;
  scheduleScaleUpdate();

  // Schedule extra ticks to catch async image rendering and modal fade transitions
  setTimeout(scheduleScaleUpdate, 50);
  setTimeout(scheduleScaleUpdate, 150);
  setTimeout(scheduleScaleUpdate, 300);

  // Attach image load listeners to handle delayed loading (e.g. logos, attachments)
  attachImageLoadListeners();
  setupObservers();
}

// Make globally accessible on window for compatibility with inline/existing calls
window.updatePdfPreviewScale = updatePdfPreviewScale;

function attachImageLoadListeners() {
  const modalEl = document.getElementById('invoicePreviewModal');
  if (!modalEl) return;
  const images = modalEl.querySelectorAll('#invoice_card img');
  images.forEach(img => {
    if (!img.complete) {
      img.addEventListener('load', scheduleScaleUpdate, { once: true });
      img.addEventListener('error', scheduleScaleUpdate, { once: true });
    }
  });
}

function setupObservers() {
  const modalEl = document.getElementById('invoicePreviewModal');
  if (!modalEl || typeof ResizeObserver === 'undefined') return;

  const container = modalEl.querySelector('.pdf-preview-container');
  const card = modalEl.querySelector('#invoice_card');

  if (container && (!containerResizeObserver || containerResizeObserver.target !== container)) {
    if (containerResizeObserver) containerResizeObserver.disconnect();
    containerResizeObserver = new ResizeObserver(() => scheduleScaleUpdate());
    containerResizeObserver.observe(container);
    containerResizeObserver.target = container;
  }

  if (card && (!cardResizeObserver || cardResizeObserver.target !== card)) {
    if (cardResizeObserver) cardResizeObserver.disconnect();
    cardResizeObserver = new ResizeObserver(() => scheduleScaleUpdate());
    cardResizeObserver.observe(card);
    cardResizeObserver.target = card;
  }
}

function cleanupObservers() {
  if (containerResizeObserver) {
    containerResizeObserver.disconnect();
    containerResizeObserver = null;
  }
  if (cardResizeObserver) {
    cardResizeObserver.disconnect();
    cardResizeObserver = null;
  }
}

/**
 * Initialize event listeners for the Invoice Preview Modal.
 */
export function initPdfPreviewManager() {
  const $modal = $('#invoicePreviewModal');
  if (!$modal.length) return;

  // Zoom In button
  $(document).off('click.pdf_zoom_in', '#invoicePreviewModal .pdf-zoom-in')
             .on('click.pdf_zoom_in', '#invoicePreviewModal .pdf-zoom-in', function (e) {
    e.preventDefault();
    const container = document.querySelector('#invoicePreviewModal .pdf-preview-container');
    const availableWidth = container ? (container.clientWidth - 16) : 360;
    const baseScale = Math.min(1, availableWidth / 800);

    if (currentZoomMode === 'fit') {
      userScaleFactor = Math.min(2.5, Math.round((baseScale + 0.2) * 100) / 100);
    } else {
      userScaleFactor = Math.min(2.5, Math.round((userScaleFactor + 0.25) * 100) / 100);
    }
    currentZoomMode = 'custom';
    scheduleScaleUpdate();
  });

  // Zoom Out button
  $(document).off('click.pdf_zoom_out', '#invoicePreviewModal .pdf-zoom-out')
             .on('click.pdf_zoom_out', '#invoicePreviewModal .pdf-zoom-out', function (e) {
    e.preventDefault();
    const container = document.querySelector('#invoicePreviewModal .pdf-preview-container');
    const availableWidth = container ? (container.clientWidth - 16) : 360;
    const baseScale = Math.min(1, availableWidth / 800);

    if (currentZoomMode === 'fit') {
      userScaleFactor = Math.max(0.3, Math.round((baseScale - 0.15) * 100) / 100);
    } else {
      userScaleFactor = Math.max(0.3, Math.round((userScaleFactor - 0.25) * 100) / 100);
    }
    currentZoomMode = 'custom';
    scheduleScaleUpdate();
  });

  // Zoom Fit button
  $(document).off('click.pdf_zoom_fit', '#invoicePreviewModal .pdf-zoom-fit')
             .on('click.pdf_zoom_fit', '#invoicePreviewModal .pdf-zoom-fit', function (e) {
    e.preventDefault();
    currentZoomMode = 'fit';
    userScaleFactor = 1.0;
    scheduleScaleUpdate();
  });

  // Window resize listener
  $(window).off('resize.pdf_preview').on('resize.pdf_preview', function () {
    scheduleScaleUpdate();
  });

  // Modal shown listener
  $(document).off('shown.bs.modal.pdf_preview', '#invoicePreviewModal')
             .on('shown.bs.modal.pdf_preview', '#invoicePreviewModal', function () {
    updatePdfPreviewScale();
  });

  // Modal hidden listener
  $(document).off('hidden.bs.modal.pdf_preview', '#invoicePreviewModal')
             .on('hidden.bs.modal.pdf_preview', '#invoicePreviewModal', function () {
    currentZoomMode = 'fit';
    userScaleFactor = 1.0;
    cleanupObservers();
    const container = document.querySelector('#invoicePreviewModal .pdf-preview-container');
    if (container) {
      container.classList.remove('is-overflowing', 'is-zoomed');
    }
  });

  // Two-finger pinch-to-zoom for touch screens
  let initialPinchDistance = 0;
  let pinchStartScale = 1.0;
  let isPinching = false;

  function getTouchDistance(e) {
    if (!e.touches || e.touches.length < 2) return 0;
    const dx = e.touches[0].clientX - e.touches[1].clientX;
    const dy = e.touches[0].clientY - e.touches[1].clientY;
    return Math.hypot(dx, dy);
  }

  $(document).off('touchstart.pdf_pinch', '#invoicePreviewModal .pdf-preview-container')
             .on('touchstart.pdf_pinch', '#invoicePreviewModal .pdf-preview-container', function (e) {
    const touchEvent = e.originalEvent || e;
    if (touchEvent.touches && touchEvent.touches.length === 2) {
      isPinching = true;
      initialPinchDistance = getTouchDistance(touchEvent);

      const container = document.querySelector('#invoicePreviewModal .pdf-preview-container');
      const availableWidth = container ? (container.clientWidth - 16) : 360;
      const baseScale = Math.min(1, availableWidth / 800);

      pinchStartScale = (currentZoomMode === 'fit') ? baseScale : userScaleFactor;
    }
  });

  $(document).off('touchmove.pdf_pinch', '#invoicePreviewModal .pdf-preview-container')
             .on('touchmove.pdf_pinch', '#invoicePreviewModal .pdf-preview-container', function (e) {
    const touchEvent = e.originalEvent || e;
    if (isPinching && touchEvent.touches && touchEvent.touches.length === 2) {
      touchEvent.preventDefault();

      const currentDistance = getTouchDistance(touchEvent);
      if (initialPinchDistance > 0 && currentDistance > 0) {
        const pinchRatio = currentDistance / initialPinchDistance;
        const calculatedScale = parseFloat((pinchStartScale * pinchRatio).toFixed(2));

        userScaleFactor = Math.min(2.5, Math.max(0.3, calculatedScale));
        currentZoomMode = 'custom';
        scheduleScaleUpdate();
      }
    }
  });

  $(document).off('touchend.pdf_pinch touchcancel.pdf_pinch', '#invoicePreviewModal .pdf-preview-container')
             .on('touchend.pdf_pinch touchcancel.pdf_pinch', '#invoicePreviewModal .pdf-preview-container', function (e) {
    const touchEvent = e.originalEvent || e;
    if (!touchEvent.touches || touchEvent.touches.length < 2) {
      isPinching = false;
      initialPinchDistance = 0;
    }
  });
}

// Auto-initialize when file is imported
initPdfPreviewManager();
document.addEventListener('turbo:load', initPdfPreviewManager);
