import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {deb} from './deb-format.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),out=path.join(root,'build/unified');
if(!process.argv[2])throw new Error('A genuinely compiled unified dylib is required');
const read=p=>fs.readFileSync(path.join(root,p)), binary=fs.readFileSync(process.argv[2]);
if(binary.length<32||binary.readUInt32LE(0)!==0xfeedfacf||binary.readUInt32LE(4)!==0x100000c||binary.readUInt32LE(12)!==6)
  throw new Error('Expected an actual thin ARM64 Mach-O MH_DYLIB');
// Prevent accidentally relabelling a previous small experiment as full Chroma.
for(const marker of ['USUnifiedComplete','SGRKaraokeView'])if(!binary.includes(Buffer.from(marker)))
  throw new Error(`Compiled image lacks required integration marker ${marker}`);
const plist=`<?xml version="1.0"?><plist version="1.0"><dict><key>Filter</key><dict><key>Bundles</key><array><string>com.spotify.client</string></array></dict></dict></plist>\n`;
const dir='Library/MobileSubstrate/DynamicLibraries/';
const files=[
  [dir+'spotifyglass.dylib',binary,0o755],[dir+'spotifyglass.plist',plist,0o644],
  [dir+'SpotifyGlassAppGroups.dylib',read('build/unified/SpotifyGlassAppGroups.dylib'),0o755],
  [dir+'SpotifyGlassAppGroups.plist',plist,0o644],
  ['usr/share/doc/local.unifiedspotify.chromaeevee/Chroma-LICENSE',read('Integration/Chroma/LICENSE'),0o644],
  ['usr/share/doc/local.unifiedspotify.chromaeevee/Eevee-COPYING',read('Licenses/EeveeSpotify-GPL-3.0.txt'),0o644],
  ['usr/share/doc/local.unifiedspotify.chromaeevee/Protobuf-LICENSE',read('build/core-ios/protobuf/SwiftProtobuf-LICENSE.txt'),0o644],
  ['usr/share/doc/local.unifiedspotify.chromaeevee/bs2b-COPYING',read('Integration/Chroma/vendor/audio/libbs2b/COPYING'),0o644],
  ['usr/share/doc/local.unifiedspotify.chromaeevee/WDL-LICENSE',read('Integration/Chroma/vendor/audio/wdl/LICENSE'),0o644]
];
const control=`Package: local.unifiedspotify.chromaeevee\nName: Unified Spotify Chroma + Eevee Private Test\nVersion: 0.4.0~test1\nArchitecture: iphoneos-arm\nMaintainer: Local private integration\nSection: Tweaks\nDescription: Full Chroma source plus selected Eevee configuration, feed and utility modules in one image. Not full Eevee parity; device verification required. IPA injection container; Live Activity requires the companion IPA assembly step.\nDepends: firmware (>= 27.0)\n`;
const bytes=deb(control,files);fs.mkdirSync(out,{recursive:true});fs.writeFileSync(path.join(out,'UnifiedSpotify-ChromaEevee_0.4.0-test1.deb'),bytes);
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
function walk(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?walk(path.join(dir,e.name)):[path.join(dir,e.name)]);}
const supportFiles=walk(path.join(out,'live-activity')).map(file=>({name:path.relative(out,file).replaceAll('\\','/'),sha256:hash(fs.readFileSync(file))}));
fs.writeFileSync(path.join(out,'package-manifest.json'),JSON.stringify({revision:'chroma-core-v5-9188',spotify:'9.1.88',build:'918802209',ios:'27',delivery:'Sideloadly IPA injection; not a rootless jailbreak installer',
  chromaSource:'425d68bc1761e90a6b5828864720511bcef79fa9',eeveeSource:'d1da1d69715935e41d1dc97a25d11bcc42ebd170',
  scope:'All Chroma source files included; selected Eevee transforms composed with Chroma delegates, not both original dylibs',
  fullEeveeParity:false,runtimeTested:false,supportFiles,liveActivity:'Built separately; assemble-personal-ipa.py must embed extension and host intents; signer must retain and sign extension',
  unresolved:['Eevee-only UI profile/options','Eevee-only lyrics providers and karaoke options','SponsorBlock/reporting','Remaining Eevee session/premium/ad-service hooks','Device compatibility and signing validation'],
  debSHA256:hash(bytes),files:files.map(([name,data,mode])=>({name,sha256:hash(data),bytes:Buffer.byteLength(data),mode:mode.toString(8)}))},null,2)+'\n');
console.log(path.join(out,'UnifiedSpotify-ChromaEevee_0.4.0-test1.deb'));
