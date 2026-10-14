import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import webpush from 'web-push';
import {createGatewayHandler} from './protocol.mjs';
const home=path.dirname(fileURLToPath(import.meta.url));
export function createGateway({stateFile,macToken,clock=()=>Date.now(),push=webpush}={}) {
  let initialState;
  if(stateFile&&fs.existsSync(stateFile)) {initialState=JSON.parse(fs.readFileSync(stateFile));initialState.mac.seen=0;initialState.pairs={};initialState.challenge=null;}
  initialState ||= {devices:{},pairs:{},runs:{},mac:{seen:0,workflows:[],status:'Offline'},vapid:webpush.generateVAPIDKeys()};
  const route=createGatewayHandler({initialState,macToken,clock,push,
    saveState(state){if(stateFile){fs.mkdirSync(path.dirname(stateFile),{recursive:true,mode:0o700});const tmp=stateFile+'.tmp';fs.writeFileSync(tmp,JSON.stringify(state),{mode:0o600});fs.renameSync(tmp,stateFile);}},
    staticAsset:name=>fs.readFileSync(path.join(home,'public',name))
  });
  const server=http.createServer((req,res)=>void route(req,res));server.requestTimeout=10000;server.headersTimeout=12000;return server;
}
if(process.argv[1]===fileURLToPath(import.meta.url)){
 const dir=process.env.STUDIO_GATEWAY_DIR||path.join(home,'../.gateway-runtime');fs.mkdirSync(dir,{recursive:true,mode:0o700});
 const tokenFile=path.join(dir,'mac-token');if(!fs.existsSync(tokenFile))fs.writeFileSync(tokenFile,crypto.randomBytes(32).toString('base64url'),{mode:0o600});
 createGateway({stateFile:path.join(dir,'relay-state.json'),macToken:fs.readFileSync(tokenFile,'utf8').trim()}).listen(Number(process.env.PORT||8787),'127.0.0.1',()=>console.log('Messenger listening on 127.0.0.1:'+ (process.env.PORT||8787)));
}
