// OmniSMS Service Worker - PWA Native
const CACHE_NAME = 'omnisms-v1';
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/style.css',
  '/app.js',
  '/manifest.json',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png'
];

// Installation : pré-cache les assets statiques
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(STATIC_ASSETS);
    }).then(() => self.skipWaiting())
  );
});

// Activation : supprime les anciens caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys
          .filter((key) => key !== CACHE_NAME)
          .map((key) => caches.delete(key))
      );
    }).then(() => self.clients.claim())
  );
});

// Fetch : Cache-first pour les assets statiques, network-first pour l'API
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Laisse passer les requêtes vers l'API backend sans cache
  if (url.hostname === 'omnisms-backend.onrender.com') {
    event.respondWith(fetch(event.request));
    return;
  }

  // Cache-first pour les assets statiques
  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) return cached;

      return fetch(event.request).then((response) => {
        // Ne cache que les réponses valides
        if (!response || response.status !== 200 || response.type === 'opaque') {
          return response;
        }
        const toCache = response.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(event.request, toCache));
        return response;
      }).catch(() => {
        // Fallback : retourner index.html pour les navigations
        if (event.request.mode === 'navigate') {
          return caches.match('/index.html');
        }
      });
    })
  );
});

// Push notifications (futur)
self.addEventListener('push', (event) => {
  if (!event.data) return;
  try {
    const data = event.data.json();
    self.registration.showNotification(data.title || 'OmniSMS', {
      body: data.body || '',
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      tag: 'omnisms-notification'
    });
  } catch (e) {
    // ignore
  }
});
