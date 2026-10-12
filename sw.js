// Route2 offline helper. Keeps copies of the planner's own files; never stores calls or settings.
const CACHE = "route2";
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", e => e.waitUntil(self.clients.claim()));
self.addEventListener("fetch", e => {
  const r = e.request;
  if (r.method !== "GET") return;
  const u = new URL(r.url);
  if (u.origin !== location.origin || u.pathname.endsWith("version.json")) return;
  e.respondWith((async () => {
    try {
      const net = await fetch(r);
      if (net.ok) { const c = await caches.open(CACHE); c.put(r, net.clone()); }
      return net;
    } catch (err) {
      const hit = await caches.match(r, { ignoreSearch: true });
      if (hit) return hit;
      throw err;
    }
  })());
});
