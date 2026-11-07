import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
for(const script of ['analyze.mjs','index-source.mjs']){
  const r=spawnSync(process.execPath,[path.join(root,'tools',script)],{encoding:'utf8'});
  assert.equal(r.status,0,r.stderr);process.stdout.write(r.stdout);
}
const get=p=>JSON.parse(fs.readFileSync(path.join(root,'reports',p),'utf8'));
const inventory=get('binary/inventory.json'), binaries=get('binary/mach-o.json'), plists=get('binary/decoded-plists.json');
const eevee=Object.entries(binaries).find(([p])=>p.endsWith('/EeveeSpotify.dylib'))[1].slices[0];
const pw=Object.entries(binaries).find(([p])=>p.endsWith('/spotifyglass.dylib'))[1].slices[0];
assert.equal(pw.cpu,0x100000c);assert.equal(eevee.cpu,0x100000c);
assert.equal(pw.build.minOS,'16.0.0');assert.equal(eevee.build.minOS,'14.0.0');
for(const [p,plist]of Object.entries(plists))if(p.endsWith('Spotify.plist')||p.endsWith('spotifyglass.plist'))assert.deepEqual(plist.Filter.Bundles,['com.spotify.client']);
assert(eevee.deps.some(d=>d.name==='@rpath/Orion.framework/Orion'));
assert(eevee.imports.some(s=>s.library==='@rpath/Orion.framework/Orion'&&!s.weak));
assert.equal(Object.entries(binaries).find(([p])=>p.endsWith('/EeveeSwiftProtobuf'))[1].slices.length,2);
assert.equal(Object.keys(plists).filter(p=>p.endsWith('Localizable.strings')).length,27);
assert(Object.values(inventory).flat().every(f=>f.stagedCopyMatches));
// Independently compare current input bytes to the original staging manifest.
const manifest=fs.readFileSync(path.join(root,'..','unified-staging','manifest.csv'),'utf8').replace(/^\uFEFF/,'').trim().split(/\r?\n/).slice(1);
for(const line of manifest){
  const cols=[...line.matchAll(/"((?:[^"]|"")*)"/g)].map(m=>m[1].replaceAll('""','"'));
  assert.equal(cols.length,4);const bytes=fs.readFileSync(path.join(root,'..',cols[0]));
  assert.equal(bytes.length,Number(cols[1]));assert.equal(crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase(),cols[2]);
}
const checks={result:'PASS',manifestFilesChecked:manifest.length,checks:['47 source hashes against previous manifest','47 staged-copy hashes','both Spotify bundle filters','ARM64 Mach-O headers and deployment targets','Orion dependency and required imports','two framework architectures','27 localization dictionaries'],runtimeFeaturesTested:0,unifiedBuildTested:false,installationTested:false};
fs.writeFileSync(path.join(root,'reports','host-verification.json'),JSON.stringify(checks,null,2)+'\n');console.log(JSON.stringify(checks,null,2));
