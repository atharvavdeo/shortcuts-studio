import {createGateway} from '../server.mjs';import crypto from 'node:crypto';import {spawn} from 'node:child_process';
const token=crypto.randomBytes(32).toString('base64url');
const server=createGateway({macToken:token,push:{setVapidDetails(){},async sendNotification(){}}});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const origin='http://127.0.0.1:'+server.address().port;console.log('BROWSER_FIXTURE '+origin);
const child=spawn(process.argv[2],[origin],{env:{...process.env,STUDIO_INTEROP_TOKEN:token,STUDIO_BROWSER_FIXTURE:'1'}});
child.stdout.pipe(process.stdout);child.stderr.pipe(process.stderr);
function stop(){child.kill();server.close();}
process.on('SIGTERM',stop);process.on('SIGINT',stop);child.on('exit',()=>server.close());
