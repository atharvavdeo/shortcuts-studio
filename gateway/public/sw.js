self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',event=>event.waitUntil(self.clients.claim()));
// No caching of authenticated responses, keys, input or output.
self.addEventListener('push',event=>{
  let runID;try{runID=event.data.json().runID;}catch{return;}
  if(typeof runID!=='string'||!/^[a-f0-9-]{36}$/i.test(runID))return;
  event.waitUntil(self.registration.showNotification('Shortcut Studio · Result ready',{body:'Open to view the result from your Mac.',tag:'studio-'+runID,icon:'/icon.svg',data:{runID},actions:[{action:'open',title:'Open result'}]}));
});
self.addEventListener('notificationclick',event=>{
  event.notification.close();const id=event.notification.data?.runID;
  const url='/'+(typeof id==='string'?'#run='+encodeURIComponent(id):'');
  event.waitUntil(self.clients.matchAll({type:'window',includeUncontrolled:true}).then(async clients=>{const client=clients.find(c=>new URL(c.url).origin===self.location.origin);if(client){await client.focus();client.postMessage({runID:id});}else await self.clients.openWindow(url);}));
});
