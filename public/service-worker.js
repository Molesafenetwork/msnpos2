const CACHE_NAME = 'msn-invoice-app-v1.1';
const urlsToCache = [
  '/',
  '/css/styles.css',
  '/js/theme.js',
  '/images/invoice-icon-192.png',
  '/images/invoice-icon-512.png'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(urlsToCache))
  );
});

self.addEventListener('fetch', event => {
  event.respondWith(
    caches.match(event.request)
      .then(response => response || fetch(event.request))
  );
});