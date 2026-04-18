// Firebase Cloud Messaging Service Worker
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Configuration Firebase
firebase.initializeApp({
  apiKey: 'AIzaSyD3Yur6Q5IvcDI_bC9YuLFNC4jvgEREtBQ',
  authDomain: 'omnisms-b98c5.firebaseapp.com',
  projectId: 'omnisms-b98c5',
  storageBucket: 'omnisms-b98c5.firebasestorage.app',
  messagingSenderId: '948236796279',
  appId: '1:948236796279:android:747ba8ba81710da2ade172',
});

const messaging = firebase.messaging();

// Gérer les messages en arrière-plan
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  const notificationTitle = payload.notification?.title || 'OmniSMS';
  const notificationOptions = {
    body: payload.notification?.body || 'Nouveau message',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: payload.data?.type || 'default',
    data: payload.data,
    requireInteraction: false,
    vibrate: [200, 100, 200],
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Gérer les clics sur notifications
self.addEventListener('notificationclick', (event) => {
  console.log('[firebase-messaging-sw.js] Notification clicked', event);
  
  event.notification.close();

  // Déterminer l'URL selon le type de notification
  let url = '/';
  const data = event.notification.data;
  
  if (data) {
    if (data.type === 'message' && data.conversationId) {
      url = `/messages/${data.conversationId}`;
    } else if (data.type === 'group' && data.groupId) {
      url = `/groups/${data.groupId}`;
    } else if (data.url) {
      url = data.url;
    }
  }

  // Ouvrir ou focaliser la fenêtre
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        // Si une fenêtre est déjà ouverte, la focaliser
        for (const client of clientList) {
          if (client.url.includes(url) && 'focus' in client) {
            return client.focus();
          }
        }
        // Sinon, ouvrir une nouvelle fenêtre
        if (clients.openWindow) {
          return clients.openWindow(url);
        }
      })
  );
});

console.log('[firebase-messaging-sw.js] Service Worker initialized');
