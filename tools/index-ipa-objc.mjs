import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
// Static metadata reader, not a runtime class dump. Layout references:
// apple-oss-distributions/dyld include/mach-o/fixup-chains.h (format 6)
// apple-oss-distributions/objc4 runtime/objc-runtime-new.h (class_ro_t, method_list_t)
const input=process.argv[2],output=process.argv[3];
const focusIndex=process.argv.indexOf('--focus-pattern');
const extraFocus=focusIndex<0?null:new RegExp(process.argv[focusIndex+1]);
if(!input||!output)throw new Error('Usage: index-ipa-objc.mjs MachO output.json');
const b=fs.readFileSync(input);assert.equal(b.readUInt32LE(0),0xfeedfacf);
const z=(off,end=b.length)=>{if(off<0||off>=b.length)throw new Error('String outside image');const e=b.indexOf(0,off);if(end!==b.length)return b.toString('utf8',off,e<0||e>end?end:e);if(e<0)throw new Error('Unterminated string');return b.toString('utf8',off,e);};
const segments=[],sections=[];let fixupBase=null;
for(let i=0,o=32;i<b.readUInt32LE(16);i++){
  const c=b.readUInt32LE(o),n=b.readUInt32LE(o+4);assert(n>=8&&o+n<=b.length);
  if(c===25){
    const segment={name:z(o+8,o+24),vm:Number(b.readBigUInt64LE(o+24)),size:Number(b.readBigUInt64LE(o+32)),file:Number(b.readBigUInt64LE(o+40)),fileSize:Number(b.readBigUInt64LE(o+48)),format:0};segments.push(segment);
    for(let j=0;j<b.readUInt32LE(o+64);j++){const p=o+72+j*80;sections.push({name:z(p,p+16),vm:Number(b.readBigUInt64LE(p+32)),size:Number(b.readBigUInt64LE(p+40)),file:b.readUInt32LE(p+48)});}
  }
  if(c===0x80000034)fixupBase=b.readUInt32LE(o+8);
  o+=n;
}
const base=segments.find(s=>s.name==='__TEXT').vm;
if(fixupBase!==null){const starts=fixupBase+b.readUInt32LE(fixupBase+4);for(let i=0;i<b.readUInt32LE(starts);i++){const rel=b.readUInt32LE(starts+4+4*i);if(rel)segments[i].format=b.readUInt16LE(starts+rel+6);}}
function at(vm,size=1){const segment=segments.find(s=>s.fileSize&&vm>=s.vm&&vm+size<=s.vm+s.fileSize);if(!segment)throw new Error('VM address outside file-backed segments');return segment.file+vm-segment.vm;}
function pointer(vm,clearFlags=false){
  const off=at(vm,8),raw=b.readBigUInt64LE(off);if(!raw)return null;
  const segment=segments.find(s=>vm>=s.vm&&vm<s.vm+s.size);
  let value;
  if(segment.format===6||segment.format===2){
    if(raw>>63n)return null; // External bound pointer is not a local class.
    const high=(raw>>36n)&255n;if(high)throw new Error('Tagged high-byte pointer unsupported');
    value=Number(raw&0xfffffffffn)+(segment.format===6?base:0);
  }else if(segment.format===0)value=Number(raw);
  else throw new Error('Unsupported chained pointer format '+segment.format);
  return clearFlags?value-(value%8):value;
}
const str=vm=>vm===null?null:z(at(vm));
function methods(vm){
  if(vm===null)return [];
  const off=at(vm,8),flags=b.readUInt32LE(off),count=b.readUInt32LE(off+4),small=!!(flags&0x80000000),direct=!!(flags&0x40000000),size=flags&0xffff;
  if(count>10000||size!==(small?12:24))throw new Error('Unsupported method list encoding');
  const result=[];
  for(let i=0;i<count;i++){
    const entry=vm+8+i*size,p=at(entry,size);let name,type,imp;
    if(small){const ref=entry+b.readInt32LE(p);name=str(direct?ref:pointer(ref));type=str(entry+4+b.readInt32LE(p+4));imp=entry+8+b.readInt32LE(p+8);}
    else{name=str(pointer(entry));type=str(pointer(entry+8));imp=pointer(entry+16);}
    result.push({selector:name,encoding:type,implementationVM:imp?.toString(16),implementationFileOffset:imp===null?null:at(imp)});
  }
  return result;
}
function classRecord(vm,includeMethods){
  const ro=pointer(vm+32,true);if(ro===null)throw new Error('External class data');
  const name=str(pointer(ro+24)),superclassVM=pointer(vm+8);
  const record={name,classVM:vm.toString(16),superclassVM:superclassVM?.toString(16)};
  if(includeMethods)record.methods=methods(pointer(ro+32));
  return record;
}
const list=sections.find(s=>s.name==='__objc_classlist');if(!list)throw new Error('Class list absent');
const classes=[],errors=[];
for(let i=0;i<list.size;i+=8){
  try{
    const vm=pointer(list.vm+i);if(vm===null)continue;
    const record=classRecord(vm,false);classes.push(record);
    if(/SettingsListViewController|SideDrawer.*(ListViewController|ListCollectionView)|SPTDataLoaderService|HttpClientURLSession|NPVScrollViewController|StatefulPlayerImplementation|NowPlayingPlatformSwiftServiceImplementation|FullscreenElementViewController|SPTPlayerTrack|ProgressBar.*Slider|NowPlayingBarViewController/.test(record.name) || (process.argv.includes('--property-inits') && /Properties/.test(record.name)) || extraFocus?.test(record.name)){
      try{record.methods=methods(pointer(pointer(vm+32,true)+32));}catch(e){record.methodsError=e.message;}
    }
  }catch(e){errors.push({index:i/8,error:e.message});}
}
const byVM=new Map(classes.map(c=>[c.classVM,c.name]));for(const c of classes)if(c.superclassVM)c.superclass=byVM.get(c.superclassVM)??'External/unresolved';
const focused=classes.filter(c=>c.methods||c.methodsError);
const report={input:path.basename(input),baseVM:base.toString(16),pointerFormats:segments.map(s=>({segment:s.name,format:s.format})),classListEntries:list.size/8,classesDecoded:classes.length,errors,classes,focused,
  caveat:'Static metadata, not execution. External/inherited/category/dynamically installed methods are not established by the own-method lists. No runtime compatibility claim.'};
fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({classListEntries:report.classListEntries,classesDecoded:classes.length,errors:errors.length,focused:focused.map(c=>({name:c.name,superclass:c.superclass,methods:c.methods?.length,error:c.methodsError}))},null,2));
