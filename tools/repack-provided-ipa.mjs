import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
const source=path.resolve(process.argv[2]??'C:/Users/Acer/Downloads/EeveeSpotify-7.0.0-9.1.88.ipa');
const root=path.resolve('unified-spotify/ipa-analysis'),cleanSource=process.argv.includes('--no-eevee'),copy=path.join(root,cleanSource?'no-eevee':'clean-base');
const input=fs.readFileSync(source);let end=input.length-22;
while(end>=Math.max(0,input.length-65557)&&input.readUInt32LE(end)!==0x06054b50)end--;
assert(end>=0);assert.equal(input.readUInt16LE(end+4),0);assert.equal(input.readUInt16LE(end+6),0);
const count=input.readUInt16LE(end+10),centralOffset=input.readUInt32LE(end+16),entries=[];
let p=centralOffset;
for(let i=0;i<count;i++){
  assert.equal(input.readUInt32LE(p),0x02014b50);
  const nameLength=input.readUInt16LE(p+28),extra=input.readUInt16LE(p+30),comment=input.readUInt16LE(p+32),length=46+nameLength+extra+comment;
  const name=input.toString('utf8',p+46,p+46+nameLength);
  assert(!name.startsWith('/')&&!name.includes('\\')&&!name.split('/').includes('..'));
  entries.push({name,central:Buffer.from(input.subarray(p,p+length)),offset:input.readUInt32LE(p+42)});p+=length;
}
const byOffset=[...entries].sort((a,b)=>a.offset-b.offset);
for(let i=0;i<byOffset.length;i++)byOffset[i].end=i+1<byOffset.length?byOffset[i+1].offset:centralOffset;
const exclude=name=>['Payload/Spotify.app/Frameworks/EeveeSpotify.dylib','Payload/Spotify.app/Frameworks/EeveeSwiftProtobuf.framework/','Payload/Spotify.app/Frameworks/Orion.framework/','Payload/Spotify.app/Frameworks/CydiaSubstrate.framework/'].some(x=>x.endsWith('/')?(name===x.slice(0,-1)||name.startsWith(x)):name===x);
// Flip only the explicit app compatibility-mode flag on the new copy.
const infoPath=path.join(copy,'Payload/Spotify.app/Info.plist'),oldInfo=fs.readFileSync(infoPath,'utf8');
assert(/<key>UIDesignRequiresCompatibility<\/key>\s*<true\s*\/>/.test(oldInfo));
const newInfo=oldInfo.replace(/(<key>UIDesignRequiresCompatibility<\/key>\s*)<true\s*\/>/,'$1<false/>');
fs.writeFileSync(infoPath,newInfo);
const modified=new Map([['Payload/Spotify.app/Info.plist',Buffer.from(newInfo)]]);
if(!cleanSource)modified.set('Payload/Spotify.app/Spotify',fs.readFileSync(path.join(copy,'Payload/Spotify.app/Spotify')));
const table=Array.from({length:256},(_,n)=>{let c=n;for(let i=0;i<8;i++)c=c&1?0xedb88320^(c>>>1):c>>>1;return c>>>0;});
const crc32=bytes=>{let c=0xffffffff;for(const byte of bytes)c=table[(c^byte)&255]^(c>>>8);return (c^0xffffffff)>>>0;};
fs.mkdirSync(path.join(root,'outputs'),{recursive:true});
const basename=cleanSource?'Spotify-9.1.88-NoEevee-GlassInput':'Spotify-9.1.88-input-no-original-Eevee';
const output=path.join(root,'outputs/'+basename+'.ipa'),fd=fs.openSync(output,'wx');
let offset=0;const records=[],excluded=[];
try{
  for(const entry of byOffset){
    if(exclude(entry.name)){excluded.push(entry.name);continue;}
    const central=entry.central;central.writeUInt32LE(offset,42);
    let chunks;
    if(modified.has(entry.name)){
      assert.equal(input.readUInt32LE(entry.offset),0x04034b50);
      const nameLength=input.readUInt16LE(entry.offset+26),extraLength=input.readUInt16LE(entry.offset+28);
      const local=Buffer.from(input.subarray(entry.offset,entry.offset+30+nameLength+extraLength));
      const body=modified.get(entry.name),compressed=zlib.deflateRawSync(body,{level:6}),crc=crc32(body);
      const flags=input.readUInt16LE(entry.offset+6)&~8;assert(!(flags&1));
      local.writeUInt16LE(flags,6);local.writeUInt16LE(8,8);local.writeUInt32LE(crc,14);
      local.writeUInt32LE(compressed.length,18);local.writeUInt32LE(body.length,22);
      central.writeUInt16LE(flags,8);central.writeUInt16LE(8,10);central.writeUInt32LE(crc,16);
      central.writeUInt32LE(compressed.length,20);central.writeUInt32LE(body.length,24);
      chunks=[local,compressed];
    }else chunks=[input.subarray(entry.offset,entry.end)];
    for(const chunk of chunks){fs.writeSync(fd,chunk);offset+=chunk.length;}
    records.push(central);
  }
  const start=offset;for(const record of records){fs.writeSync(fd,record);offset+=record.length;}
  const comment=input.subarray(end+22,end+22+input.readUInt16LE(end+20)),eocd=Buffer.alloc(22);
  eocd.writeUInt32LE(0x06054b50);eocd.writeUInt16LE(records.length,8);eocd.writeUInt16LE(records.length,10);
  eocd.writeUInt32LE(offset-start,12);eocd.writeUInt32LE(start,16);eocd.writeUInt16LE(comment.length,20);
  fs.writeSync(fd,eocd);fs.writeSync(fd,comment);
}finally{fs.closeSync(fd);}
const report={originalIPA:source,originalSHA256:crypto.createHash('sha256').update(input).digest('hex'),output,
  outputSHA256:crypto.createHash('sha256').update(fs.readFileSync(output)).digest('hex'),outputEntries:records.length,excludedEntries:excluded,
  originalModesAndCompressedEntriesPreserved:true,modifiedEntries:[...modified.keys()],UIDesignRequiresCompatibility:false,
  requiresResigning:true,notPristineAppStoreIPA:true,newUnifiedTweakInjected:false,deviceTested:false};
fs.writeFileSync(path.join(root,'outputs/'+basename+'.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({output,outputEntries:records.length,excludedEntries:excluded.length,sha256:report.outputSHA256,requiresResigning:true},null,2));
