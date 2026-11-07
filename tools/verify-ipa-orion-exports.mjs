import fs from 'node:fs';
import {macho} from './binary-formats.mjs';
const base='unified-spotify/ipa-analysis/extracted/Payload/Spotify.app/Frameworks/';
const b=fs.readFileSync(base+'Orion.framework/Orion');let start,size;
for(let i=0,o=32;i<b.readUInt32LE(16);i++){
  const c=b.readUInt32LE(o);if(c===0x80000033){start=b.readUInt32LE(o+8);size=b.readUInt32LE(o+12);}
  if((c&0x7fffffff)===34&&start===undefined){start=b.readUInt32LE(o+40);size=b.readUInt32LE(o+44);}
  o+=b.readUInt32LE(o+4);
}
if(!size)throw new Error('Export trie unavailable; stripped symbol table alone is not conclusive');
const trie=b.subarray(start,start+size),exports=new Map();
function uleb(cursor){let value=0,shift=0;for(let n=0;n<8;n++){if(cursor.offset>=trie.length)throw new Error('Truncated ULEB');const byte=trie[cursor.offset++];value+=(byte&127)*2**shift;if(!(byte&128))return value;shift+=7;}throw new Error('Unsafe ULEB');}
function visit(offset,prefix,ancestors){
  if(offset>=trie.length||ancestors.has(offset))throw new Error('Invalid/cyclic export trie');
  const nextAncestors=new Set(ancestors);nextAncestors.add(offset);
  const cursor={offset},terminalSize=uleb(cursor),terminalStart=cursor.offset;
  if(terminalSize){const flags=uleb(cursor);exports.set(prefix,{flags,reexport:!!(flags&8)});}
  cursor.offset=terminalStart+terminalSize;if(cursor.offset>=trie.length)throw new Error('Missing child count');
  const count=trie[cursor.offset++];for(let i=0;i<count;i++){
    const end=trie.indexOf(0,cursor.offset);if(end<0)throw new Error('Missing export edge terminator');
    const edge=trie.toString('utf8',cursor.offset,end);cursor.offset=end+1;
    visit(uleb(cursor),prefix+edge,nextAncestors);
  }
}
visit(0,'',new Set());
const required=macho(fs.readFileSync(base+'EeveeSpotify.dylib')).slices[0].imports.filter(s=>!s.weak&&s.library?.includes('Orion.framework'));
const report={runtimeDeclaredVersion:'1.0.2',requiredSymbols:required.length,exportsInTrie:exports.size,
  requiredAbsentFromExportTrie:required.filter(s=>!exports.has(s.name)).map(s=>s.name),
  requiredReexports:required.filter(s=>exports.get(s.name)?.reexport).map(s=>s.name),
  caveat:'Export-name availability only, not Swift ABI execution, source commit identity or full loader validation. The normal symbol table is stripped and is not sufficient.'};
fs.writeFileSync('unified-spotify/ipa-analysis/reports/orion-symbol-comparison.json',JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
