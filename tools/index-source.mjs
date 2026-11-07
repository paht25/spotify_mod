import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const out=path.join(root,'reports','source');fs.mkdirSync(out,{recursive:true});
const write=(name,data)=>fs.writeFileSync(path.join(out,name),JSON.stringify(data,null,2)+'\n');
function files(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.name==='.git'?[]:e.isDirectory()?files(path.join(dir,e.name)):[path.join(dir,e.name)]);}
const hooks=[],settings=[],activation=[],modules=[],dependencies=[];
for(const [source,dir,sourceRoot]of [['Chroma','Chroma-reference','tweak/Sources'],['EeveeSpotify','EeveeSpotify','Sources']]){
  const base=path.join(root,'upstream',dir);
  for(const file of files(path.join(base,sourceRoot))){
    if(!/\.(?:x|m|mm|h|swift|c|metal)$/.test(file))continue;
    const text=fs.readFileSync(file,'utf8'),lines=text.split(/\r?\n/),rel=path.relative(base,file).replaceAll('\\','/');
    modules.push({source,file:rel,lines:lines.length,role:'Source file; not proof of runtime activation'});
    let current=null,group=null;
    for(let i=0;i<lines.length;i++){
      const line=lines[i], loc={source,file:rel,line:i+1};
      const gm=line.match(/^\s*%group\s+(\w+)/);if(gm)group=gm[1];
      const lg=line.match(/^\s*%hook\s+(\w+)/);
      const sw=line.match(/^\s*(?:(?:private|final|public|internal|open)\s+)*class\s+(\w+)\s*:\s*ClassHook<([^>]+)>/);
      if(lg||sw){current={...loc,kind:lg?'Logos':'Orion',hookClass:lg?lg[1]:sw[1],target:lg?lg[1]:sw[2],group,methods:[],targetResolution:lg?'source literal':'generic type; inspect targetName/target overrides',runtimeStatus:'NOT TESTED'};hooks.push(current);}
      if(current){
        const target=line.match(/static\s+(?:let|var)\s+targetName\s*(?::\s*String)?\s*=\s*"([^"]+)"/);
        if(target){current.target=target[1];current.targetResolution='source targetName literal';}
        const g=line.match(/typealias\s+Group\s*=\s*(\w+)/);if(g)current.group=g[1];
        if(/^\s*[+-]\s*\(/.test(line)||/^\s*(?:(?:override|class|static|final|private|public)\s+)*func\s+/.test(line))current.methods.push({line:i+1,declaration:line.trim(),caveat:'Textual declaration candidate; inspect full source for selector, %new, helper or conditional activation'});
        if(/^\s*%end\b/.test(line))current=null;
      }
      for(const m of line.matchAll(/(?:@)?"((?:spotifyglass\.|eevee)[a-zA-Z0-9_.-]+)"/g))settings.push({...loc,key:m[1],evidence:'literal key candidate',runtimeStatus:'NOT TESTED',integrationStatus:'NOT INTEGRATED'});
      for(const m of line.matchAll(/(?:let|var)\s+(\w*Key)\s*=\s*"([^"]+)"/g))settings.push({...loc,key:m[2],symbol:m[1],evidence:'named key constant candidate',runtimeStatus:'NOT TESTED',integrationStatus:'NOT INTEGRATED'});
      if(/%ctor|%init\b|\.activate\(|\.install\(|func activate\w+|if .*UserDefaults|if .*SG(?:Native|Redesigned)/.test(line))activation.push({...loc,text:line.trim()});
      if(/^\s*(?:import |#import [<"])/.test(line))dependencies.push({...loc,text:line.trim()});
    }
  }
}
const collisions=[];
for(const a of hooks.filter(h=>h.source==='Chroma'))for(const b of hooks.filter(h=>h.source==='EeveeSpotify'))if(a.target===b.target&&a.target!=='NSObject')collisions.push({target:a.target,Chroma:{file:a.file,line:a.line,group:a.group},EeveeSpotify:{file:b.file,line:b.line,group:b.group},status:'SHARED SOURCE TARGET; selector and activation reconciliation REQUIRED'});
const csv=(name,rows)=>{const cols=Object.keys(rows[0]??{});fs.writeFileSync(path.join(out,name),[cols.join(','),...rows.map(r=>cols.map(k=>'"'+String(r[k]??'').replaceAll('"','""')+'"').join(','))].join('\n')+'\n');};
write('hook-declarations.json',hooks);write('settings-literals.json',settings);write('activation-evidence.json',activation);write('source-files.json',modules);write('import-evidence.json',dependencies);write('shared-hook-targets.json',collisions);
csv('feature-verification.csv',settings);csv('shared-hook-targets.csv',collisions.map(c=>({target:c.target,chromaFile:c.Chroma.file,chromaLine:c.Chroma.line,eeveeFile:c.EeveeSpotify.file,eeveeLine:c.EeveeSpotify.line,status:c.status})));
const summary={sourceFiles:modules.length,hookDeclarations:hooks.length,sharedTargetPairs:collisions.length,settingLiteralOccurrences:settings.length,activationEvidence:activation.length,caveat:'Lexical index, not an AST or proof of binary/source equivalence. Swift methods after a hook declaration may include later helpers; dynamic targets/swizzles and generated selectors require manual review.'};write('summary.json',summary);console.log(JSON.stringify(summary,null,2));
