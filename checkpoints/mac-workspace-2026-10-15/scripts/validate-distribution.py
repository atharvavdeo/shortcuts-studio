from pathlib import Path
import hashlib,json,plistlib,subprocess,sys,zipfile,xml.etree.ElementTree as ET
from html.parser import HTMLParser
R=Path(__file__).resolve().parent.parent
checks=[]
def check(ok,label):
 if not ok:raise SystemExit('FAIL: '+label)
 checks.append(label)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
i=plistlib.loads((R/'scripts/Info.plist').read_bytes())
check(i['CFBundleShortVersionString']=='0.6.0','bundle version')
check('tools.shortcutstudio.workflow' in str(i),'workflow UTI')
check(plistlib.loads((R/'scripts/PrivacyInfo.xcprivacy').read_bytes())['NSPrivacyTracking']==False,'privacy parses')
for name in ['docs/.reference-hashes.json','docs/site/.source-hashes.json']:
 h=json.loads((R/name).read_text());check(all((R/p).is_file() and sha(R/p)==v for p,v in h.items()),name+' fresh')
c=json.loads((R/'docs/action-catalog.json').read_text());check(len(c)==67,'67 actions')
for p in (R/'docs/assets').glob('*.svg'):
 ET.parse(p);check('<script' not in p.read_text().lower(),p.name+' safe SVG')
def lum(c):
 v=[int(c[n:n+2],16)/255 for n in (0,2,4)]
 return sum(w*(x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4) for w,x in zip([.2126,.7152,.0722],v))
for c in ['6236AF','165DAC','A52F75','9B450D','1A6938','B02A38','09696F','55555F']:check(1.05/(lum(c)+.05)>=4.5,'tile contrast '+c)
class Links(HTMLParser):
 def __init__(self):super().__init__();self.links=[]
 def handle_starttag(self,tag,attrs):self.links += [v for k,v in attrs if k in ('href','src') and v]
for p in (R/'docs/site').glob('*.html'):
 h=Links();h.feed(p.read_text())
 for url in h.links:
  if not url.startswith(('https:','http:','mailto:','#','data:')):check((p.parent/url.split('#')[0]).is_file(),p.name+' link '+url)
if '--preflight' not in sys.argv:
 a=R/'dist/Shortcut Studio.app'
 check(plistlib.loads((a/'Contents/Info.plist').read_bytes())==i,'bundle metadata matches')
 check((a/'Contents/Resources/PrivacyInfo.xcprivacy').read_bytes()==(R/'scripts/PrivacyInfo.xcprivacy').read_bytes(),'privacy bundled')
 for p in (R/'docs/site').rglob('*'):
  if p.is_file():check((a/'Contents/Resources/Handbook'/p.relative_to(R/'docs/site')).read_bytes()==p.read_bytes(),'help '+p.name)
 subprocess.run(['codesign','--verify','--deep','--strict',str(a)],check=True)
 s=subprocess.run(['codesign','-dv','--verbose=4',str(a)],capture_output=True,text=True,check=True).stderr
 check('runtime' in s,'hardened runtime')
 m=json.loads((R/'verification/build-manifest.json').read_text())
 check(sha(a/'Contents/MacOS/ShortcutStudio')==m['binarySHA256'],'binary provenance')
 check(all(sha(R/p)==v for p,v in m['sourceSHA256'].items()),'source provenance')
 with zipfile.ZipFile(R/'dist/Shortcut-Studio-Source.zip') as z:
  check(all(not any(x in {'.build','.git','.swiftpm','__pycache__','.DS_Store','library.json','node_modules','.wrangler','.dev.vars'} for x in Path(n).parts) for n in z.namelist()),'source excludes runtime data')
  check(all(z.read('ShortcutStudio/'+p)==(R/p).read_bytes() for p in m['sourceSHA256']),'source ZIP matches')
 for line in (R/'dist/SHA256SUMS').read_text().splitlines():
  v,n=line.split('  ',1);check(sha(R/'dist'/n)==v,'archive checksum '+n)
 (R/'verification/distribution-validation.json').write_text(json.dumps({'status':'PASS','checks':checks,'limits':'Mechanical checks only; no Apple certification or exhaustive accessibility claim.'},indent=2)+'\n')
print(f'PASS: {len(checks)} mechanical distribution checks')
