import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {macho} from './binary-formats.mjs';
const dir=path.resolve(process.argv[2]??'unified-spotify/ipa-analysis/clean-base');
const reference=path.resolve('unified-spotify/ipa-analysis/extracted/Payload/Spotify.app/Spotify');
const executable=path.join(dir,'Payload/Spotify.app/Spotify');
const b=fs.readFileSync(executable),original=fs.readFileSync(reference);
assert(b.equals(original),'Expected a fresh extracted copy, not a previously patched executable');
const info=macho(b).slices[0];assert.equal(info.cpu,0x100000c);
const unwanted=['@rpath/EeveeSpotify.dylib','@rpath/EeveeSwiftProtobuf.framework/EeveeSwiftProtobuf'];
const ordinals=info.deps.flatMap((d,i)=>unwanted.includes(d.name)?[i+1]:[]);
assert.equal(ordinals.length,2);
assert(!info.imports.some(s=>ordinals.includes(s.ordinal)),'Injected dependencies unexpectedly supply imported symbols');
let fixups=null;
for(let i=0,o=32;i<b.readUInt32LE(16);i++){
  const c=b.readUInt32LE(o);if(c===0x80000034)fixups=b.readUInt32LE(o+8);
  o+=b.readUInt32LE(o+4);
}
const importCounts={};
if(fixups!==null){
  const start=fixups+b.readUInt32LE(fixups+8),count=b.readUInt32LE(fixups+16),format=b.readUInt32LE(fixups+20);
  assert([1,2,3].includes(format),'Unsupported chained import table');
  for(let i=0;i<count;i++){
    const p=start+i*(format===1?4:format===2?8:16);
    let ordinal=format===3?Number(b.readBigUInt64LE(p)&65535n):(b.readUInt32LE(p)&255);
    if(format===3&&ordinal>=32768)ordinal-=65536;else if(format!==3&&ordinal>=128)ordinal-=256;
    importCounts[ordinal]=(importCounts[ordinal]??0)+1;
    assert(!ordinals.includes(ordinal),'Chained import binds to an injected dependency');
  }
}
const replacement='/usr/lib/libobjc.A.dylib',changes=[];
// Preserve the number/order/size of dylib commands and every original binding
// ordinal. The injected, unreferenced weak loads become redundant loads of the
// existing ObjC runtime. Removing commands would unnecessarily shift ordinals.
for(let i=0,o=32;i<b.readUInt32LE(16);i++){
  const c=b.readUInt32LE(o),size=b.readUInt32LE(o+4);
  if((c&0x7fffffff)===24){
    const start=o+b.readUInt32LE(o+8),end=b.indexOf(0,start),name=b.toString('utf8',start,end);
    if(unwanted.includes(name)){
      assert(Buffer.byteLength(replacement)+1<=o+size-start);
      b.fill(0,start,o+size);b.write(replacement,start,'utf8');changes.push({from:name,to:replacement,loadCommandOffset:o});
    }
  }
  o+=size;
}
assert.equal(changes.length,2);
const parsed=macho(b).slices[0];assert(!parsed.deps.some(d=>unwanted.includes(d.name)));
assert.equal(parsed.deps.length,info.deps.length);assert.equal(b.length,original.length);
// Ensure there are no body changes outside the two dependency-name slots.
const differences=[];for(let i=0;i<b.length;i++)if(b[i]!==original[i])differences.push(i);
assert(differences.every(i=>changes.some(c=>i>=c.loadCommandOffset&&i<c.loadCommandOffset+original.readUInt32LE(c.loadCommandOffset+4))));
fs.writeFileSync(executable,b);
const excluded=['Payload/Spotify.app/Frameworks/EeveeSpotify.dylib','Payload/Spotify.app/Frameworks/EeveeSwiftProtobuf.framework/',
  'Payload/Spotify.app/Frameworks/Orion.framework/','Payload/Spotify.app/Frameworks/CydiaSubstrate.framework/'];
const activeBinaries=[];
function walk(directory){for(const item of fs.readdirSync(directory,{withFileTypes:true})){
  const file=path.join(directory,item.name),rel=path.relative(dir,file).replaceAll('\\','/');
  if(item.isDirectory()){if(!excluded.includes(rel+'/'))walk(file);continue;}
  if(excluded.includes(rel))continue;
  const fd=fs.openSync(file,'r'),header=Buffer.alloc(4),read=fs.readSync(fd,header,0,4,0);fs.closeSync(fd);
  if(read!==4||![0xcffaedfe,0xcafebabe].includes(header.readUInt32BE(0)))continue;
  const image=macho(fs.readFileSync(file));
  for(const s of image.slices)assert(!s.deps.some(d=>/EeveeSpotify\.dylib|EeveeSwiftProtobuf\.framework|Orion\.framework|CydiaSubstrate\.framework/.test(d.name)),`Remaining dependency in ${rel}`);
  activeBinaries.push(rel);
}}
walk(path.join(dir,'Payload'));
const hash=value=>crypto.createHash('sha256').update(value).digest('hex');
const report={scope:'Provided IPA transformed into a separate unsigned input base for Sideloadly; not a unified app',changes,changedBytes:differences.length,
  originalExecutableSHA256:hash(original),preparedExecutableSHA256:hash(b),activeBinaries,excludedFromOutput:excluded,
  dylibOrdinalsPreserved:true,originalImportsIntoInjectedLibraries:0,signatureNowInvalidated:true,requiresResigning:true,
  retainedOriginalInfoAndResources:true,deviceTested:false};
fs.writeFileSync(path.join(dir,'PREPARATION.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));
