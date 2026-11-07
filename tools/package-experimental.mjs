import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const input=process.argv[2];
if(!input)throw new Error('Supply a genuinely compiled ARM64 Mach-O dylib');
const binary=fs.readFileSync(input);
if(binary.length<32||binary.readUInt32LE(0)!==0xfeedfacf||binary.readUInt32LE(4)!==0x100000c||binary.readUInt32LE(12)!==6)
  throw new Error('Expected thin ARM64 Mach-O MH_DYLIB');
function tar(entries){
  const chunks=[];
  for(const [name,data,mode]of entries){
    const bytes=Buffer.isBuffer(data)?data:Buffer.from(data);
    const header=Buffer.alloc(512);
    const text=(s,offset,length)=>header.write(s,offset,length,'ascii');
    const octal=(n,offset,length)=>text(n.toString(8).padStart(length-1,'0')+'\0',offset,length);
    if(Buffer.byteLength(name)>100)throw new Error('Tar path too long');
    text(name,0,100);octal(mode,100,8);octal(0,108,8);octal(0,116,8);
    octal(bytes.length,124,12);octal(0,136,12);header.fill(32,148,156);
    text('0',156,1);text('ustar\0',257,6);text('00',263,2);text('root',265,32);text('wheel',297,32);
    const checksum=header.reduce((a,b)=>a+b,0);
    text(checksum.toString(8).padStart(6,'0')+'\0 ',148,8);
    chunks.push(header,bytes,Buffer.alloc((512-bytes.length%512)%512));
  }
  return Buffer.concat([...chunks,Buffer.alloc(1024)]);
}
function arMember(name,bytes){
  const header=(name+'/').padEnd(16)+'0'.padEnd(12)+'0'.padEnd(6)+'0'.padEnd(6)+'100644'.padEnd(8)+String(bytes.length).padEnd(10)+'`\n';
  return Buffer.concat([Buffer.from(header),bytes,...(bytes.length%2?[Buffer.from('\n')]:[])]);
}
const control=`Package: local.unifiedspotify.personaltest\nName: Unified Spotify Personal Test\nVersion: 0.3.0~test1\nArchitecture: iphoneos-arm\nMaintainer: Local private integration project\nSection: Tweaks\nDescription: Spotify 9.1.88 private integration: settings/sidebar entry, native glass row, Eevee bootstrap/config transforms, feed filtering and utilities. Full Chroma player and lyrics integration is incomplete.\nDepends: firmware (>= 27.0)\n`;
const plist=`<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0"><dict><key>Filter</key><dict><key>Bundles</key><array><string>com.spotify.client</string></array></dict></dict></plist>\n`;
const entries=[
  ['Library/MobileSubstrate/DynamicLibraries/UnifiedSpotifyExperimental.dylib',binary,0o755],
  ['Library/MobileSubstrate/DynamicLibraries/UnifiedSpotifyExperimental.plist',plist,0o644],
  ['usr/share/doc/local.unifiedspotify.personaltest/COPYING',fs.readFileSync(path.join(root,'Licenses/EeveeSpotify-GPL-3.0.txt')),0o644],
  ['usr/share/doc/local.unifiedspotify.personaltest/SwiftProtobuf-LICENSE.txt',fs.readFileSync(path.join(root,'build/core-ios/protobuf/SwiftProtobuf-LICENSE.txt')),0o644]
];
const deb=Buffer.concat([Buffer.from('!<arch>\n'),arMember('debian-binary',Buffer.from('2.0\n')),
  arMember('control.tar.gz',zlib.gzipSync(tar([['control',control,0o644]]))),
  arMember('data.tar.gz',zlib.gzipSync(tar(entries)))]);
const output=path.join(root,'build/experimental/UnifiedSpotify-Personal_0.3.0-test1.deb');
fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,deb);
const manifest={scope:'PERSONAL STAGED INTEGRATION: settings/sidebar, native glass settings row, original Eevee bootstrap/config transforms, feed and utilities; full Chroma player/lyrics/lock-screen integration incomplete',buildRevision:'personal-sidebar-v4-9188',spotify:'9.1.88',minimumIOS:'27.0',
  protobufSourceCommit:fs.readFileSync(path.join(root,'build/core-ios/protobuf/protobuf-source-commit.txt'),'utf8').trim(),
  configurationSnapshots:['resolveconfiguration.bnk','resolveconfiguration_9_1_76.bnk'].map(name=>({name,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(root,'Resources/Configuration',name))).digest('hex')})),
  missingFeatureGroups:['Full unified Liquid Glass redesign','Chroma player','Lyrics providers and karaoke','Animated lock-screen artwork','Live Activity','DSP','Complete Premium/session/ad-service hooks','SponsorBlock'],
  debSHA256:crypto.createHash('sha256').update(deb).digest('hex'),dylibSHA256:crypto.createHash('sha256').update(binary).digest('hex'),
  files:entries.map(([name,data,mode])=>({name,bytes:Buffer.byteLength(data),mode:mode.toString(8)})),runtimeTested:false};
fs.writeFileSync(path.join(path.dirname(output),'package-manifest.json'),JSON.stringify(manifest,null,2)+'\n');
console.log(output);
