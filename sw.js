const CACHE = 'richang-pwa-33c74f68ce148c1e';
const FILES = ["./.last_build_id", "./assets/AssetManifest.bin", "./assets/AssetManifest.bin.json", "./assets/assets/branding/cat_rabbit_heads.png", "./assets/assets/branding/richang_cover.png", "./assets/assets/branding/ycf.jpg", "./assets/assets/data/semester_2026_pwa.json", "./assets/assets/fonts/NotoEmoji.ttf", "./assets/assets/fonts/NotoSansSC.ttf", "./assets/assets/moods/angry.png", "./assets/assets/moods/anxious.png", "./assets/assets/moods/excited.png", "./assets/assets/moods/gentle.png", "./assets/assets/moods/happy.png", "./assets/assets/moods/sad.png", "./assets/assets/moods/stressed.png", "./assets/assets/moods/touched.png", "./assets/FontManifest.json", "./assets/fonts/fallback/Roboto-Regular.ttf", "./assets/fonts/MaterialIcons-Regular.otf", "./assets/NOTICES", "./assets/shaders/ink_sparkle.frag", "./assets/shaders/stretch_effect.frag", "./canvaskit/canvaskit.js", "./canvaskit/canvaskit.js.symbols", "./canvaskit/canvaskit.wasm", "./canvaskit/chromium/canvaskit.js", "./canvaskit/chromium/canvaskit.js.symbols", "./canvaskit/chromium/canvaskit.wasm", "./canvaskit/skwasm.js", "./canvaskit/skwasm.js.symbols", "./canvaskit/skwasm.wasm", "./canvaskit/skwasm_heavy.js", "./canvaskit/skwasm_heavy.js.symbols", "./canvaskit/skwasm_heavy.wasm", "./canvaskit/webparagraph/canvaskit.js", "./canvaskit/webparagraph/canvaskit.js.symbols", "./canvaskit/webparagraph/canvaskit.wasm", "./canvaskit/wimp.js", "./canvaskit/wimp.js.symbols", "./canvaskit/wimp.wasm", "./favicon.png", "./flutter.js", "./flutter_bootstrap.js", "./icons/apple-touch-icon.png", "./icons/Icon-192.png", "./icons/Icon-512.png", "./icons/Icon-maskable-512.png", "./index.html", "./licenses/NotoEmoji-OFL.txt", "./licenses/NotoSansSC-OFL.txt", "./licenses/SQLite-worker-BSD.txt", "./main.dart.js", "./manifest.json", "./sqflite_sw.js", "./sqlite3.wasm", "./version.json"];
const ROOT = new URL('./', self.location.href).href;
self.addEventListener('install', event => {
  event.waitUntil((async()=>{
    const cache = await caches.open(CACHE);
    for (let i=0;i<FILES.length;i+=12) await cache.addAll(FILES.slice(i,i+12));
  })());
});
self.addEventListener('activate', event=>event.waitUntil((async()=>{
  for(const key of await caches.keys()) if(key.startsWith('richang-pwa-')&&key!==CACHE) await caches.delete(key);
  await self.clients.claim();
})()));
// Updates wait for existing windows to close, avoiding mixed app versions.
self.addEventListener('fetch',event=>{
  const req=event.request;
  if(req.method!=='GET'||!req.url.startsWith(ROOT))return;
  event.respondWith((async()=>{
    const cache=await caches.open(CACHE);
    if(req.mode==='navigate')return (await cache.match(new URL('index.html',ROOT).href))||fetch(req);
    return (await cache.match(req,{ignoreSearch:true}))||fetch(req);
  })());
});
