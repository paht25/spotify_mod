// Distributed beside PATCH-MANIFEST.json in the extracted repair ZIP.
// Copies checked source bytes, with backups. Never merges, commits, or pushes.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';

const patch=fs.realpathSync(path.dirname(fileURLToPath(import.meta.url)));
const sha=data=>crypto.createHash('sha256').update(data).digest('hex');
function inside(base,file){const relative=path.relative(base,file);return relative===''||(!relative.startsWith('..'+path.sep)&&relative!=='..'&&!path.isAbsolute(relative));}
function checkedPath(base,name){
  if(typeof name!=='string'||!name||name.includes('\\')||path.isAbsolute(name)||name.split('/').some(p=>!p||p==='.'||p==='..'))throw new Error('Unsafe patch path');
  const target=path.resolve(base,name);if(!inside(base,target))throw new Error('Patch path escapes root');
  let part=base;
  for(const item of name.split('/')){
    part=path.join(part,item);
    if(fs.existsSync(part)&&fs.lstatSync(part).isSymbolicLink())throw new Error('Refusing to traverse a symbolic link or junction: '+part);
  }
  return target;
}
function main(){
  if(!process.argv[2])throw new Error('Usage: node apply-clean-files.mjs <local Git repository root>');
  const repo=fs.realpathSync(path.resolve(process.argv[2]));
  if(inside(repo,patch)||inside(patch,repo))throw new Error('Extract the patch outside the Git repository before applying it');
  const git=spawnSync('git',['-C',repo,'rev-parse','--show-toplevel'],{encoding:'utf8'});
  if(git.status!==0)throw new Error('The destination must be an existing local Git checkout');
  if(fs.realpathSync(git.stdout.trim())!==repo)throw new Error('Select the repository root, not a subdirectory');
  const remote=spawnSync('git',['-C',repo,'remote','get-url','origin'],{encoding:'utf8'});
  if(remote.status!==0||!/(?:github\.com[/:])paht25\/(?:spotify_mod|cloud)(?:\.git)?\/?$/.test(remote.stdout.trim()))throw new Error('Expected a checkout of paht25/spotify_mod or paht25/cloud; no files changed');
  const manifest=JSON.parse(fs.readFileSync(path.join(patch,'PATCH-MANIFEST.json'),'utf8'));
  if(manifest.revision!=='chroma-core-v5-9188-fix4')throw new Error('Unexpected patch manifest revision');
  const names=new Set(),plan=[];
  for(const item of manifest.files){
    if(names.has(item.path))throw new Error('Duplicate patch entry');names.add(item.path);
    const source=checkedPath(patch,item.path),bytes=fs.readFileSync(source);
    if(sha(bytes)!==item.sha256)throw new Error('Patch hash mismatch: '+item.path);
    if(!item.install)continue;
    if(!/^(?:Sources\/|Tests\/|Integration\/Chroma\/tweak\/|scripts\/|tools\/|\.github\/workflows\/|target\.json$)/.test(item.path))throw new Error('Unexpected install destination: '+item.path);
    const target=checkedPath(repo,item.path);
    if(fs.existsSync(target)&&!fs.statSync(target).isFile())throw new Error('Destination is not a regular file: '+item.path);
    plan.push({name:item.path,target,bytes});
  }
  // Verify every input and destination before writing anything in the checkout.
  const backupParent=checkedPath(patch,'backups');
  const backup=path.join(backupParent,new Date().toISOString().replaceAll(':','-')+'-'+crypto.randomUUID());
  const record=[];
  for(const item of plan){
    const previous=fs.existsSync(item.target)?fs.readFileSync(item.target):null;
    if(previous&&previous.equals(item.bytes))continue;
    if(previous){const saved=checkedPath(backup,item.name);fs.mkdirSync(path.dirname(saved),{recursive:true});fs.writeFileSync(saved,previous,{flag:'wx'});}
    fs.mkdirSync(path.dirname(item.target),{recursive:true});fs.writeFileSync(item.target,item.bytes);
    record.push({path:item.name,previousSHA256:previous?sha(previous):null,newSHA256:sha(item.bytes)});
  }
  if(record.length){fs.mkdirSync(backup,{recursive:true});fs.writeFileSync(path.join(backup,'APPLY-REPORT.json'),JSON.stringify({repository:repo,files:record},null,2)+'\n');}
  console.log(`Applied ${record.length} clean files. No merge, commit, or push was performed.`);
  if(record.length)console.log('Backups: '+backup);
  const result=spawnSync(process.execPath,[path.join(repo,'tools/check-source-conflicts.mjs')],{cwd:repo,stdio:'inherit'});
  if(result.status!==0)throw new Error('Other source conflicts remain. Keep the backups and resolve the paths reported above before committing');
  console.log('Review git diff, commit the corrected files, then push and run the workflow on that new commit.');
}
try{main();}catch(error){console.error('Patch application stopped: '+error.message);process.exitCode=1;}
