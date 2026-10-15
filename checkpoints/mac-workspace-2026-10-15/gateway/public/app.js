'use strict';
const $=id=>document.getElementById(id), encoder=new TextEncoder(), decoder=new TextDecoder();
function resultText(text){try{const result=JSON.parse(text);if(result.kind==='shortcutSaved')return 'Saved “'+result.name+'” on your Mac. You can now run it from My Shortcuts.';if(result.kind==='shortcutLoaded')return 'Shortcut loaded for editing.';}catch{}return text;}
const terminal=new Set(['Completed','Failed','Cancelled','Interrupted','Rejected','DeliveryExpired','NeedsLocalAttention']);
let state=null,busy=false,pairing=false,pending=null,registration=null,session=null,refreshing=false,lastWorkflows="",lastRuns="";
function b64(bytes){return btoa(String.fromCharCode(...new Uint8Array(bytes)));}
function raw(s){return Uint8Array.from(atob(s),c=>c.charCodeAt(0));}
function urlRaw(s){return raw(s.replaceAll('-','+').replaceAll('_','/'));}
function db(){return new Promise((resolve,reject)=>{const r=indexedDB.open('studio-messenger',1);r.onupgradeneeded=()=>r.result.createObjectStore('credentials');r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});}
async function saved(action,value){const database=await db();return new Promise((resolve,reject)=>{const t=database.transaction('credentials',action==='get'?'readonly':'readwrite'),store=t.objectStore('credentials');const r=action==='get'?store.get('session'):action==='delete'?store.delete('session'):store.put(value,'session');r.onsuccess=()=>{if(action==='get')resolve(r.result);};t.oncomplete=()=>{database.close();if(action!=='get')resolve();};t.onerror=()=>reject(t.error);});}
function notice(text){$('notice').textContent=text;}
async function api(path,body,method){const headers={};if(session)headers.Authorization='Bearer '+session.token;if(body)headers['Content-Type']='application/json';const response=await fetch(path,{method:method||(body?'POST':'GET'),headers,body:body?JSON.stringify(body):undefined,cache:'no-store',credentials:'omit',signal:AbortSignal.timeout(12000)});const data=await response.json();if(!response.ok)throw Error(data.error||'Request failed');return data;}
async function encrypt(value,id){const iv=crypto.getRandomValues(new Uint8Array(12));const clear=encoder.encode(JSON.stringify(value));const data=await crypto.subtle.encrypt({name:'AES-GCM',iv,additionalData:encoder.encode('command|'+session.id+'|'+id)},session.key,clear);return b64(new Uint8Array([...iv,...new Uint8Array(data)]));}
async function decrypt(payload,id){const data=raw(payload);const clear=await crypto.subtle.decrypt({name:'AES-GCM',iv:data.slice(0,12),additionalData:encoder.encode('result|'+session.id+'|'+id)},session.key,data.slice(12));return JSON.parse(decoder.decode(clear));}
function element(tag,text,cls){const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(cls)e.className=cls;return e;}
const palette={purple:'#6236AF',blue:'#165DAC',pink:'#A52F75',orange:'#9B450D',green:'#1A6938',red:'#B02A38',teal:'#09696F',gray:'#55555F'};
let navigation='all', editingShortcut=null;
const demoNames=new Set(['Hello, You','Morning Note','List Playground','Persistent Counter','JSON Explorer','JSON Explorer · Imported Check','Studio Bridge Check — text only','Text Input · Validation','On-Device Model · Validation','Google Search in Chrome','Framer to Subframe','Model Draft UI Check','Phone · Echo','Phone · Google in Chrome','Phone · Framer to Subframe','Phone · On-Device Answer','Phone · Desktop File Names','Phone · Assistant']);
const libraryWorkflows=()=> (state?.workflows||[]).filter(w=>!w.canCreate&&(w.userCreated||!demoNames.has(w.name)));
const selectable=()=> (state?.workflows||[]).filter(w=>w.canCreate||w.userCreated||!demoNames.has(w.name));
const authoring=()=>state?.workflows.find(w=>w.canCreate);
function stepFields(values=['']){const container=$('shortcutSteps');container.replaceChildren();values.forEach((value,index)=>{const row=element('div',undefined,'inputPanel');const label=element('label','Command '+(index+1));const input=element('textarea');input.rows=3;input.value=value;input.setAttribute('aria-label','Command '+(index+1));input.placeholder='Enter a Mac command or question…';const remove=element('button','Remove command','quiet');remove.type='button';remove.disabled=values.length===1;remove.onclick=()=>{const next=[...container.querySelectorAll('textarea')].map(e=>e.value);next.splice(index,1);stepFields(next);};row.append(label,input,remove);container.append(row);});$('addCommand').disabled=values.length>=10;}
function openBuilder(draft){draft=draft||session?.shortcutDraft;editingShortcut=draft?.id?draft:null;$('shortcutName').value=draft?.name||'';$('builderTitle').textContent=draft?'Edit Shortcut':'Create Shortcut';stepFields(draft?.steps||['']);navigate('create');}

function glyph(w){const name=(w.symbol||'')+' '+w.name.toLowerCase();if(name.includes('desktop'))return '▣';if(name.includes('globe')||name.includes('Chrome'))return '◎';if(w.usesModel)return '✦';if(name.includes('list'))return '≡';if(name.includes('curly'))return '{}';return '▱';}
function library(){
 const filter=$('search').value.toLowerCase(),grid=$('shortcutGrid');grid.replaceChildren();
 for(const w of libraryWorkflows()){if(!w.name.toLowerCase().includes(filter))continue;const tile=element('button',undefined,'shortcutTile'+(w.id===$('workflow').value?' selected':''));tile.style.background=palette[w.color]||palette.purple;tile.setAttribute('aria-label','Open '+w.name);tile.setAttribute('aria-pressed',String(w.id===$('workflow').value));tile.append(element('span',glyph(w),'tileIcon'),element('span',w.name,'tileName'),element('span',w.actionCount?w.actionCount+' actions':'Mac workflow','tileCount'));tile.onclick=()=>{$('workflow').value=w.id;selectWorkflow();if(matchMedia('(max-width:650px)').matches)$('composer').scrollIntoView({block:'start',behavior:matchMedia('(prefers-reduced-motion:reduce)').matches?'auto':'smooth'});};grid.append(tile);}
 const count=libraryWorkflows().length;$('shortcutCount').textContent=count;$('libraryCount').textContent=count+' shortcuts';if(!count)grid.append(element('p','Create your first shortcut. Save it here, then run it whenever you need it.','hint'));
}
function selectWorkflow(){
 const w=state?.workflows.find(w=>w.id===$('workflow').value);if(!w)return;
 session.selectedWorkflowID=w.id;$('input').value=session.drafts?.[w.id]||'';void saved('put',session);hint();library();document.body.classList.remove('sidebarOpen');
}
function editor(){
 const w=state?.workflows.find(w=>w.id===$('workflow').value);if(!w)return;
 $('modelControls').hidden=!w.canCreate;$('selectedName').textContent=w.canCreate?'Mac Assistant':w.name;$('composer').hidden=!session||navigation==='create'||(navigation==='all'&&w.canCreate);$('editShortcut').hidden=!w.userCreated;$('inputPanel').hidden=w.userCreated&&!w.requiresInput;$('selectedIcon').textContent=glyph(w);$('selectedIcon').style.color=palette[w.color]||palette.purple;
 const list=$('actionList');list.replaceChildren();for(const [index,title] of (w.actionTitles||[]).entries()){const card=element('article',undefined,'actionCard');card.append(element('span',index+1,'actionNumber'),element('div',w.userCreated?'Command '+(index+1):title,'actionCardTitle'),element('div',w.userCreated?'Saved on your Mac':'Approved on your Mac','actionCardSub'));list.append(card);}
 if(w.actionCount>(w.actionTitles?.length||0))list.append(element('p',(w.actionCount-(w.actionTitles?.length||0))+' more actions on your Mac','hint'));
 $('inputCount').textContent=encoder.encode($('input').value).length+' / 16 KiB';
}
function navigate(page){if(!session){notice('Pair with your Mac first.');return;}navigation=page;document.querySelector('.toolbar h1').textContent=page==='history'?'Run History':page==='assistant'?'Assistant':page==='create'?'New Shortcut':'My Shortcuts';$('libraryPane').hidden=page!=='all';$('builder').hidden=page!=='create';$('composer').hidden=page==='create';$('workspace').hidden=!session||page==='history';$('outputTitle').textContent=page==='history'?'Run History':'Output';for(const [id,key] of [['navAll','all'],['navAssistant','assistant'],['navHistory','history']])$(id).classList.toggle('selected',key===page);if(page==='assistant'){const w=authoring();if(w){$('workflow').value=w.id;selectWorkflow();}else notice('Approve Phone · Assistant in the Mac Messenger window.');}document.body.classList.remove('sidebarOpen');}
async function render(){
  $('pair').hidden=!!session;$('composer').hidden=!session||navigation==='create';$('builder').hidden=!session||navigation!=='create';$('inboxSection').hidden=!session;$('workspace').hidden=!session||navigation==='history';$('disconnect').hidden=!session;
  if(!session||!state)return;
  $('connection').textContent=state.online?'Mac connected':'Mac unavailable';
  $('testNotification').hidden=!state.pushRegistered; if(state.pushRegistered)$('notifications').replaceChildren(element('span','♧'),element('span','Notifications enabled'));
  const select=$('workflow'),previous=select.value,workflowSignature=JSON.stringify([session.id,state.workflows]);
  if(workflowSignature!==lastWorkflows){lastWorkflows=workflowSignature;select.replaceChildren();for(const w of selectable()){const option=element('option',w.name+(w.usesModel?' · AI':''));option.value=w.id;select.append(option);}if(selectable().some(w=>w.id===(session.selectedWorkflowID||previous)))select.value=session.selectedWorkflowID||previous;else if(authoring())select.value=authoring().id;
    $('input').value=session.drafts?.[select.value]||'';library();editor();
    if(!selectable().length){const o=element('option','Approve a workflow on your Mac');select.append(o);}
  }
  const running=state.macStatus==='Busy'||state.runs.some(r=>!terminal.has(r.state));$('createShortcut').disabled=busy||!authoring();$('saveShortcut').disabled=running||busy||!state.online||!authoring();$('editShortcut').disabled=running||busy||!state.online||!authoring();$('send').disabled=busy||!state.online||!selectable().length||state.macStatus==='Busy'||state.runs.some(r=>!terminal.has(r.state));for(const id of ['modelOff','modelOn','modelStatus'])$(id).disabled=running||busy||!state.online||!authoring();hint();
  const runSignature=JSON.stringify([session.id,state.runs,pending?.id]);if(runSignature===lastRuns)return;lastRuns=runSignature;
  $('inbox').replaceChildren();
  if(pending){const p=element('article',undefined,'run running');p.append(element('h3','Sending…'),element('p','Waiting for a receipt. Reconnect checks the same request; it will not create a second run.','hint'));$('inbox').append(p);}
  $('runLog').textContent=state.runs.map(r=>new Date(r.updatedAt).toLocaleTimeString()+' · '+(session.names?.[r.id]||'Mac workflow')+' · '+r.state+(r.message?' · '+r.message:'')).join('\n');
  for(const r of state.runs){const card=element('article',undefined,'run'+(!terminal.has(r.state)?' running':''));card.id='run-'+r.id;const head=element('div',undefined,'runHead');head.append(element('h3',session.names?.[r.id]||'Mac workflow'),element('span',r.state==='Sent'?'Sent to gateway':r.state,'pill'));card.append(head,element('time',new Date(r.createdAt).toLocaleString()));
    if(r.output){try{const result=await decrypt(r.output,r.id);card.append(element('pre',resultText(result.text)));
        try {const managed=JSON.parse(result.text);session.handled=session.handled||{};
          if(r.state==='Completed'&&!session.handled[r.id]&&['shortcutSaved','shortcutLoaded'].includes(managed.kind)){
            session.handled[r.id]=true;
            if(managed.kind==='shortcutSaved'){session.selectedWorkflowID=managed.id;delete session.shortcutDraft;notice('Shortcut saved on your Mac. Select it and tap Run.');navigate('all');}
            else openBuilder(managed);
            await saved('put',session);
          }
        }catch{}
if(result.truncated)card.append(element('p','Result shortened to fit the phone inbox.','hint'));}catch{card.append(element('p','Response could not be authenticated.','hint'));}}
    else card.append(element('p',r.message||'Waiting for Mac…','hint'));
    const actions=element('div',undefined,'runActions');if(!terminal.has(r.state)){const stop=element('button',r.cancelRequested?'Stop requested':'Stop','quiet danger');stop.disabled=r.cancelRequested;stop.onclick=async()=>{try{await api('/api/runs/'+r.id+'/cancel',{});await refresh();}catch(e){notice(e.message);}};actions.append(stop);}
    else if(r.output){const copy=element('button','Copy result','quiet');copy.onclick=async()=>{try{await navigator.clipboard.writeText((await decrypt(r.output,r.id)).text);notice('Result copied.');}catch{notice('Copy unavailable. Select the result text.');}};actions.append(copy);}card.append(actions);$('inbox').append(card);
  }
}
function hint(){editor();const w=state?.workflows.find(w=>w.id===$('workflow').value);$('workflowHint').textContent=w?.canCreate?'Try: What is on my Desktop? · Open Calculator · In ChatGPT: explain gravity · Ask a question.':w?.usesModel?'Apple AI is used when a command needs it.':'Runs authored actions on your Mac. No model call.';}
async function refresh(){if(!session||pairing||refreshing)return;refreshing=true;try{state=await api('/api/state');if(pending){const found=state.runs.find(r=>r.id===pending.id);if(found){pending=null;session.pending=null;await saved('put',session);notice('Command received by gateway.');}}
 await render();const target=location.hash.match(/^#run=([a-f0-9-]+)$/i)?.[1];if(target)document.getElementById('run-'+target)?.scrollIntoView({block:'center'});
 }catch(e){$('connection').textContent='Connection interrupted';$('send').disabled=true;if(e.message==='UNAUTHORIZED'){notice('This phone was revoked or its session expired. Pair again.');await saved('delete');session=null;await render();}else notice('Connection interrupted. Your existing command will not be rerun. Use Refresh to recover.');}finally{refreshing=false;}}
$('pairForm').onsubmit=async event=>{
 event.preventDefault();if(pairing)return;pairing=true;$('pairButton').disabled=true;
 try{
  const identity=await crypto.subtle.generateKey({name:'ECDH',namedCurve:'P-256'},true,['deriveBits']);const publicKey=await crypto.subtle.exportKey('raw',identity.publicKey);const fingerprint=[...new Uint8Array(await crypto.subtle.digest('SHA-256',publicKey)).slice(0,8)].map(x=>x.toString(16).padStart(2,'0')).join('');
  const pair=await api('/api/pair',{code:$('code').value,publicKey:b64(publicKey),label:$('label').value});$('fingerprint').hidden=false;$('fingerprint').textContent='Verify this fingerprint on your Mac, then approve: '+fingerprint;notice('Waiting for approval on your Mac…');
  const deadline=Date.now()+300000;
  while(Date.now()<deadline){await new Promise(r=>setTimeout(r,1500));const answer=await api('/api/pair-status',pair);if(answer.state==='Rejected')throw Error('Pairing declined on Mac');if(answer.state==='Approved'){
    const peer=await crypto.subtle.importKey('raw',raw(answer.macPublicKey),{name:'ECDH',namedCurve:'P-256'},false,[]);const shared=await crypto.subtle.deriveBits({name:'ECDH',public:peer},identity.privateKey,256);const material=await crypto.subtle.importKey('raw',shared,'HKDF',false,['deriveKey']);const key=await crypto.subtle.deriveKey({name:'HKDF',hash:'SHA-256',salt:encoder.encode('studio.messenger/1'),info:encoder.encode(answer.id)},material,{name:'AES-GCM',length:256},false,['encrypt','decrypt']);session={id:answer.id,token:answer.token,key,pending:null};await saved('put',session);notice('Paired. Choose an approved Mac workflow.');break;
  }}if(!session)throw Error('Pairing expired');
 }catch(e){notice(e.message);}finally{pairing=false;$('pairButton').disabled=false;await refresh();}
};
async function submit(w,input,label){
 if(busy||!state||!w)return;if(pending){notice('Refresh to recover the earlier request before sending another command.');return;}
 if(encoder.encode(input).length>16384){notice('Input exceeds 16 KiB.');return;}
 busy=true;await render();try{
   if(!pending){const id=crypto.randomUUID();pending={id,payload:await encrypt({id,deviceID:session.id,workflowID:w.id,workflowRevision:w.revision,input,expiresAt:Date.now()+60000},id)};session.names=session.names||{};session.names[id]=label||w.name;session.pending=pending;await saved('put',session);}
   const result=await api('/api/runs',pending);notice(result.state==='Sent'?'Sent. Waiting for your Mac…':result.state);pending=null;session.pending=null;await saved('put',session);
 }catch(e){if(['MAC_OFFLINE','BUSY','INVALID_COMMAND','SESSION_FULL'].includes(e.message)){pending=null;session.pending=null;await saved('put',session);notice(e.message);}else notice('Delivery uncertain. Refresh to look up this request; never send a new command automatically.');}
 finally{busy=false;await refresh();}
}
$('send').onclick=()=>submit(state?.workflows.find(w=>w.id===$('workflow').value),$('input').value);
for(const [id,command] of [['modelOff','model off'],['modelOn','model on'],['modelStatus','model status']])$(id).onclick=()=>submit(authoring(),command,command);
$('createShortcut').onclick=()=>openBuilder();
$('addCommand').onclick=()=>{const values=[...$('shortcutSteps').querySelectorAll('textarea')].map(e=>e.value);if(values.length<10)stepFields([...values,'']);};
$('cancelShortcut').onclick=()=>{delete session.shortcutDraft;void saved('put',session);navigate('all');};
let builderTimer;$('shortcutForm').addEventListener('input',()=>{if(!session)return;session.shortcutDraft={name:$('shortcutName').value,steps:[...$('shortcutSteps').querySelectorAll('textarea')].map(e=>e.value),...(editingShortcut?{id:editingShortcut.id,revision:editingShortcut.revision}:{})};clearTimeout(builderTimer);builderTimer=setTimeout(()=>void saved('put',session),300);});
$('editShortcut').onclick=()=>{const w=state?.workflows.find(w=>w.id===$('workflow').value);if(w?.userCreated)void submit(authoring(),'studio.shortcut/1\n'+JSON.stringify({operation:'load',id:w.id}),'Edit '+w.name);};
$('shortcutForm').onsubmit=event=>{event.preventDefault();const name=$('shortcutName').value.trim(),steps=[...$('shortcutSteps').querySelectorAll('textarea')].map(e=>e.value.trim());if(!name||!steps.length||steps.some(s=>!s)||steps.reduce((n,s)=>n+encoder.encode(s).length,0)>4000){notice('Enter a name and nonempty commands, up to 4,000 bytes total.');return;}const draft={operation:'save',name,steps,...(editingShortcut?{id:editingShortcut.id,revision:editingShortcut.revision}:{})};void submit(authoring(),'studio.shortcut/1\n'+JSON.stringify(draft),'Save '+name);};
$('refresh').onclick=async()=>{if(pending){try{await api('/api/runs/'+pending.id);pending=null;session.pending=null;await saved('put',session);}catch(e){if(e.message==='NOT_FOUND'){pending=null;session.pending=null;await saved('put',session);notice('No gateway receipt found. Nothing is being retried. Send again explicitly if desired.');}else notice(e.message);}}await refresh();};
$('workflow').onchange=selectWorkflow;let draftTimer;$('input').oninput=()=>{$('inputCount').textContent=encoder.encode($('input').value).length+' / 16 KiB';if(session){session.drafts=session.drafts||{};session.drafts[$('workflow').value]=$('input').value;clearTimeout(draftTimer);draftTimer=setTimeout(()=>void saved('put',session),300);}};
$('search').oninput=library;$('sidebarToggle').onclick=()=>document.body.classList.toggle('sidebarOpen');$('navAll').onclick=()=>navigate('all');$('navAssistant').onclick=()=>navigate('assistant');$('navHistory').onclick=()=>navigate('history');$('toolbarRefresh').onclick=()=>void refresh();
$('tabResult').onclick=()=>{$('inbox').hidden=false;$('runLog').hidden=true;$('tabResult').classList.add('active');$('tabLog').classList.remove('active');};$('tabLog').onclick=()=>{$('inbox').hidden=true;$('runLog').hidden=false;$('tabLog').classList.add('active');$('tabResult').classList.remove('active');};
$('disconnect').onclick=async()=>{if(!confirm('Revoke this phone and remove its local credential?'))return;try{await api('/api/device',undefined,'DELETE');}catch{notice('Could not revoke on relay. Revoke this phone from your Mac.');return;}await saved('delete');session=null;state=null;pending=null;await render();notice('Phone disconnected.');};
$('testNotification').onclick=async()=>{try{const result=await api('/api/push-test',{});notice(result.httpStatus===201?'Test alert accepted by the push service. Check your phone notification shade.':result.status);}catch(e){notice(e.message);}};
$('notifications').onclick=async()=>{try{if(!session||!state)throw Error('Pair with your Mac first.');
 if(!registration||!('PushManager' in window))throw Error('Push is not supported in this browser.');const permission=await Notification.requestPermission();if(permission!=='granted')throw Error('Notifications were not enabled. Results remain in your inbox.');
 const subscription=await registration.pushManager.getSubscription()||await registration.pushManager.subscribe({userVisibleOnly:true,applicationServerKey:urlRaw(state.pushPublicKey)});await api('/api/push',{subscription:subscription.toJSON()});$('notifications').replaceChildren(element('span','♧'),element('span','Notifications enabled'));notice('Completion alerts enabled. Phone settings can delay delivery.');
 }catch(e){notice(e.message);}};
(async()=>{try{if('serviceWorker' in navigator){await navigator.serviceWorker.register('/sw.js');registration=await navigator.serviceWorker.ready;navigator.serviceWorker.addEventListener('message',event=>{if(event.data?.runID){location.hash='run='+event.data.runID;void refresh();}});}session=await saved('get');pending=session?.pending||null;await render();await refresh();setInterval(()=>void refresh(),2000);document.addEventListener('visibilitychange',()=>{if(!document.hidden)void refresh();});}catch(e){notice('This browser could not initialize secure storage: '+e.message);}})();
