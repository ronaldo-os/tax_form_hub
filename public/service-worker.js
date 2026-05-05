// Tax Form Hub - Service Worker
// Provides PWA functionality: asset caching, offline fallback, background sync

const CACHE_NAME = 'tfh-cache-v2'
const STATIC_ASSETS = [
  '/',
  '/manifest.json',
  '/icon.png',
  '/icon.svg',
  '/assets/application.js',
  '/assets/application.css',
  '/assets/critical.css'
]

// Install event - cache static assets
self.addEventListener('install', (event) => {
  console.log('[Service Worker] Installing...')

  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('[Service Worker] Caching static assets')
        return cache.addAll(STATIC_ASSETS)
      })
      .then(() => {
        console.log('[Service Worker] Skip waiting')
        return self.skipWaiting()
      })
      .catch((error) => {
        console.error('[Service Worker] Cache failed:', error)
      })
  )
})

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  console.log('[Service Worker] Activating...')

  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames
            .filter((name) => name !== CACHE_NAME)
            .map((name) => {
              console.log('[Service Worker] Deleting old cache:', name)
              return caches.delete(name)
            })
        )
      })
      .then(() => {
        console.log('[Service Worker] Claiming clients')
        return self.clients.claim()
      })
  )
})

// Fetch event - cache strategies
self.addEventListener('fetch', (event) => {
  const { request } = event
  const url = new URL(request.url)

  // Skip non-GET requests
  if (request.method !== 'GET') {
    return
  }

  // Skip browser extensions and chrome-extension URLs
  if (url.protocol !== 'http:' && url.protocol !== 'https:') {
    return
  }

  // Strategy 1: Cache First for static assets (JS, CSS, images, fonts)
  if (isStaticAsset(url.pathname)) {
    event.respondWith(cacheFirst(request))
    return
  }

  // Strategy 2: Network First for API calls
  if (url.pathname.startsWith('/api/') || request.headers.get('Accept')?.includes('application/json')) {
    event.respondWith(networkFirst(request))
    return
  }

  // Strategy 3: Stale While Revalidate for HTML pages
  if (request.mode === 'navigate' || request.headers.get('Accept')?.includes('text/html')) {
    event.respondWith(staleWhileRevalidate(request))
    return
  }

  // Default: Network with cache fallback
  event.respondWith(networkWithCacheFallback(request))
})

// Helper: Check if URL is a static asset
function isStaticAsset(pathname) {
  const staticExtensions = ['.js', '.css', '.png', '.jpg', '.jpeg', '.gif', '.svg', '.woff', '.woff2', '.ttf', '.eot']
  return staticExtensions.some(ext => pathname.endsWith(ext))
}

// Cache First strategy - serve from cache, fall back to network
async function cacheFirst(request) {
  const cached = await caches.match(request)

  if (cached) {
    return cached
  }

  try {
    const response = await fetch(request)
    if (response.ok) {
      const cache = await caches.open(CACHE_NAME)
      cache.put(request, response.clone())
    }
    return response
  } catch (error) {
    console.error('[Service Worker] Cache first failed:', error)
    return new Response('Offline - Asset unavailable', { status: 503 })
  }
}

// Network First strategy - try network, fall back to cache
async function networkFirst(request) {
  try {
    const networkResponse = await fetch(request)

    if (networkResponse.ok) {
      const cache = await caches.open(CACHE_NAME)
      cache.put(request, networkResponse.clone())
    }

    return networkResponse
  } catch (error) {
    console.log('[Service Worker] Network failed, trying cache...')
    const cached = await caches.match(request)

    if (cached) {
      return cached
    }

    return new Response(JSON.stringify({ error: 'Offline' }), {
      status: 503,
      headers: { 'Content-Type': 'application/json' }
    })
  }
}

// Stale While Revalidate strategy - serve cache immediately, update in background
async function staleWhileRevalidate(request) {
  const cached = await caches.match(request)

  // Fetch update in background
  const fetchPromise = fetch(request)
    .then((networkResponse) => {
      if (networkResponse.ok) {
        // Clone the response before consuming it
        const responseToCache = networkResponse.clone()
        caches.open(CACHE_NAME).then((cache) => {
          cache.put(request, responseToCache)
        })
      }
      return networkResponse
    })
    .catch((error) => {
      console.log('[Service Worker] Background fetch failed:', error)
    })

  // Return cached version immediately if available
  if (cached) {
    return cached
  }

  // Otherwise wait for network
  try {
    return await fetchPromise
  } catch (error) {
    // Return offline fallback page
    return caches.match('/offline.html')
  }
}

// Network with cache fallback
async function networkWithCacheFallback(request) {
  try {
    return await fetch(request)
  } catch (error) {
    const cached = await caches.match(request)
    if (cached) {
      return cached
    }
    throw error
  }
}

// Background sync for offline form submissions
self.addEventListener('sync', (event) => {
  if (event.tag === 'sync-forms') {
    event.waitUntil(syncFormSubmissions())
  }
})

async function syncFormSubmissions() {
  // This would sync any queued form submissions when back online
  console.log('[Service Worker] Syncing queued form submissions...')
}

// Push notification support (future enhancement)
self.addEventListener('push', (event) => {
  if (event.data) {
    const data = event.data.json()
    const options = {
      body: data.body,
      icon: '/icon.png',
      badge: '/icon.png',
      tag: data.tag || 'default',
      requireInteraction: true
    }

    event.waitUntil(
      self.registration.showNotification(data.title, options)
    )
  }
})

// Notification click handler
self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  event.waitUntil(
    clients.openWindow('/')
  )
})
