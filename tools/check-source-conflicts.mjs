import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const root=process.argv[2]?path.resolve(process.argv[2]):path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const roots=['Sources','Tests','Integration/Chroma/tweak','Integration/Chroma/extension','Integration/Chroma/vendor/audio','scripts','tools','.github','Resources','target.json'];
const skip=new Set(['.git','.theos','build','__pycache__','node_modules']);
const extensions=new Set(['.h','.m','.mm','.c','.cc','.cpp','.swift','.x','.js','.mjs','.sh','.py','.ps1','.json','.yml','.yaml','.plist','.modulemap']);
const marker=/^(?:<{7,}(?: .*)?|>{7,}(?: .*)?|={7,}|\|{7,}(?: .*)?)$/;
let checked=0;
const conflicts=[];
function scan(file){
  if(!fs.existsSync(file))return;
  const stat=fs.lstatSync(file);
  if(stat.isSymbolicLink())return;
  if(stat.isDirectory()){
    if(skip.has(path.basename(file)))return;
    for(const entry of fs.readdirSync(file))scan(path.join(file,entry));
    return;
  }
  if(!extensions.has(path.extname(file)) && !['Makefile','control'].includes(path.basename(file)))return;
  checked++;
  fs.readFileSync(file,'utf8').replace(/^\uFEFF/,'').split(/\r?\n/).forEach((line,index)=>{
    if(marker.test(line))conflicts.push({file:path.relative(root,file).replaceAll('\\','/'),line:index+1,marker:line});
  });
}
for(const item of roots)scan(path.join(root,item));
if(conflicts.length){
  console.error('Build blocked: unresolved Git merge-conflict markers. Resolve the files and commit before rerunning.');
  for(const item of conflicts)console.error(`${item.file}:${item.line}: ${item.marker}`);
  process.exitCode=1;
}else console.log(`Source conflict preflight passed (${checked} source/configuration files).`);
