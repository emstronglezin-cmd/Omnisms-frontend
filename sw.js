// OmniSMS Service Worker - root level (redirect to web/sw.js)
// This file is kept for compatibility - main SW is in web/sw.js

const CACHE_NAME = 'omnisms-root-sw-v1';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', () => self.clients.claim());
