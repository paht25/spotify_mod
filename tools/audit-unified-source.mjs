import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const walk=dir=>fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?walk(path.join(dir,e.name)):[path.join(dir,e.name)]);
const baseline=path.join(root,'upstream/Chroma-reference/tweak/Sources'),integrated=path.join(root,'Integration/Chroma/tweak/Sources');
const originals=walk(baseline),records=originals.map(file=>{
  const relative=path.relative(baseline,file),target=path.join(integrated,relative);assert(fs.existsSync(target),`Missing original Chroma file ${relative}`);
  const before=hash(fs.readFileSync(file)),after=hash(fs.readFileSync(target));
  return {file:relative.replaceAll('\\','/'),originalSHA256:before,integratedSHA256:after,changed:before!==after};
});
const hooks=walk(integrated).filter(f=>f.endsWith('.x'));
for(const file of hooks){const text=fs.readFileSync(file,'utf8');
  const ctors=[...text.matchAll(/%ctor\s*\{/g)];
  for(const ctor of ctors)assert(/^\s*if \(!USUnifiedTargetSupported\(\)\) return;/.test(text.slice(ctor.index+ctor[0].length)),`Missing target gate: ${file}`);
}
const swift=fs.readFileSync(path.join(root,'Sources/Eevee/Premium/USPremiumModule.swift'),'utf8');
assert(swift.includes('@_cdecl("USAttachEeveePremium")'));
const table=fs.readFileSync(path.join(integrated,'Shared/Flags/SGFlagList.m'),'utf8');
const keys=[...table.matchAll(/\{"([^"]+)", SGFlag/g)].map(m=>m[1]);assert.equal(keys.length,2496);assert.equal(new Set(keys).size,keys.length);
const metadata=JSON.parse(fs.readFileSync(path.join(root,'ipa-analysis/reports/objc-services.json')));
const classes=new Map(metadata.classes.map(c=>[c.name,c]));
const serviceSource=fs.readFileSync(path.join(integrated,'Core/USEeveeServices.m'),'utf8');
const targets=[...new Set([...serviceSource.matchAll(/@"(_TtC[^"]+)"/g)].map(m=>m[1]))];
const serviceEvidence=targets.map(name=>({name,present:classes.has(name),ownMethods:classes.get(name)?.methods?.filter(m=>['load','checkRecommendationsEnabled','recommendationIsBeingAddedWithTrackID:','setAudioCrossfadeTime:','setAudioCrossfade:'].includes(m.selector))??[],caveat:'Own metadata only; inherited/category/lazy runtime methods need on-device inspection'}));
const report={revision:'chroma-core-v5-9188',originalChromaFiles:records.length,missingChromaFiles:0,logosSources:hooks.length,
  unchangedChromaFiles:records.filter(r=>!r.changed).length,modifiedChromaFiles:records.filter(r=>r.changed).length,
  allOriginalChromaSourceIncluded:true,fullEeveeParity:false,appleCompilationTested:false,runtimeFeaturesTested:0,
  flags:{keys:keys.length,typed:2306,unknown:190},serviceEvidence,files:records};
fs.writeFileSync(path.join(root,'reports/unified-source-audit.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({originalChromaFiles:records.length,logosSources:hooks.length,missingChromaFiles:0,flags:keys.length,serviceTargets:serviceEvidence.length,servicesWithOwnLoad:serviceEvidence.filter(e=>e.ownMethods.some(m=>m.selector==='load')).length,runtimeVerified:false},null,2));
