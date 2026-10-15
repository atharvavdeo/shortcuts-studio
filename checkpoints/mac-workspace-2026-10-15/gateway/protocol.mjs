import crypto from 'node:crypto';
const terminal=new Set(['Completed','Failed','Cancelled','Interrupted','Rejected','DeliveryExpired','NeedsLocalAttention']);
export function createGatewayHandler({initialState,macToken,clock=()=>Date.now(),push,saveState=()=>{},staticAsset,background=p=>{void p.catch(()=>{});}}) {
  let state=initialState||{devices:{},pairs:{},runs:{},mac:{seen:0,workflows:[],status:'Offline'},vapid:push.generateVAPIDKeys()};
  push.setVapidDetails('https://shortcutstudio.local',state.vapid.publicKey,state.vapid.privateKey);
  const rates=new Map();let challenge=state.challenge||null;
  function save(){state.challenge=challenge;saveState(state);}
  function fail(code,status=400){throw Object.assign(new Error(code),{status});}
  function safeEqual(a,b){return typeof a==='string'&&typeof b==='string'&&Buffer.byteLength(a)===Buffer.byteLength(b)&&crypto.timingSafeEqual(Buffer.from(a),Buffer.from(b));}
  function auth(req,role){const token=req.headers.authorization?.replace(/^Bearer /,'');if(role==='mac'){if(!safeEqual(token,macToken))fail('UNAUTHORIZED',401);return;}
    const device=Object.values(state.devices).find(d=>!d.revoked&&safeEqual(d.token,token));if(!device)fail('UNAUTHORIZED',401);return device;}
  function rate(key,limit){const now=clock();const r=rates.get(key);if(!r||now-r.start>60000){rates.set(key,{start:now,n:1});}else if(++r.n>limit)fail('RATE_LIMIT',429);if(rates.size>10000)rates.clear();}
  function exact(o,keys){if(!o||Array.isArray(o)||typeof o!=='object'||Object.keys(o).some(k=>!keys.includes(k)))fail('INVALID_BODY');}
  function uuid(x){return typeof x==='string'&&/^[0-9a-f-]{36}$/i.test(x);}
  function ciphertext(x){return typeof x==='string'&&x.length<=50000&&/^[A-Za-z0-9+/=]+$/.test(x);}
  function summary(r){return {id:r.id,deviceID:r.deviceID,state:r.state,createdAt:r.createdAt,updatedAt:r.updatedAt,output:r.output||null,message:r.message||'',cancelRequested:!!r.cancelRequested};}
  async function notify(run){
    const d=state.devices[run.deviceID];if(!d?.subscription)return {status:'Not registered'};
    try{const response=await push.sendNotification(d.subscription,JSON.stringify({runID:run.id}),{TTL:300,urgency:'high'});d.pushStatus='Accepted by push service';d.pushHTTP=response?.statusCode||0;save();return {status:d.pushStatus,httpStatus:d.pushHTTP};}
    catch(e){d.pushStatus='Push service rejected delivery';d.pushHTTP=e.statusCode||0;if([404,410].includes(e.statusCode))delete d.subscription;save();return {status:d.pushStatus,httpStatus:d.pushHTTP};}
  }
  async function body(req){if(!req.headers['content-type']?.startsWith('application/json'))fail('JSON_REQUIRED',415);let size=0,chunks=[];for await(const c of req){size+=c.length;if(size>65536)fail('BODY_TOO_LARGE',413);chunks.push(c);}try{return JSON.parse(Buffer.concat(chunks).toString('utf8'));}catch{fail('INVALID_JSON');}}
  async function route(req,res){
    res.setHeader('Cache-Control','no-store');res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('Referrer-Policy','no-referrer');res.setHeader('X-Frame-Options','DENY');
    res.setHeader('Content-Security-Policy',"default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self' data:; frame-ancestors 'none'; base-uri 'none'; form-action 'self'");
    const u=new URL(req.url,'http://local');
    try {
      rate(req.socket.remoteAddress||'unknown',400);
      // Mutations from a browser must come from this exact origin. Native connector has no Origin header.
      if(req.headers.origin&&req.headers.origin!==`${req.headers['x-forwarded-proto']||'http'}://${req.headers.host}`)fail('WRONG_ORIGIN',403);
      let result;
      if(req.method==='GET'&&u.pathname==='/health')result={ok:true,protocol:'studio.messenger/1'};
      else if(u.pathname.startsWith('/mac/')) {
        auth(req,'mac');
        if(req.method==='GET'&&u.pathname==='/mac/poll'){
          state.mac.seen=clock();
          for(const r of Object.values(state.runs)){if(r.state==='Sent'&&r.expiresAt<clock()){r.state='DeliveryExpired';r.message='Command expired before Mac acceptance';r.updatedAt=clock();}}
          save();result={activeDevices:Object.values(state.devices).filter(d=>!d.revoked).map(d=>d.id),revokedDevices:Object.values(state.devices).filter(d=>d.revoked).map(d=>d.id),pairs:Object.values(state.pairs).filter(p=>p.expiresAt>clock()&&p.state==='Pending').map(({id,publicKey,label})=>({id,publicKey,label})),commands:Object.values(state.runs).filter(r=>!terminal.has(r.state)).map(({id,deviceID,payload,expiresAt,cancelRequested,state})=>({id,deviceID,payload,expiresAt,state,cancelRequested:!!cancelRequested}))};
        } else if(req.method==='POST'&&u.pathname==='/mac/challenge') {challenge={code:crypto.randomInt(100000,1000000).toString(),expiresAt:clock()+300000};save();result=challenge;}
        else if(req.method==='POST'&&u.pathname==='/mac/snapshot') {
          const b=await body(req);exact(b,['workflows','status','decisions','updates','revoke']);
          if(!Array.isArray(b.workflows)||b.workflows.length>50)fail('INVALID_WORKFLOWS');
          state.mac={seen:clock(),status:String(b.status||'Ready').slice(0,100),workflows:b.workflows.map(w=>{exact(w,['id','name','revision','usesModel','color','symbol','actionCount','actionTitles','userCreated','canCreate','requiresInput']);if(!uuid(w.id)||!/^[a-f0-9]{64}$/.test(w.revision)||typeof w.name!=='string')fail('INVALID_WORKFLOW');return {...w,userCreated:w.userCreated===true,canCreate:w.canCreate===true,requiresInput:w.requiresInput===true,name:w.name.slice(0,160),color:typeof w.color==='string'?w.color.slice(0,16):'purple',symbol:typeof w.symbol==='string'?w.symbol.slice(0,80):'square.stack',actionCount:Number.isInteger(w.actionCount)?w.actionCount:0,actionTitles:Array.isArray(w.actionTitles)?w.actionTitles.slice(0,6).map(t=>String(t).slice(0,64)):[]};})};
          for(const decision of b.decisions||[]){const p=state.pairs[decision.id];if(!p||p.state!=='Pending'||p.expiresAt<clock())continue;if(decision.approved){if(!/^[A-Za-z0-9+/=]{80,100}$/.test(decision.macPublicKey))fail('INVALID_KEY');const token=crypto.randomBytes(32).toString('base64url');state.devices[p.id]={id:p.id,token,label:p.label};p.state='Approved';p.token=token;p.macPublicKey=decision.macPublicKey;}else p.state='Rejected';}
          for(const id of b.revoke||[]){if(state.devices[id]){state.devices[id].revoked=true;delete state.devices[id].subscription;for(const r of Object.values(state.runs).filter(r=>r.deviceID===id&&!terminal.has(r.state)))r.cancelRequested=true;}}
          const notifications=[];
          for(const update of b.updates||[]){const r=state.runs[update.id];if(!r||terminal.has(r.state))continue;
            if(!['Accepted','Running',...terminal].includes(update.state)||update.output&&!ciphertext(update.output))fail('INVALID_UPDATE');
            const was=r.state;r.state=update.state;r.updatedAt=clock();r.output=update.output||null;r.message=String(update.message||'').slice(0,180);if(was!==r.state&&terminal.has(r.state))notifications.push(r);
          }save();for(const r of notifications)background(notify(r));result={ok:true};
        }else fail('NOT_FOUND',404);
      } else if(req.method==='POST'&&u.pathname==='/api/pair'){
        rate('pair:'+req.socket.remoteAddress,8);const b=await body(req);exact(b,['code','publicKey','label']);
        if(!challenge||challenge.expiresAt<clock()||!safeEqual(b.code,challenge.code))fail('PAIR_CODE_INVALID',403);
        if(typeof b.publicKey!=='string'||!/^[A-Za-z0-9+/=]{80,100}$/.test(b.publicKey))fail('INVALID_KEY');
        if(Object.keys(state.devices).length>=20)fail('DEVICE_LIMIT',409);
        const id=crypto.randomUUID(),ticket=crypto.randomBytes(32).toString('base64url');state.pairs[id]={id,ticket,publicKey:b.publicKey,label:String(b.label||'Android phone').slice(0,80),state:'Pending',expiresAt:clock()+300000};challenge=null;save();result={id,ticket};
      } else if(req.method==='POST'&&u.pathname==='/api/pair-status'){
        const b=await body(req);exact(b,['id','ticket']);const p=state.pairs[b.id];if(!p||p.expiresAt<clock()||!safeEqual(p.ticket,b.ticket))fail('PAIR_EXPIRED',403);result={state:p.state,id:p.id,...(p.state==='Approved'?{token:p.token,macPublicKey:p.macPublicKey}:{})};
      } else if(u.pathname.startsWith('/api/')){
        const d=auth(req,'phone');rate('device:'+d.id,180);
        if(req.method==='GET'&&u.pathname==='/api/state'){
          result={deviceID:d.id,online:clock()-state.mac.seen<10000,macStatus:state.mac.status,workflows:state.mac.workflows,runs:Object.values(state.runs).filter(r=>r.deviceID===d.id).slice(-100).reverse().map(summary),pushPublicKey:state.vapid.publicKey,pushRegistered:!!d.subscription,pushStatus:d.pushStatus||null};
        }else if(req.method==='POST'&&u.pathname==='/api/runs'){
          const b=await body(req);exact(b,['id','payload']);if(!uuid(b.id)||!ciphertext(b.payload))fail('INVALID_COMMAND');
          const existing=state.runs[b.id];if(existing){if(existing.deviceID!==d.id)fail('NOT_FOUND',404);if(existing.payload!==b.payload)fail('REQUEST_CONFLICT',409);result=summary(existing);}
          else{if(clock()-state.mac.seen>=10000)fail('MAC_OFFLINE',409);if(Object.values(state.runs).some(r=>!terminal.has(r.state)))fail('BUSY',409);if(Object.keys(state.runs).length>=1000)fail('SESSION_FULL',409);const now=clock();const r={id:b.id,deviceID:d.id,payload:b.payload,state:'Sent',createdAt:now,updatedAt:now,expiresAt:now+60000};state.runs[b.id]=r;save();result=summary(r);}
        }else if(req.method==='GET'&&/^\/api\/runs\/[^/]+$/.test(u.pathname)){const id=u.pathname.split('/')[3],r=state.runs[id];if(!r||r.deviceID!==d.id)fail('NOT_FOUND',404);result=summary(r);}
        else if(req.method==='POST'&&/^\/api\/runs\/[^/]+\/cancel$/.test(u.pathname)){
          const id=u.pathname.split('/')[3],r=state.runs[id];if(!r||r.deviceID!==d.id)fail('NOT_FOUND',404);r.cancelRequested=true;if(r.state==='Sent'){r.state='Cancelled';r.updatedAt=clock();}save();result=summary(r);
        }else if(req.method==='POST'&&u.pathname==='/api/push-test'){const run=Object.values(state.runs).reverse().find(r=>r.deviceID===d.id&&terminal.has(r.state));if(!run)fail('RUN_A_WORKFLOW_FIRST',409);result=await notify(run);}
        else if(req.method==='POST'&&u.pathname==='/api/push'){
          const b=await body(req);exact(b,['subscription']);let endpoint;try{endpoint=new URL(b.subscription?.endpoint);}catch{fail('INVALID_SUBSCRIPTION');}
          // Restrict destinations: never let subscription registration become an arbitrary server fetch.
          if(endpoint.protocol!=='https:'||!['fcm.googleapis.com','updates.push.services.mozilla.com','web.push.apple.com'].includes(endpoint.hostname)||endpoint.port||endpoint.username||endpoint.password||JSON.stringify(b.subscription).length>4096)fail('INVALID_SUBSCRIPTION');
          d.subscription=b.subscription;d.pushStatus='Registered';save();result={ok:true};
        }else if(req.method==='DELETE'&&u.pathname==='/api/device'){d.revoked=true;delete d.subscription;for(const r of Object.values(state.runs).filter(r=>r.deviceID===d.id&&!terminal.has(r.state)))r.cancelRequested=true;save();result={ok:true};}
        else fail('NOT_FOUND',404);
      }else if(req.method==='GET'){
        const allowed={'/':'index.html','/app.js':'app.js','/style.css':'style.css','/sw.js':'sw.js','/manifest.webmanifest':'manifest.webmanifest','/icon.svg':'icon.svg'};
        const name=allowed[u.pathname];if(!name)fail('NOT_FOUND',404);
        res.setHeader('Content-Type',({'html':'text/html; charset=utf-8','js':'text/javascript; charset=utf-8','css':'text/css; charset=utf-8','svg':'image/svg+xml','webmanifest':'application/manifest+json'})[name.split('.').pop()]);res.end(await staticAsset(name));return;
      }else fail('NOT_FOUND',404);
      res.setHeader('Content-Type','application/json');res.end(JSON.stringify(result));
    }catch(e){res.statusCode=e.status||500;res.setHeader('Content-Type','application/json');res.end(JSON.stringify({error:e.status?e.message:'SERVER_ERROR'}));}
  }
  return route;
}
