import zlib from 'node:zlib';
export function tar(entries) {
  const chunks=[];
  for (const [name,value,mode=0o644] of entries) {
    const bytes=Buffer.isBuffer(value)?value:Buffer.from(value), h=Buffer.alloc(512);
    if(Buffer.byteLength(name)>100)throw new Error(`USTAR path too long: ${name}`);
    const str=(s,p,n)=>h.write(s,p,n,'ascii');
    const oct=(v,p,n)=>str(v.toString(8).padStart(n-1,'0')+'\0',p,n);
    str(name,0,100);oct(mode,100,8);oct(0,108,8);oct(0,116,8);oct(bytes.length,124,12);oct(0,136,12);
    h.fill(32,148,156);str('0',156,1);str('ustar\0',257,6);str('00',263,2);str('root',265,32);str('wheel',297,32);
    str(h.reduce((a,b)=>a+b,0).toString(8).padStart(6,'0')+'\0 ',148,8);
    chunks.push(h,bytes,Buffer.alloc((512-bytes.length%512)%512));
  }
  return Buffer.concat([...chunks,Buffer.alloc(1024)]);
}
function member(name,bytes) {
  const h=(name+'/').padEnd(16)+'0'.padEnd(12)+'0'.padEnd(6)+'0'.padEnd(6)+'100644'.padEnd(8)+String(bytes.length).padEnd(10)+'`\n';
  return Buffer.concat([Buffer.from(h),bytes,...(bytes.length%2?[Buffer.from('\n')]:[])]);
}
export function deb(control,entries) {
  return Buffer.concat([Buffer.from('!<arch>\n'),member('debian-binary',Buffer.from('2.0\n')),
    member('control.tar.gz',zlib.gzipSync(tar([['control',control]]))),member('data.tar.gz',zlib.gzipSync(tar(entries)))]);
}
