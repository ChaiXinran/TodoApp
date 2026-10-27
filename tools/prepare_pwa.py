"""Generate an atomic offline application cache from the finished web build."""
import hashlib, json
from pathlib import Path
root=Path(__file__).resolve().parent.parent/'build'/'web'
if not (root/'main.dart.js').is_file():raise SystemExit('Run flutter build web first')
excluded={'sw.js','flutter_service_worker.js','.nojekyll','_headers','CNAME'}
files=sorted(p for p in root.rglob('*') if p.is_file() and p.name not in excluded and not p.name.endswith(('.map','.deps')))
digest=hashlib.sha256(b''.join(str(p.relative_to(root)).encode()+hashlib.sha256(p.read_bytes()).digest() for p in files)).hexdigest()[:16]
urls=['./'+p.relative_to(root).as_posix() for p in files]
worker='''const CACHE = 'richang-pwa-__VERSION__';
const FILES = __FILES__;
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
'''.replace('__VERSION__',digest).replace('__FILES__',json.dumps(urls,ensure_ascii=False))
(root/'sw.js').write_text(worker,encoding='utf-8')
(root/'.nojekyll').touch()
(root/'_headers').write_text('/*\n  X-Content-Type-Options: nosniff\n  Referrer-Policy: strict-origin-when-cross-origin\n/sw.js\n  Cache-Control: no-cache\n/index.html\n  Cache-Control: no-cache\n/flutter_bootstrap.js\n  Cache-Control: no-cache\n',encoding='utf-8')
print(json.dumps({'cache':digest,'precache_files':len(files),'bytes':sum(p.stat().st_size for p in files)}))
