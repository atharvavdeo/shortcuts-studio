#!/bin/bash
set -euo pipefail
STUDIO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$STUDIO_ROOT"
STUDIO_WRANGLER="$STUDIO_ROOT/gateway/node_modules/.bin/wrangler"
[[ -x "$STUDIO_WRANGLER" ]] || { echo 'Run npm ci --prefix gateway first.' >&2; exit 1; }
mkdir -p .gateway-runtime
chmod 700 .gateway-runtime
node --input-type=module <<'JS'
import fs from 'node:fs';import crypto from 'node:crypto';import path from 'node:path';
const dir='.gateway-runtime';
if(!fs.existsSync(path.join(dir,'mac-token')))fs.writeFileSync(path.join(dir,'mac-token'),crypto.randomBytes(32).toString('base64url'),{mode:0o600});
const identity=path.join(dir,'personal-gateway.json');
if(!fs.existsSync(identity))fs.writeFileSync(identity,JSON.stringify({name:'shortcut-studio-'+crypto.randomBytes(6).toString('hex')}),{mode:0o600});
const owner=JSON.parse(fs.readFileSync(identity));const config=JSON.parse(fs.readFileSync('gateway/cloudflare/wrangler.jsonc'));
config.name=owner.name;delete config.account_id;config.main=path.resolve('gateway/cloudflare/worker.mjs');config.assets.directory=path.resolve('gateway/public');
fs.writeFileSync(path.join(dir,'personal-wrangler.jsonc'),JSON.stringify(config),{mode:0o600});
JS
"$STUDIO_WRANGLER" whoami
"$STUDIO_WRANGLER" deploy --dry-run --config .gateway-runtime/personal-wrangler.jsonc
"$STUDIO_WRANGLER" deploy --config .gateway-runtime/personal-wrangler.jsonc | tee .gateway-runtime/personal-deploy.log
"$STUDIO_WRANGLER" secret put MAC_TOKEN --config .gateway-runtime/personal-wrangler.jsonc < .gateway-runtime/mac-token
python3 - <<'PY'
from pathlib import Path
import json,os,re
runtime=Path('.gateway-runtime')
urls=re.findall(r'https://[a-z0-9.-]+\.workers\.dev', (runtime/'personal-deploy.log').read_text())
if not urls:raise SystemExit('No deployed URL was returned; configuration was not changed.')
url=urls[-1];folder=Path.home()/'Library/Application Support/ShortcutStudio';folder.mkdir(parents=True,exist_ok=True)
file=folder/'messenger-bootstrap.json';file.write_text(json.dumps({'url':url,'token':(runtime/'mac-token').read_text().strip()}));os.chmod(file,0o600)
print('Personal phone URL: '+url)
print('Restart Studio, connect, and pair your phone. Authorize only the workflows and OS permissions you intend to use.')
PY
