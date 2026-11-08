// Static UI preview only. The actual listener runs inside the iOS tweak.
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const html=fs.readFileSync(path.join(root,'Resources/Personal/WebDisplay.html'));
const server=http.createServer((request,response)=>{
  if(request.url!=='/'){response.writeHead(404);response.end();return;}
  response.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store'});response.end(html);
});
server.listen(0,'127.0.0.1',()=>console.log(`Static empty-state preview: http://127.0.0.1:${server.address().port}/`));
