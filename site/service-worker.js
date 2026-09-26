const CACHE='scan-open-site-v1';
const ASSETS=['./','index.html','styles.css','link-policy.js','app.js','icon.svg','manifest.webmanifest'];
self.addEventListener('install',event=>event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(ASSETS)).then(()=>self.skipWaiting())));
self.addEventListener('activate',event=>event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(key=>key!==CACHE).map(key=>caches.delete(key)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',event=>{if(event.request.method!=='GET')return;event.respondWith(caches.match(event.request).then(cached=>cached||fetch(event.request).then(response=>{if(new URL(event.request.url).origin===location.origin){const copy=response.clone();caches.open(CACHE).then(cache=>cache.put(event.request,copy));}return response;})))});
