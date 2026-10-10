// OmniSMS Service Worker - PWA Native
// IMPORTANT : mettre à jour CACHE_VERSION à chaque déploiement pour invalider l'ancien cache
const CACHE_VERSION = 'v5.3.0-google-web-callback';
const CACHE_NAME = `omnisms-${CACHE_VERSION}`;
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

// Activation : supprime TOUS les anciens caches (noms différents de CACHE_NAME)
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys
          .filter((key) => key !== CACHE_NAME)
          .map((key) => {
            console.log('[SW] Suppression ancien cache :', key);
            return caches.delete(key);
          })
      );
    }).then(() => self.clients.claim())
  );
});

// Fetch : Network-first pour HTML/JS/CSS (toujours la dernière version),
//         Cache-first pour images/fonts (assets immuables)
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Laisse passer les requêtes vers l'API backend sans cache
  if (url.hostname === 'omnisms-backend.onrender.com') {
    event.respondWith(fetch(event.request));
    return;
  }

  // Network-first pour les fichiers principaux de l'application
  const isAppFile = ['/index.html', '/app.js', '/style.css', '/manifest.json', '/sw.js', '/'].some(
    (path) => url.pathname === path || url.pathname === ''
  );

  if (isAppFile || event.request.mode === 'navigate') {
    // Network-first : récupère toujours la version serveur, fallback cache si hors-ligne
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          if (!response || response.status !== 200 || response.type === 'opaque') {
            return response;
          }
          const toCache = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, toCache));
          return response;
        })
        .catch(() => {
          // Hors-ligne : utiliser le cache
          return caches.match(event.request).then((cached) => {
            if (cached) return cached;
            if (event.request.mode === 'navigate') {
              return caches.match('/index.html');
            }
          });
        })
    );
    return;
  }

  // Cache-first pour les assets statiques (images, icônes, fonts)
  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) return cached;

      return fetch(event.request).then((response) => {
        if (!response || response.status !== 200 || response.type === 'opaque') {
          return response;
        }
        const toCache = response.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(event.request, toCache));
        return response;
      }).catch(() => {
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
