// Skeleton Loader Transition Utility
// Smoothly cross-fades from a skeleton placeholder to the rendered content

export function hideSkeleton(skeletonId, contentId, duration = 200) {
  const skeleton = typeof skeletonId === 'string' ? document.getElementById(skeletonId) : skeletonId;
  const content = typeof contentId === 'string' ? document.getElementById(contentId) : contentId;

  if (content) {
    if (content.style.display === 'none') {
      content.style.display = '';
    }
    content.classList.add('skeleton-fade-in');
  }

  if (skeleton) {
    skeleton.classList.add('skeleton-fade-out');
    setTimeout(() => {
      skeleton.style.display = 'none';
      skeleton.classList.remove('skeleton-fade-out');
    }, duration);
  }
}

// Global safety fallback: if any skeleton is still visible after 1200ms, reveal content
export function setupSkeletonSafetyFallback(pairs = []) {
  setTimeout(() => {
    pairs.forEach(([sId, cId]) => {
      const skeleton = document.getElementById(sId);
      const content = document.getElementById(cId);
      if (skeleton && skeleton.style.display !== 'none' && content && content.style.display === 'none') {
        hideSkeleton(skeleton, content, 150);
      }
    });
  }, 1200);
}

