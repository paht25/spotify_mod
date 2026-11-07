import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const dir=path.resolve(process.argv[2]??'unified-spotify/received-artifact');
const manifest=JSON.parse(fs.readFileSync(path.join(dir,'package-manifest.json'),'utf8'));
const deb=fs.readFileSync(path.join(dir,'UnifiedSpotify-FeedTest_0.1.0-test1.deb'));
const dylib=fs.readFileSync(path.join(dir,'UnifiedSpotifyExperimental.dylib'));
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
assert.equal(sha(deb),manifest.debSHA256);assert.equal(sha(dylib),manifest.dylibSHA256);
assert.equal(deb.toString('ascii',0,8),'!<arch>\n');
const ar=new Map();
for(let o=8;o<deb.length;){
  assert.equal(deb.toString('ascii',o+58,o+60),'`\n');
  const name=deb.toString('ascii',o,o+16).trim().replace(/\/$/,''),size=Number(deb.toString('ascii',o+48,o+58).trim());
  assert(Number.isSafeInteger(size)&&size>=0&&o+60+size<=deb.length);
  assert(!ar.has(name));ar.set(name,deb.subarray(o+60,o+60+size));o+=60+size+(size%2);
}
assert.deepEqual([...ar.keys()],['debian-binary','control.tar.gz','data.tar.gz']);
assert.equal(ar.get('debian-binary').toString(),'2.0\n');
function tar(bytes){
  const entries=new Map();
  for(let o=0;o+512<=bytes.length;){
    const h=bytes.subarray(o,o+512);if(h.every(x=>x===0))break;
    const text=(p,n)=>h.toString('utf8',p,p+n).split('\0')[0];
    const name=text(0,100),size=parseInt(text(124,12).trim(),8),mode=parseInt(text(100,8).trim(),8);
    assert(!name.startsWith('/')&&!name.split('/').includes('..'));
    const expected=parseInt(text(148,8).trim(),8),copy=Buffer.from(h);copy.fill(32,148,156);
    assert.equal(copy.reduce((a,b)=>a+b,0),expected,'Tar header checksum');
    assert.equal(text(156,1),'0');assert(Number.isSafeInteger(size)&&size>=0&&o+512+size<=bytes.length);
    assert(!entries.has(name));entries.set(name,{data:bytes.subarray(o+512,o+512+size),mode});o+=512+Math.ceil(size/512)*512;
  }
  return entries;
}
const controlEntries=tar(zlib.gunzipSync(ar.get('control.tar.gz')));
assert.deepEqual([...controlEntries.keys()],['control']);
const control=controlEntries.get('control').data.toString();
assert(control.includes('Package: local.unifiedspotify.feedtest\n'));
const data=tar(zlib.gunzipSync(ar.get('data.tar.gz')));
assert.deepEqual([...data.keys()],manifest.files.map(f=>f.name));
for(const f of manifest.files){assert.equal(data.get(f.name).data.length,f.bytes);assert.equal(data.get(f.name).mode.toString(8),f.mode);}
assert(data.get('Library/MobileSubstrate/DynamicLibraries/UnifiedSpotifyExperimental.dylib').data.equals(dylib));
const filter=data.get('Library/MobileSubstrate/DynamicLibraries/UnifiedSpotifyExperimental.plist').data.toString();
assert(filter.includes('<key>Bundles</key><array><string>com.spotify.client</string></array>'));
assert.equal(dylib.readUInt32LE(0),0xfeedfacf);assert.equal(dylib.readUInt32LE(4),0x100000c);assert.equal(dylib.readUInt32LE(12),6);
const z=(o,end)=>dylib.toString('utf8',o,Math.min(dylib.indexOf(0,o),end));
const version=v=>`${v>>>16}.${(v>>>8)&255}.${v&255}`;
const dependencies=[],rpaths=[],initializerSections=[];let minimumOS,sdk,platform,signatureCommand=false;
for(let i=0,o=32;i<dylib.readUInt32LE(16);i++){
  const cmd=dylib.readUInt32LE(o),size=dylib.readUInt32LE(o+4),k=cmd&0x7fffffff;
  assert(size>=8&&o+size<=dylib.length);
  if([12,24,31,35].includes(k))dependencies.push({name:z(o+dylib.readUInt32LE(o+8),o+size),weak:k===24});
  if(k===28)rpaths.push(z(o+dylib.readUInt32LE(o+8),o+size));
  if(k===50){platform=dylib.readUInt32LE(o+8);minimumOS=version(dylib.readUInt32LE(o+12));sdk=version(dylib.readUInt32LE(o+16));}
  if(k===29){const start=dylib.readUInt32LE(o+8),length=dylib.readUInt32LE(o+12);assert(start+length<=dylib.length);signatureCommand=true;}
  if(k===25)for(let j=0;j<dylib.readUInt32LE(o+64);j++){
    const start=o+72+j*80,name=z(start,start+16);if(['__mod_init_func','__init_offsets'].includes(name))initializerSections.push(name);
  }
  o+=size;
}
assert.equal(platform,2);assert.equal(minimumOS,'27.0.0');assert(signatureCommand);assert(initializerSections.length>0);
assert(dependencies.every(d=>d.name.startsWith('/System/Library/')||d.name.startsWith('/usr/lib/')));
assert(dylib.includes(Buffer.from('_USAttachEeveeFeed\0')),'C bridge symbol string');
const result={status:'PASS_STATIC_CHECKS',debSHA256:sha(deb),dylibSHA256:sha(dylib),
  packagedDylibEqualsStandalone:true,tarChecksumsValid:true,fileModesMatchManifest:true,
  bundleFilter:'com.spotify.client',architecture:'arm64',platform:'iOS',minimumOS,sdk,
  dependencies,rpaths,initializerSections,embeddedCodeSignatureCommand:signatureCommand,
  signatureCryptographicallyVerified:false,deviceRuntimeTested:false,
  scope:'Experimental Eevee feed hook only; not full Chroma + Eevee integration',control};
fs.writeFileSync(path.join(dir,'STATIC-VERIFICATION.json'),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify(result,null,2));
