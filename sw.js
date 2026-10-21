/* Cache-first app shell. The whole game is static, so there is nothing to
   revalidate - but that also means a new version only reaches a phone that
   already has this installed when CACHE below changes. Bump it on every deploy.
   ponytail: no versioned filenames, bump CACHE by hand if that ever gets missed. */
var CACHE = "agit-v6";
var FILES = [
  "./",
  "./index.html",
  "./manifest.json",
  "./icon-180.png",
  "./icon-192.png",
  "./icon-512.png",
  "./art/bg-agit.png",
  "./art/bg-mine.png",
  "./art/bg-pasture.png",
  "./art/sprites/agit1-camp.png",
  "./art/sprites/agit2-cabin.png",
  "./art/sprites/agit3-farm.png",
  "./art/sprites/animal1-rabbit.png",
  "./art/sprites/animal2-goat.png",
  "./art/sprites/animal3-deer.png",
  "./art/sprites/char1-green.png",
  "./art/sprites/char2-blue.png",
  "./art/sprites/char3-pink.png",
  "./art/sprites/char4-lilac.png",
  "./art/sprites/char5-cream.png",
  "./art/sprites/char6-brown.png"
];

self.addEventListener("install", function (e) {
  e.waitUntil(caches.open(CACHE).then(function (c) {
    return c.addAll(FILES);
  }).then(function () { return self.skipWaiting(); }));
});

self.addEventListener("activate", function (e) {
  e.waitUntil(caches.keys().then(function (ks) {
    return Promise.all(ks.map(function (k) { return k === CACHE ? null : caches.delete(k); }));
  }).then(function () { return self.clients.claim(); }));
});

self.addEventListener("fetch", function (e) {
  if (e.request.method !== "GET") return;
  e.respondWith(caches.match(e.request).then(function (hit) {
    return hit || fetch(e.request);
  }));
});
