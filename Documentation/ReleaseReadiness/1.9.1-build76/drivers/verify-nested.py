from pathlib import Path
import subprocess
r=Path('.build/release-1.9.1')
magic={bytes.fromhex(x) for x in ['feedface','feedfacf','cefaedfe','cffaedfe','cafebabe','bebafeca','cafebabf','bfbafeca']}
for variant in ['standard','slim']:
 app=r/variant/'Ultimate Lemmings.app'; paths=[app];seen=set()
 for folder in ['MacOS','Frameworks']:
  for p in (app/'Contents'/folder).rglob('*'):
   if not p.is_file():continue
   resolved=p.resolve()
   if resolved in seen:continue
   seen.add(resolved)
   with p.open('rb') as f: header=f.read(4)
   if header in magic:paths.append(p)
 for p in paths:
  result=subprocess.run(['codesign','-dv','--verbose=4',str(p)],capture_output=True,text=True,check=True)
  details=result.stderr
  assert 'TeamIdentifier=54WU29TRTY' in details,(p,details)
  assert 'runtime' in details,(p,details)
  subprocess.run(['codesign','--verify','--strict',str(p)],check=True,capture_output=True)
 print('PASS',variant,len(paths),'signatures, one Developer ID team and hardened runtime')
