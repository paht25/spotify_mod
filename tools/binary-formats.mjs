// Pure binary readers shared with analyze.mjs; no payload execution.
const z = (b,o,end=b.length) => { const e=b.indexOf(0,o); return b.toString('utf8',o,e<0||e>end?end:e); };
export function plist(b) {
  if(b.toString('ascii',0,8)!=='bplist00') throw new Error('Not a binary plist');
  const t=b.length-32, os=b[t+6], rs=b[t+7];
  const uint=(p,n)=>{if(n>8||p<0||p+n>b.length)throw new Error('Invalid integer');let v=0n;for(let i=0;i<n;i++)v=(v<<8n)|BigInt(b[p+i]);if(v>BigInt(Number.MAX_SAFE_INTEGER))throw new Error('Unsafe integer');return Number(v);};
  const count=uint(t+8,8), top=uint(t+16,8), table=uint(t+24,8), cache=new Map();
  function object(id) {
    if(cache.has(id))return cache.get(id);
    if(id>=count)throw new Error('Bad object reference');
    let p=uint(table+id*os,os), marker=b[p++], type=marker>>4, n=marker&15;
    if(type===0)return n===9?true:n===8?false:null;
    if(type===1)return uint(p,2**n);
    if(type===2)return n===2?b.readFloatBE(p):b.readDoubleBE(p);
    if(type===3)return new Date((b.readDoubleBE(p)+978307200)*1000).toISOString();
    if(n===15){const size=2**(b[p++]&15);n=uint(p,size);p+=size;}
    let value;
    if(type===4)value={dataBase64:b.subarray(p,p+n).toString('base64')};
    else if(type===5)value=b.toString('ascii',p,p+n);
    else if(type===6){value='';for(let i=0;i<n;i++)value+=String.fromCharCode(b.readUInt16BE(p+2*i));}
    else if(type===10||type===12){value=[];cache.set(id,value);for(let i=0;i<n;i++)value.push(object(uint(p+i*rs,rs)));}
    else if(type===13){value=Object.create(null);cache.set(id,value);for(let i=0;i<n;i++)value[object(uint(p+i*rs,rs))]=object(uint(p+(n+i)*rs,rs));}
    else throw new Error('Unsupported plist marker '+marker.toString(16));
    cache.set(id,value);return value;
  }
  return object(top);
}

function version(v){return `${v>>>16}.${(v>>>8)&255}.${v&255}`;}
export function macho(data) {
  const magic=data.readUInt32BE(0);
  if(magic===0xcafebabe){const n=data.readUInt32BE(4);return {fat:true,slices:Array.from({length:n},(_,i)=>{const p=8+i*20;return macho(data.subarray(data.readUInt32BE(p+8),data.readUInt32BE(p+8)+data.readUInt32BE(p+12))).slices[0];})};}
  if(data.readUInt32LE(0)!==0xfeedfacf)throw new Error('Unsupported Mach-O');
  const b=data, deps=[],rpaths=[],sections=[],symbols=[];
  let installName, build, symtab, signed=false, initFunctions=false;
  for(let i=0,o=32;i<b.readUInt32LE(16);i++){
    const cmd=b.readUInt32LE(o), size=b.readUInt32LE(o+4), k=cmd&0x7fffffff;
    if(size<8||o+size>b.length)throw new Error('Invalid load command');
    if([12,13,24,31,35].includes(k)){
      const d={name:z(b,o+b.readUInt32LE(o+8),o+size),command:'0x'+cmd.toString(16),currentVersion:version(b.readUInt32LE(o+16)),compatibilityVersion:version(b.readUInt32LE(o+20))};
      if(k===13)installName=d;else deps.push(d);
    }
    if(k===28)rpaths.push(z(b,o+b.readUInt32LE(o+8),o+size));
    if(k===50)build={platform:b.readUInt32LE(o+8),minOS:version(b.readUInt32LE(o+12)),sdk:version(b.readUInt32LE(o+16))};
    if(k===29)signed=true;
    if(k===2)symtab={offset:b.readUInt32LE(o+8),count:b.readUInt32LE(o+12),strings:b.readUInt32LE(o+16)};
    if(k===25)for(let j=0;j<b.readUInt32LE(o+64);j++){
      const s=o+72+j*80,name=z(b,s,s+16),segment=z(b,s+16,s+32),offset=b.readUInt32LE(s+48),length=Number(b.readBigUInt64LE(s+40));
      const item={name,segment,offset,length};
      if(['__objc_methname','__objc_classname','__cstring'].includes(name))item.strings=b.toString('utf8',offset,offset+length).split('\0').filter(Boolean);
      if(name==='__mod_init_func')initFunctions=true;
      sections.push(item);
    }
    o+=size;
  }
  if(symtab)for(let i=0;i<symtab.count;i++){
    const p=symtab.offset+i*16, type=b[p+4], desc=b.readUInt16LE(p+6),ordinal=desc>>>8,name=z(b,symtab.strings+b.readUInt32LE(p));
    if((type&0xe)===0&&name)symbols.push({name,ordinal,library:ordinal>0&&ordinal<=deps.length?deps[ordinal-1].name:null,weak:!!(desc&64)});
  }
  return {fat:false,slices:[{cpu:b.readUInt32LE(4),cpuSubtype:b.readUInt32LE(8),fileType:b.readUInt32LE(12),installName,build,deps,rpaths,hasCodeSignatureCommand:signed,hasInitializerSection:initFunctions,sections,imports:symbols}]};
}

