import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
const origin=process.env.STUDIO_TEST_ORIGIN||'http://127.0.0.1:8791';
const mac='studio-worker-local-fixture-token-00000000';
const checkpoint='/tmp/shortcut-worker-conformance.json';
async function api(path,{token,body,method}={}) {
 const response=await fetch(origin+path,{method:method||(body?'POST':'GET'),headers:{...(token?{Authorization:'Bearer '+token}:{}),...(body?{'Content-Type':'application/json'}:{})},body:body?JSON.stringify(body):undefined});
 return {status:response.status,data:await response.json()};
}
function key(){const ecdh=crypto.createECDH('prime256v1');ecdh.generateKeys();return ecdh.getPublicKey().toString('base64');}
const workflow={id:crypto.randomUUID(),revision:'b'.repeat(64),name:'Worker fixture',color:'teal',symbol:'text.bubble',usesModel:false,actionCount:1,actionTitles:['Text']};
async function snapshot(extra={}) {return api('/mac/snapshot',{token:mac,body:{workflows:[workflow],status:'Ready',decisions:[],updates:[],revoke:[],...extra}});}
if(process.argv.includes('--resume')) {
 const saved=JSON.parse(fs.readFileSync(checkpoint));
 const result=await api('/api/runs/'+saved.runID,{token:saved.token});assert.equal(result.status,200);assert.equal(result.data.state,'Completed');assert.equal(result.data.output,'YWJj');
 const pairing=await api('/api/pair',{body:{code:saved.code,publicKey:key(),label:'Restored challenge fixture'}});assert.equal(pairing.status,200);
 console.log('PASS Worker restart restores credentials, terminal result and unused pairing challenge');
} else {
 assert.equal((await api('/health')).data.protocol,'studio.messenger/1');assert.equal((await api('/mac/poll')).status,401);assert.equal((await api('/api/state')).status,401);
 const asset=await fetch(origin+'/');assert.equal(asset.status,200);assert.match(asset.headers.get('Content-Security-Policy'),/frame-ancestors 'none'/);
 assert.equal((await snapshot()).status,200);
 const challenge=(await api('/mac/challenge',{token:mac,body:{}})).data;
 const pair=(await api('/api/pair',{body:{code:challenge.code,publicKey:key(),label:'Worker fixture'}})).data;
 assert.equal((await api('/api/pair',{body:{code:challenge.code,publicKey:key(),label:'Replay'}})).status,403);
 const pending=(await api('/mac/poll',{token:mac})).data;assert.equal(pending.pairs.at(-1).id,pair.id);
 assert.equal((await snapshot({decisions:[{id:pair.id,approved:true,macPublicKey:key()}]})).status,200);
 const approval=(await api('/api/pair-status',{body:pair})).data;assert.equal(approval.state,'Approved');
 assert.equal((await api('/mac/poll',{token:approval.token})).status,401);
 const command={id:crypto.randomUUID(),payload:'YWJj'};
 assert.equal((await api('/api/runs',{token:approval.token,body:command})).data.state,'Sent');
 assert.equal((await api('/api/runs',{token:approval.token,body:command})).data.id,command.id);
 assert.equal((await api('/api/runs',{token:approval.token,body:{...command,payload:'ZGVm'}})).status,409);
 assert.equal((await api('/api/runs',{token:approval.token,body:{id:crypto.randomUUID(),payload:'YWJj'}})).status,409);
 assert.equal((await snapshot({updates:[{id:command.id,state:'Running',output:null,message:'Running'},{id:command.id,state:'Completed',output:'YWJj',message:'Completed'}]})).status,200);
 assert.equal((await api('/api/runs/'+command.id,{token:approval.token})).data.state,'Completed');
 assert.equal((await snapshot({updates:[{id:command.id,state:'Running',message:'Replay'}]})).status,200);
 assert.equal((await api('/api/runs/'+command.id,{token:approval.token})).data.state,'Completed');
 const denied=await api('/api/push',{token:approval.token,body:{subscription:{endpoint:'http://127.0.0.1'}}});assert.equal(denied.status,400);
 const wrongOrigin=await fetch(origin+'/mac/challenge',{method:'POST',headers:{Authorization:'Bearer '+mac,'Content-Type':'application/json',Origin:'https://attacker.example'},body:'{}'});assert.equal(wrongOrigin.status,403);
 const next=(await api('/mac/challenge',{token:mac,body:{}})).data;
 fs.writeFileSync(checkpoint,JSON.stringify({token:approval.token,runID:command.id,code:next.code}),{mode:0o600});
 console.log('PASS Worker assets/CSP, auth roles, pairing approval/replay, command duplicate/conflict/busy, terminal monotonicity, push destination and origin checks');
}
