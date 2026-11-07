import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const read=p=>fs.readFileSync(path.join(root,p));
const main=JSON.parse(read('ipa-analysis/spotify-9.1.90/objc-main.json'));
const shared=JSON.parse(read('ipa-analysis/spotify-9.1.90/objc-shared.json'));
assert.equal(main.errors.length,0);assert.equal(shared.errors.length,0);
const classes=new Map([...shared.classes,...main.classes].map(c=>[c.name,c]));
const walk=p=>fs.readdirSync(p,{withFileTypes:true}).flatMap(e=>e.isDirectory()?walk(path.join(p,e.name)):[path.join(p,e.name)]);
const base=path.join(root,'Integration/Chroma/tweak/Sources');
const declarations=walk(base).filter(f=>f.endsWith('.x')).flatMap(f=>[...fs.readFileSync(f,'utf8').matchAll(/%hook\s+((?:SPT|_TtC)\w+)/g)].map(m=>({file:path.relative(base,f).replaceAll('\\','/'),name:m[1],classPresent:classes.has(m[1])})));
const contracts={SPTCoreProductState:{'initWithValuesDict:scheduler:':'@32@0:8@16^{Scheduler=^^?}24','setOriginalValues:':'v24@0:8@16','setOverrides:':'v24@0:8@16','values':'@16@0:8','originalValues':'@16@0:8','stringForKey:':'@24@0:8@16','objectForKeyedSubscript:':'@24@0:8@16'},SPTAdsProductState:{adsEnabled:'B16@0:8'}};
const audioContracts=[];
for(const [name,methods] of Object.entries(contracts))for(const [selector,encoding] of Object.entries(methods)){
  const method=classes.get(name)?.methods?.find(m=>m.selector===selector);
  assert.equal(method?.encoding,encoding,`${name} ${selector}: reviewed ABI changed`);
  audioContracts.push({name,selector,encoding,implementationVM:method.implementationVM});
}
const binary=read('ipa-analysis/spotify-9.1.90/Payload/Spotify.app/Spotify');
const flags=new Set([...read('Generated/SGFlagList.m').toString().matchAll(/\{"([^"]+)", SGFlag/g)].map(m=>m[1]));
const redesignFlags=walk(path.join(base,'Redesigned')).flatMap(f=>[...fs.readFileSync(f,'utf8').matchAll(/@"(ios-[^"]+\.[^".][^"]*)"/g)].map(m=>({file:path.relative(base,f).replaceAll('\\','/'),key:m[1]})));
const missingFlagReferences=redesignFlags.filter(m=>!flags.has(m.key)).map(m=>({...m,rawUTF8StringPresent:binary.includes(Buffer.from(m.key)),caveat:'Retained original reference; cannot confirm equivalent behavior without version-specific runtime investigation'}));
const cryptids=[];
for(let i=0,o=32;i<binary.readUInt32LE(16);i++){
  const command=binary.readUInt32LE(o),size=binary.readUInt32LE(o+4);
  assert(size>=8 && o+size<=binary.length);
  if(command===0x21||command===0x2c)cryptids.push(binary.readUInt32LE(o+16));
  o+=size;
}
assert(cryptids.length>0 && cryptids.every(c=>c===0),'Input has not been confirmed decrypted');
const report={revision:'personal-v6-9190',spotify:'9.1.90',build:'919002269',binarySHA256:crypto.createHash('sha256').update(binary).digest('hex'),encryptionCryptIDs:cryptids,metadataErrors:0,
  hookDeclarations:declarations.length,classesPresent:declarations.filter(c=>c.classPresent).length,absent:declarations.filter(c=>!c.classPresent),audioContracts,missingFlagReferences,
  caveat:'Static class/ABI presence does not prove hook execution, UI behavior, server response compatibility or audible ad blocking. Legacy player morph remains unresolved.',runtimeTested:false};
fs.writeFileSync(path.join(root,'reports/target-v6-static.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));
