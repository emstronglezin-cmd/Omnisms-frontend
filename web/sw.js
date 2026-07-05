// OmniSMS Service Worker - Flutter Web PWA
// Version: 2.3.0

const CACHE_NAME = 'omnisms-v2.3.0';
const FLUTTER_CACHE = 'flutter-web-cache-v2.3.0';

// Assets Flutter essentiels à mettre en cache
const PRECACHE_URLS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/favicon.png',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
];

// Installation : précache les assets essentiels
self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(PRECACHE_URLS).catch((err) => {
        console.warn('[SW] Precache partiel:', err);
      });
    })
  );
});

// Activation : supprime les anciens caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames
          .filter((name) => name !== CACHE_NAME && name !== FLUTTER_CACHE)
          .map((name) => caches.delete(name))
      );
    }).then(() => self.clients.claim())
  );
});

// Stratégie fetch : Network first, cache fallback
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Ne pas intercepter les requêtes non-GET
  if (event.request.method !== 'GET') return;

  // Ne pas intercepter les requêtes vers le backend ou APIs externes
  if (
    url.hostname === 'omnisms-backend.onrender.com' ||
    url.hostname === 'firebaseinstallations.googleapis.com' ||
    url.hostname === 'fcmregistrations.googleapis.com' ||
    url.protocol === 'chrome-extension:'
  ) {
    return;
  }

  // Pour les assets Flutter (.js, .wasm, .woff2) : cache first
  if (
    url.pathname.endsWith('.js') ||
    url.pathname.endsWith('.wasm') ||
    url.pathname.endsWith('.woff2') ||
    url.pathname.endsWith('.png') ||
    url.pathname.endsWith('.jpg') ||
    url.pathname.includes('flutter_service_worker')
  ) {
    event.respondWith(
      caches.open(FLUTTER_CACHE).then(async (cache) => {
        const cached = await cache.match(event.request);
        if (cached) return cached;
        try {
          const response = await fetch(event.request);
          if (response.ok) cache.put(event.request, response.clone());
          return response;
        } catch {
          return cached || new Response('', { status: 503 });
        }
      })
    );
    return;
  }

  // Pour les pages HTML : network first, cache fallback
  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request).catch(() =>
        caches.match('/index.html')
      )
    );
    return;
  }
});
