// Skeleton Loader Transition Utility
// Performs an atomic, zero-shift swap from skeleton placeholder to rendered content

export function hideSkeleton(skeletonId, contentId, _duration = 0) {
  const skeleton = typeof skeletonId === 'string' ? document.getElementById(skeletonId) : skeletonId;
  const content = typeof contentId === 'string' ? document.getElementById(contentId) : contentId;

  if (!skeleton && !content) return;

  const skeletonWasVisible = skeleton && skeleton.style.display !== 'none';
  const contentWasHidden = content && content.style.display === 'none';

  // If skeleton is already gone and content is already visible, exit early to avoid redundant reflows
  if (!skeletonWasVisible && !contentWasHidden) return;

  // 1. Immediately remove skeleton from layout to eliminate dual-stacking & height doubling
  if (skeleton) {
    skeleton.style.display = 'none';
    skeleton.classList.remove('skeleton-fade-out');
  }

  // 2. Immediately reveal content in the exact same coordinates
  if (content) {
    if (contentWasHidden) {
      content.style.display = '';
    }

    // Apply quick opacity smoothing without any vertical translation
    content.classList.remove('skeleton-fade-in');
    void content.offsetWidth; // Force reflow so animation starts immediately
    content.classList.add('skeleton-fade-in');

    // 3. Adjust DataTables and responsive layouts immediately upon unhiding
    if (typeof $ !== 'undefined' && $.fn && $.fn.DataTable) {
      try {
        $(content).find('table.dataTable').each(function () {
          if ($.fn.DataTable.isDataTable(this)) {
            const dt = $(this).DataTable();
            dt.columns.adjust();
            if (dt.responsive && typeof dt.responsive.recalc === 'function') {
              dt.responsive.recalc();
            }
          }
        });
      } catch (e) {
        // Defensive: ignore any DataTable adjustment errors
      }
    }

    // Trigger window resize so Chart.js / canvas elements recalibrate dimensions immediately
    if (typeof window !== 'undefined') {
      window.dispatchEvent(new Event('resize'));
    }
  }
}

// Global safety fallback: if any skeleton is still visible after timeout, reveal content
export function setupSkeletonSafetyFallback(pairs = [], timeout = 800) {
  setTimeout(() => {
    if (Array.isArray(pairs)) {
      pairs.forEach(([sId, cId]) => {
        const skeleton = document.getElementById(sId);
        const content = document.getElementById(cId);
        if (skeleton && skeleton.style.display !== 'none' && content && content.style.display === 'none') {
          hideSkeleton(skeleton, content);
        }
      });
    }

    // Auto-detect and reveal any lingering skeleton placeholder on the current page
    document.querySelectorAll('[id$="_skeleton"]').forEach((skeleton) => {
      if (skeleton && skeleton.style.display !== 'none') {
        const baseId = skeleton.id.replace(/_skeleton$/, '');
        const content = document.getElementById(`${baseId}_content`);
        if (content && content.style.display === 'none') {
          hideSkeleton(skeleton, content);
        }
      }
    });
  }, timeout);
}

// Hook global fallback into Turbo and DOM lifecycle
if (typeof document !== 'undefined') {
  document.addEventListener('turbo:load', () => setupSkeletonSafetyFallback([], 800));
  document.addEventListener('DOMContentLoaded', () => setupSkeletonSafetyFallback([], 800));
}

