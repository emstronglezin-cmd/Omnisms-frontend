// Firebase Cloud Messaging Service Worker — stub
// Firebase n'est pas initialisé dans cette version.
// Ce fichier est gardé pour compatibilité mais ne fait rien.

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', () => self.clients.claim());

console.log('[firebase-messaging-sw.js] SW stub initialized (Firebase not configured)');
