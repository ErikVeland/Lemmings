from pathlib import Path
import json, hashlib
r=Path('.build/release-1.8.5')
full=r/'standard/Ultimate Lemmings.app/Contents/Resources/Music'
slim=r/'slim/Ultimate Lemmings.app/Contents/Resources/Music'
def read(p): return json.loads(p.read_text())
assert read(full/'recording-playback.json')['variants']==read(slim/'recording-playback.json')['variants']
assert read(slim/'bundle.json')['scope']=='main'
assert read(full/'catalogue.json')==read(slim/'catalogue.json')
a,b=read(full/'libraries.json'),read(slim/'libraries.json')
assert [{k:x[k] for k in ('id','url','bytes','sha256','files')} for x in a['packs']]==[{k:x[k] for k in ('id','url','bytes','sha256','files')} for x in b['packs']]
for p in slim.rglob('*'):
 if p.is_file() and p.suffix.lower() not in ['.json','.md','.txt']:
  q=full/p.relative_to(slim)
  assert q.is_file() and hashlib.sha256(p.read_bytes()).digest()==hashlib.sha256(q.read_bytes()).digest(),str(p)
print('PASS unchanged catalogue, all recording playback profiles, optional-library archive bindings and every retained music file')
