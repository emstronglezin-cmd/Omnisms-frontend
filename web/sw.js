// OmniSMS Service Worker - Flutter Web PWA
// Version: 2.4.0

const CACHE_NAME = 'omnisms-v2.4.0';
const FLUTTER_CACHE = 'flutter-web-cache-v2.4.0';

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

// ── Push notifications (Web Push API — optionnel, gratuit) ──────────────────
// Ce handler est prêt pour recevoir des push notifications si une infrastructure
// Web Push (VAPID) est configurée côté serveur dans le futur.
// Actuellement : les notifications sont envoyées depuis l'app Flutter ouverte
// via la Browser Notification API (notification_web.dart).
// Ce handler permet les notifications en arrière-plan si un push server est ajouté.
self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {
    data = { title: 'OmniSMS', body: event.data ? event.data.text() : 'Nouveau message' };
  }

  const title          = data.title          || 'OmniSMS';
  const body           = data.body           || 'Vous avez un nouveau message';
  const conversationId = data.conversationId || '';
  const messageId      = data.messageId      || '';

  const options = {
    body : body,
    icon : '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag  : conversationId || 'omnisms-message',
    data : { conversationId, messageId, url: '/' },
    requireInteraction: false,
    silent: false,
  };

  event.waitUntil(
    self.registration.showNotification(title, options).catch((err) => {
      console.warn('[SW] Push notification error:', err);
    })
  );
});

// ── Notification click → ouvrir/focaliser l'application ────────────────────
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const conversationId = event.notification.data?.conversationId || '';
  const targetUrl = '/'; // toujours l'app principale

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clients) => {
      // Trouver un onglet OmniSMS déjà ouvert
      const existing = clients.find((c) => c.url.includes(self.location.origin));
      if (existing) {
        existing.focus();
        // Transmettre l'ID de conversation à l'app via postMessage
        if (conversationId) {
          existing.postMessage({
            type          : 'NOTIFICATION_CLICK',
            conversationId: conversationId,
          });
        }
        return;
      }
      // Sinon ouvrir un nouvel onglet
      return self.clients.openWindow(targetUrl);
    })
  );
});
