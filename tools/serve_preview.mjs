import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
const root=path.resolve('build');
const types={'.html':'text/html;charset=utf-8','.js':'application/javascript','.json':'application/json','.wasm':'application/wasm','.png':'image/png','.jpg':'image/jpeg','.ttf':'font/ttf','.otf':'font/otf','.css':'text/css'};
http.createServer((req,res)=>{
  let url=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
  if(url==='/__verify'||url==='/__production'){
    res.writeHead(302,{'Location':'/','Set-Cookie':`richang_validation=${url==='/__verify'?'1':'0'}; Path=/; SameSite=Lax`});res.end();return;
  }
  const validation=(req.headers.cookie||'').includes('richang_validation=1');
  const folder=path.join(root,validation?'validation':'web');
  const file=path.resolve(folder,'.'+(url==='/'?'/index.html':url));
  if(!file.startsWith(folder+path.sep)){res.writeHead(403);res.end();return;}
  if(!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404);res.end('Not found');return;}
  res.writeHead(200,{'Content-Type':types[path.extname(file)]||'application/octet-stream','Cache-Control':'no-store'});
  fs.createReadStream(file).pipe(res);
}).listen(8765,'127.0.0.1',()=>console.log('PWA preview http://127.0.0.1:8765'));
