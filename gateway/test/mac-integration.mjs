import fs from 'node:fs';
import {createGateway} from '../server.mjs';import crypto from 'node:crypto';import {spawn} from 'node:child_process';import assert from 'node:assert/strict';
const external=process.env.STUDIO_TEST_GATEWAY;
const token=external?fs.readFileSync(process.env.STUDIO_TEST_MAC_TOKEN_FILE,'utf8').trim():crypto.randomBytes(32).toString('base64url');
const s=external?null:createGateway({macToken:token,push:{setVapidDetails(){},async sendNotification(){}}});
if(s)await new Promise(r=>s.listen(0,'127.0.0.1',r));
const base=external||('http://127.0.0.1:'+s.address().port);
let pairedToken;
const child=spawn(process.argv[2],[base],{env:{...process.env,STUDIO_INTEROP_TOKEN:token}});let output='',code;
child.stdout.on('data',c=>{process.stdout.write(c);output+=c;code=output.match(/CODE (\d{6})/)?.[1];});child.stderr.on('data',c=>process.stderr.write(c));const done=new Promise(r=>child.on('exit',r));
async function until(fn){for(let n=0;n<120;n++){const v=await fn();if(v)return v;await new Promise(r=>setTimeout(r,1000));}throw Error('Timed out');}
async function api(route,body,credential){const r=await fetch(base+route,{method:body?'POST':'GET',headers:{...(body?{'Content-Type':'application/json'}:{}),...(credential?{Authorization:'Bearer '+credential}:{})},body:body?JSON.stringify(body):undefined});const b=await r.json();assert.equal(r.status,200,JSON.stringify(b));return b;}
try{
 await until(()=>code);const subtle=crypto.webcrypto.subtle,identity=await subtle.generateKey({name:'ECDH',namedCurve:'P-256'},true,['deriveBits']);
 const pair=await api('/api/pair',{code,publicKey:Buffer.from(await subtle.exportKey('raw',identity.publicKey)).toString('base64'),label:'Isolated phone'});
 const a=await until(async()=>{const p=await api('/api/pair-status',pair);return p.state==='Approved'?p:null;});
 pairedToken=a.token;
 const peer=await subtle.importKey('raw',Buffer.from(a.macPublicKey,'base64'),{name:'ECDH',namedCurve:'P-256'},false,[]),shared=await subtle.deriveBits({name:'ECDH',public:peer},identity.privateKey,256),material=await subtle.importKey('raw',shared,'HKDF',false,['deriveKey']);
 const key=await subtle.deriveKey({name:'HKDF',hash:'SHA-256',salt:Buffer.from('studio.messenger/1'),info:Buffer.from(pair.id)},material,{name:'AES-GCM',length:256},false,['encrypt','decrypt']);
 const state=await until(async()=>{const p=await api('/api/state',null,a.token);return p.workflows.length===3?p:null;}),echo=state.workflows.find(w=>w.name==='Remote Echo'),slow=state.workflows.find(w=>w.name==='Remote Wait'),author=state.workflows.find(w=>w.name==='Remote Author');
 async function command(w,changes={},corrupt=false){const id=crypto.randomUUID(),iv=crypto.randomBytes(12),inner={id,deviceID:pair.id,workflowID:w.id,workflowRevision:w.revision,input:'Hello\nUnicode ✓',expiresAt:Date.now()+60000,...changes};const seal=await subtle.encrypt({name:'AES-GCM',iv,additionalData:Buffer.from('command|'+pair.id+'|'+id)},key,Buffer.from(JSON.stringify(inner)));const bytes=Buffer.concat([iv,Buffer.from(seal)]);if(corrupt)bytes[20]^=1;const request={id,payload:bytes.toString('base64')};await api('/api/runs',request,a.token);return request;}
 async function terminal(id){return until(async()=>{const r=await api('/api/runs/'+id,null,a.token);return ['Completed','Cancelled','Rejected','Failed'].includes(r.state)?r:null;});}
 const request=await command(echo),result=await terminal(request.id);assert.equal(result.state,'Completed');const bytes=Buffer.from(result.output,'base64'),clear=await subtle.decrypt({name:'AES-GCM',iv:bytes.subarray(0,12),additionalData:Buffer.from('result|'+pair.id+'|'+request.id)},key,bytes.subarray(12));assert.equal(JSON.parse(Buffer.from(clear)).text,'Remote says: Hello\nUnicode ✓');console.log('PASS WebCrypto ↔ Swift CryptoKit command/result and dialog-free Show');
 async function clearResult(id){const r=await terminal(id);assert.equal(r.state,'Completed');const bytes=Buffer.from(r.output,'base64');const clear=await subtle.decrypt({name:'AES-GCM',iv:bytes.subarray(0,12),additionalData:Buffer.from('result|'+pair.id+'|'+id)},key,bytes.subarray(12));return JSON.parse(Buffer.from(clear)).text;}
 const savedRequest=await command(author,{input:'studio.shortcut/1\n'+JSON.stringify({operation:'save',name:'Created from phone',steps:['model status']})});
 const saved=JSON.parse(await clearResult(savedRequest.id));assert.equal(saved.kind,'shortcutSaved');
 await api('/api/runs',savedRequest,a.token);
 const withChild=await until(async()=>{const current=await api('/api/state',null,a.token);return current.workflows.find(w=>w.id===saved.id)?current:null;});
 const childShortcut=withChild.workflows.find(w=>w.id===saved.id);assert.equal(childShortcut.userCreated,true);assert.equal(childShortcut.canCreate,false);
 const load=await command(author,{input:'studio.shortcut/1\n'+JSON.stringify({operation:'load',id:saved.id})});
 const draft=JSON.parse(await clearResult(load.id));assert.deepEqual(draft.steps,['model status']);
 const edited=await command(author,{input:'studio.shortcut/1\n'+JSON.stringify({operation:'save',id:draft.id,revision:draft.revision,name:'Edited from phone',steps:['model status','model status']})});
 assert.equal(JSON.parse(await clearResult(edited.id)).id,saved.id);
 const ready=await until(async()=>{const current=await api('/api/state',null,a.token);return current.workflows.find(w=>w.id===saved.id&&w.name==='Edited from phone')});
 const execution=await command(ready,{input:''});assert.match(await clearResult(execution.id),/Studio model use:/);
 const denied=await command(author,{input:'studio.shortcut/1\n'+JSON.stringify({operation:'save',name:'Forbidden scope',steps:['model status'],applications:'com.apple.finder'})});assert.equal((await terminal(denied.id)).state,'Failed');
 console.log('PASS phone request cannot inject app permissions');
 console.log('PASS encrypted phone creation, durable save, load, edit, duplicate save and execution');
 assert.equal((await api('/api/runs',request,a.token)).state,'Completed');console.log('PASS duplicate retrieves original terminal run');
 for(const [changes,corrupt,label] of [[{workflowRevision:'a'.repeat(64)},false,'revision changed'],[{unexpected:'code'},false,'unknown inner key'],[{},true,'ciphertext forged'],[{input:'X'.repeat(16385)},false,'oversized input']]){const r=await command(echo,changes,corrupt);assert.equal((await terminal(r.id)).state,'Rejected');console.log('PASS rejects '+label);}
 const run=await command(slow);await until(async()=>{const r=await api('/api/runs/'+run.id,null,a.token);return r.state==='Running';});await api('/api/runs/'+run.id+'/cancel',{},a.token);assert.equal((await terminal(run.id)).state,'Cancelled');console.log('PASS owned cancellation round trip');
 assert.equal(await done,0);assert.match(output,/MESSENGER VALIDATION PASS/);
}catch(e){console.error(e);child.kill();process.exitCode=1;}finally{if(external&&pairedToken)await fetch(base+'/api/device',{method:'DELETE',headers:{Authorization:'Bearer '+pairedToken}});if(s)await new Promise(r=>s.close(r));}
