from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import subprocess,os,json
root=Path.cwd(); r=root/'.build/release-1.9.2'; out=r/'trolley/results'; out.mkdir(parents=True,exist_ok=True)
env=dict(os.environ,TROLLEY_OUTPUT=str(out),TROLLEY_RESOURCES=str(root/'.build/release-1.9.1/standard/Ultimate Lemmings.app/Contents/Resources'))
tasks=[('classic-'+str(i),['classic','--shard='+str(i)+'/8']) for i in range(8)]+[(x,[x]) for x in ['ports','l2','l3']]
def run(item):
 name,args=item
 with (r/(name+'-proofs.log')).open('w') as log:
  p=subprocess.run([str(r/'trolley-audit'),*args],env=env,stdout=log,stderr=subprocess.STDOUT)
 print(name,p.returncode,flush=True);return p.returncode
with ThreadPoolExecutor(max_workers=4) as pool: results=list(pool.map(run,tasks))
assert not any(results),results
subprocess.run(['python3','Tools/TrolleyVerification/catalogue.py','merge','--results',str(out),'--shards','8'],check=True)
subprocess.run(['python3','Tools/TrolleyVerification/catalogue.py','check'],check=True)
