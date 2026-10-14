#!/usr/bin/env python3
"""Render a self-contained offline handbook; no JS, remote fonts, or analytics."""
from pathlib import Path
import hashlib, html, json, re, shutil, sys
try:
    import markdown
except ImportError:
    raise SystemExit('Install scripts/requirements-docs.txt to regenerate HTML; packaging can use fresh checked-in HTML.')
ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / 'docs'
SITE = DOCS / 'site'
SITE.mkdir(parents=True, exist_ok=True)
PAGES = sorted(DOCS.glob('*.md')) + [ROOT / 'VERIFICATION.md']
names = {p.name: ('index.html' if p.name == 'HANDBOOK.md' else p.stem + '.html') for p in PAGES}
STYLE = '''body{margin:0;color:#20252c;background:#f5f6f8;font:16px/1.65 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}header{background:#17334b;color:#fff;padding:24px}header a{color:#fff}main{max-width:1080px;margin:28px auto;padding:32px;background:#fff;border-radius:14px}nav{display:flex;gap:10px;flex-wrap:wrap}nav a{font-size:13px}a{color:#145ba3;text-underline-offset:3px}h1,h2,h3{line-height:1.25;scroll-margin-top:24px}h2{margin-top:2em;border-bottom:1px solid #dbe0e7;padding-bottom:8px}table{border-collapse:collapse;width:100%;display:block;overflow:auto;margin:20px 0;font-size:14px}th,td{border:1px solid #dbe0e7;padding:9px 12px;text-align:left;vertical-align:top}th{background:#eef2f6}pre{background:#142b3c;color:#eff7fc;padding:18px;border-radius:8px;overflow:auto;font-size:13px}code{font-family:ui-monospace,SFMono-Regular,Consolas,monospace}p code,li code,td code{background:#eef2f6;padding:2px 4px;border-radius:4px;font-size:.9em}img{max-width:100%;height:auto}blockquote{border-left:4px solid #267289;padding-left:16px;color:#445361}.note,.local-file{color:#526170;font-size:14px}.diagram{margin:20px 0;padding:12px;border:1px solid #dbe0e7;border-radius:10px}footer{max-width:1080px;margin:20px auto;padding:12px;color:#526170;font-size:13px}@media(prefers-color-scheme:dark){body{background:#111920;color:#e6edf3}main{background:#19242e}a{color:#8bbaff}th,p code,li code,td code{background:#253745}th,td,h2{border-color:#40515e}.note,.local-file,footer{color:#a7bac9}}@media(max-width:700px){main{margin:0;padding:20px;border-radius:0}header{padding:18px}table{font-size:12px}}@media print{header nav,footer{display:none}body,main{background:white;color:black}main{margin:0;padding:0}pre{white-space:pre-wrap;background:#f0f0f0;color:black}a{color:black}h2{break-after:avoid}tr,img{break-inside:avoid}}'''
nav = ' '.join(f'<a href="{names[p.name]}">{html.escape(p.stem.replace("_", " ").title())}</a>' for p in PAGES)
for page in PAGES:
    text = page.read_text()
    body = markdown.markdown(text, extensions=['tables','fenced_code','toc'], output_format='html5')
    def links(match):
        target = html.unescape(match.group(1))
        label = match.group(2)
        if target.startswith(('https://','http://','mailto:','#')): return match.group(0)
        parts = target.split('#',1)
        name = Path(parts[0]).name
        if name in names:
            return '<a href="'+names[name]+('#'+parts[1] if len(parts)>1 else '')+'">'+label+'</a>'
        if name.endswith('.json') and (DOCS/name).is_file(): return '<a href="'+html.escape(name)+'">'+label+'</a>'
        # Distribution/source paths cannot be assumed to exist beside an installed app.
        return '<span class="local-file" title="This file is in the source checkout; downloads are linked in its README.">'+label+'</span>'
    body = re.sub(r'<a href="([^"]+)"[^>]*>(.*?)</a>',links,body,flags=re.S)
    diagram_asset = {'SYSTEM_CONSTRUCTION.md':'system-architecture.svg','ANDROID_SCOPE.md':'android-architecture.svg','REMOTE_PROTOCOL_PROPOSAL.md':'remote-states.svg'}.get(page.name)
    used = False
    def diagram(match):
        nonlocal_dummy = None
        return '<details class="diagram"><summary>Editable diagram source</summary><pre><code>'+match.group(1)+'</code></pre></details>'
    if diagram_asset:
        first = re.search(r'<pre><code class="language-mermaid">(.*?)</code></pre>',body,re.S)
        if first:
            replacement = f'<figure class="diagram"><img src="assets/{diagram_asset}" alt="{html.escape(page.stem.replace("_"," ").title())} overview"/><figcaption>Rendered overview; editable Mermaid source is in the chapter Markdown.</figcaption></figure>' + diagram(first)
            body = body[:first.start()] + replacement + body[first.end():]
    body = re.sub(r'<pre><code class="language-mermaid">(.*?)</code></pre>',diagram,body,flags=re.S)
    title = re.search(r'^#\s+(.+)',text,re.M).group(1)
    document = '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta http-equiv="Content-Security-Policy" content="default-src \'none\'; style-src \'unsafe-inline\'; img-src \'self\' data:; font-src \'self\';"><title>'+html.escape(title)+' — Shortcut Studio</title><style>'+STYLE+'</style></head><body><header><strong>Shortcut Studio · offline handbook</strong><nav aria-label="Handbook chapters">'+nav+'</nav></header><main><p class="note">Reviewed 14 October 2026. Local app/source downloads are in the source README. Android browser messenger is implemented; native Android and permanent hosting remain future work.</p>'+body+'</main><footer>Independent macOS workflow application. No Apple approval or full-parity claim. Print this page using your browser’s Print command.</footer></body></html>'
    (SITE/names[page.name]).write_text(document)
shutil.copytree(DOCS/'assets', SITE/'assets', dirs_exist_ok=True)
for file in DOCS.glob('*.json'):
    if not file.name.startswith('.'):
        shutil.copy2(file,SITE/file.name)
inputs = PAGES + sorted((DOCS/'assets').glob('*')) + sorted(DOCS.glob('*.json')) + [Path(__file__).resolve()]
manifest = {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs if p.is_file()}
(SITE/'.source-hashes.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(f'Rendered {len(PAGES)} chapters to docs/site/index.html')
