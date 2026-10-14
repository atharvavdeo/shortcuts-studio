import { DurableObject } from 'cloudflare:workers';
import webpush from 'web-push';
import {createGatewayHandler} from '../protocol.mjs';
const assetPaths=new Set(['/','/app.js','/style.css','/sw.js','/manifest.webmanifest','/icon.svg']);
const secureHeaders={
  'Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer','X-Frame-Options':'DENY',
  'Content-Security-Policy':"default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self' data:; frame-ancestors 'none'; base-uri 'none'; form-action 'self'"
};
export class Gateway extends DurableObject {
  constructor(ctx,env) {
    super(ctx,env);
    ctx.storage.sql.exec('CREATE TABLE IF NOT EXISTS gateway_records (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    this.rows=new Map(Array.from(ctx.storage.sql.exec('SELECT key,value FROM gateway_records')).map(r=>[r.key,r.value]));
    let initialState;
    if(this.rows.has('meta')) {
      initialState=JSON.parse(this.rows.get('meta'));
      for(const collection of ['devices','pairs','runs']) {
        initialState[collection]={};
        for(const [key,value] of this.rows)if(key.startsWith(collection+':'))initialState[collection][key.slice(collection.length+1)]=JSON.parse(value);
      }
    }
    const push={
      generateVAPIDKeys:()=>webpush.generateVAPIDKeys(),
      setVapidDetails:(...args)=>webpush.setVapidDetails(...args),
      async sendNotification(subscription,payload,options) {
        const details=webpush.generateRequestDetails(subscription,payload,options);
        const response=await fetch(details.endpoint,{method:details.method,headers:details.headers,body:details.body,redirect:'error',signal:AbortSignal.timeout(10000)});
        await response.body?.cancel();
        if(!response.ok)throw Object.assign(new Error('PUSH_REJECTED'),{statusCode:response.status});
        return {statusCode:response.status};
      }
    };
    this.route=createGatewayHandler({initialState,macToken:env.MAC_TOKEN,push,
      background:p=>ctx.waitUntil(p),
      saveState:state=>{
        const next=new Map([['meta',JSON.stringify({mac:state.mac,vapid:state.vapid,challenge:state.challenge})]]);
        for(const collection of ['devices','pairs','runs'])for(const [id,value] of Object.entries(state[collection]))next.set(collection+':'+id,JSON.stringify(value));
        const changed=[...next].filter(([key,value])=>this.rows.get(key)!==value);
        const removed=[...this.rows.keys()].filter(key=>!next.has(key));
        ctx.storage.transactionSync(()=>{
          for(const [key,value] of changed)ctx.storage.sql.exec('INSERT INTO gateway_records(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',key,value);
          for(const key of removed)ctx.storage.sql.exec('DELETE FROM gateway_records WHERE key=?',key);
        });
        this.rows=next;
      },
      staticAsset:()=>{throw new Error('ASSET_ROUTED_TO_GATEWAY');}
    });
  }
  async fetch(request) {
    if(!this.env.MAC_TOKEN)return new Response(JSON.stringify({error:'GATEWAY_NOT_CONFIGURED'}),{status:503,headers:{...secureHeaders,'Content-Type':'application/json'}});
    const chunks=[];let size=0;
    if(request.body) {
      const reader=request.body.getReader();
      try {
        while(true) {
          const {done,value}=await reader.read();if(done)break;
          size+=value.byteLength;
          if(size>65536) { await reader.cancel();return new Response(JSON.stringify({error:'BODY_TOO_LARGE'}),{status:413,headers:{...secureHeaders,'Content-Type':'application/json'}}); }
          chunks.push(Buffer.from(value));
        }
      } finally { reader.releaseLock(); }
    }
    const url=new URL(request.url);
    const headers=Object.fromEntries(request.headers);headers.host=url.host;headers['x-forwarded-proto']=url.protocol.slice(0,-1);
    const req={url:url.pathname+url.search,method:request.method,headers,socket:{remoteAddress:request.headers.get('CF-Connecting-IP')||'unknown'},
      async *[Symbol.asyncIterator](){for(const chunk of chunks)yield chunk;}
    };
    let status=200,body;const out=new Headers(secureHeaders);
    const res={setHeader:(k,v)=>out.set(k,v),end:value=>{body=value;},get statusCode(){return status;},set statusCode(value){status=value;}};
    await this.route(req,res);
    return new Response(body,{status,headers:out});
  }
}
export default {
  async fetch(request,env) {
    const path=new URL(request.url).pathname;
    if(request.method==='GET'&&assetPaths.has(path)) {
      const response=await env.ASSETS.fetch(request);
      const headers=new Headers(response.headers);for(const [key,value] of Object.entries(secureHeaders))headers.set(key,value);
      return new Response(response.body,{status:response.status,headers});
    }
    if(path==='/health'||path.startsWith('/api/')||path.startsWith('/mac/'))return env.GATEWAY.getByName('owner-v1').fetch(request);
    return new Response(JSON.stringify({error:'NOT_FOUND'}),{status:404,headers:{...secureHeaders,'Content-Type':'application/json'}});
  }
};
