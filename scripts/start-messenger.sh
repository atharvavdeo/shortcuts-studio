#!/bin/bash
set -euo pipefail
STUDIO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$STUDIO_ROOT"
mkdir -p .gateway-runtime
chmod 700 .gateway-runtime
node gateway/server.mjs &
STUDIO_SERVER_PID=$!
trap 'kill "$STUDIO_SERVER_PID" 2>/dev/null || true' EXIT
STUDIO_TUNNEL="${STUDIO_CLOUDFLARED:-$STUDIO_ROOT/.gateway-runtime/cloudflared}"
if [[ ! -x "$STUDIO_TUNNEL" ]]; then echo 'Set STUDIO_CLOUDFLARED to your installed official cloudflared binary.' >&2; exit 1; fi
if [[ -n "${STUDIO_GATEWAY_ORIGIN:-}" ]]; then
 [[ -n "${STUDIO_TUNNEL_TOKEN_FILE:-}" && -f "$STUDIO_TUNNEL_TOKEN_FILE" ]] || { echo 'Permanent mode requires STUDIO_TUNNEL_TOKEN_FILE for your named tunnel.' >&2; exit 1; }
 python3 - <<'CHECK_ORIGIN'
import os,urllib.parse
u=urllib.parse.urlsplit(os.environ['STUDIO_GATEWAY_ORIGIN'])
assert u.scheme=='https' and u.hostname and not u.username and not u.password and not u.query and not u.fragment and u.path in ('','/'), 'Use a plain HTTPS gateway origin'
CHECK_ORIGIN
 "$STUDIO_TUNNEL" tunnel run --token-file "$STUDIO_TUNNEL_TOKEN_FILE" > .gateway-runtime/tunnel.log 2>&1 &
else
 "$STUDIO_TUNNEL" tunnel --url http://127.0.0.1:8787 > .gateway-runtime/tunnel.log 2>&1 &
fi
STUDIO_TUNNEL_PID=$!
trap 'kill "$STUDIO_SERVER_PID" "$STUDIO_TUNNEL_PID" 2>/dev/null || true' EXIT
python3 - <<'PY'
from pathlib import Path
import json,os,re,time,urllib.request
root=Path.cwd()
fixed=os.environ.get('STUDIO_GATEWAY_ORIGIN','').rstrip('/')
for _ in range(60):
    if fixed:
        try:
            with urllib.request.urlopen(fixed+'/health',timeout=2) as response:
                if response.status==200:break
        except Exception:pass
        time.sleep(1);continue
    text=(root/'.gateway-runtime/tunnel.log').read_text()
    found=re.search(r'https://[a-z-]+\.trycloudflare.com',text)
    if found:break
    time.sleep(1)
else:raise SystemExit('No tunnel URL. Inspect .gateway-runtime/tunnel.log')
folder=Path.home()/'Library/Application Support/ShortcutStudio';folder.mkdir(parents=True,exist_ok=True)
p=folder/'messenger-bootstrap.json'
origin=fixed or found.group()
p.write_text(json.dumps({'url':origin,'token':(root/'.gateway-runtime/mac-token').read_text().strip()}));os.chmod(p,0o600)
print('Phone URL: '+origin)
print('Restart Studio. Open Messenger → Phone Messenger, Connect, and create a pairing code.')
PY
wait "$STUDIO_TUNNEL_PID"
