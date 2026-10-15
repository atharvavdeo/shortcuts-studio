from pathlib import Path
import datetime,hashlib,json,plistlib,subprocess,zipfile,sys
ROOT=Path(__file__).resolve().parent.parent
D=ROOT/'dist'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
files=[ROOT/n for n in ['Package.swift','README.md','VERIFICATION.md','.gitignore'] if (ROOT/n).is_file()]
for name in ['Sources','Tests','scripts','docs','examples','verification','gateway']:
 files += [p for p in (ROOT/name).rglob('*') if p.is_file() and not p.is_symlink() and not any(x in {'.build','.git','.swiftpm','__pycache__','.DS_Store','node_modules','.wrangler','.dev.vars'} for x in p.relative_to(ROOT).parts) and not p.name.startswith('.dev.vars') and p.name not in {'build-manifest.json','distribution-validation.json'}]
a=D/'Shortcut Studio.app'
m={'createdUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'configuration':sys.argv[1] if len(sys.argv)>1 else 'release','version':plistlib.loads((a/'Contents/Info.plist').read_bytes())['CFBundleShortVersionString'],'signingDetails':subprocess.run(['codesign','-dv','--verbose=4',str(a)],capture_output=True,text=True,check=True).stderr,'sourceSHA256':{str(p.relative_to(ROOT)):sha(p) for p in sorted(files)},'binarySHA256':sha(a/'Contents/MacOS/ShortcutStudio')}
(ROOT/'verification/build-manifest.json').write_text(json.dumps(m,indent=2)+'\n')
with zipfile.ZipFile(D/'Shortcut-Studio-Source.zip','w',zipfile.ZIP_DEFLATED) as z:
 for p in sorted(files)+[ROOT/'verification/build-manifest.json']:z.write(p,'ShortcutStudio/'+str(p.relative_to(ROOT)))
names=['Shortcut-Studio-macOS.zip','Shortcut-Studio-Source.zip']
(D/'SHA256SUMS').write_text(''.join(f'{sha(D/n)}  {n}\n' for n in names))
print('Local source archive and SHA256SUMS created.')
