/* 정적 앱 셸.

   install 에서 cache:"reload" 로 받는다. 그냥 addAll 하면 브라우저 HTTP 캐시에
   있던 옛 응답을 그대로 집어넣어서, CACHE 이름만 바뀌고 내용은 어제 것인
   캐시가 만들어진다. 실제로 그 일이 있었다 - 배포해도 폰에 안 갔다.

   문서(navigate)는 network-first 다. 배포가 "다음 다음 실행"이 아니라 바로
   다음 실행에 닿는다. 오프라인이면 캐시로 떨어진다.
   나머지(그림, manifest)는 cache-first - 바뀌는 일이 거의 없다. */
var CACHE = "agit-v9";
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
    return Promise.all(FILES.map(function (u) {
      return fetch(new Request(u, { cache: "reload" })).then(function (res) {
        if (res && res.ok) { return c.put(u, res); }
      }).catch(function () { /* 하나 실패해도 설치는 끝낸다 */ });
    }));
  }).then(function () { return self.skipWaiting(); }));
});

self.addEventListener("activate", function (e) {
  e.waitUntil(caches.keys().then(function (ks) {
    return Promise.all(ks.map(function (k) { return k === CACHE ? null : caches.delete(k); }));
  }).then(function () { return self.clients.claim(); }));
});

self.addEventListener("fetch", function (e) {
  if (e.request.method !== "GET") return;

  if (e.request.mode === "navigate") {
    e.respondWith(fetch(e.request).then(function (res) {
      var copy = res.clone();
      caches.open(CACHE).then(function (c) { c.put(e.request, copy); });
      return res;
    }).catch(function () {
      return caches.match(e.request).then(function (hit) {
        return hit || caches.match("./");
      });
    }));
    return;
  }

  e.respondWith(caches.match(e.request).then(function (hit) {
    return hit || fetch(e.request);
  }));
});
