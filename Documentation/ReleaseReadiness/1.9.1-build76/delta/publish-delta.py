import base64, datetime, hashlib, json, pathlib, subprocess, time, urllib.request
r=pathlib.Path('.build/delta-1.9.1'); evidence=pathlib.Path('Documentation/ReleaseReadiness/1.9.1-build76')
p=json.loads((r/'delta-verification.json').read_text())
def api(path):return json.loads(subprocess.check_output(['gh','api','repos/ErikVeland/Lemmings/'+path],text=True))
def save():
 (r/'delta-publication.json').write_text(json.dumps(p,indent=2)+'\n')
 (evidence/'delta/delta-publication.json').write_bytes((r/'delta-publication.json').read_bytes())
 hashes={str(x.relative_to(evidence)):hashlib.sha256(x.read_bytes()).hexdigest() for x in sorted(evidence.rglob('*')) if x.is_file() and x.name!='evidence-manifest.json'}
 (evidence/'evidence-manifest.json').write_text(json.dumps(hashes,indent=2)+'\n')
if __import__('sys').argv[1]=='asset':
 release=api('releases/tags/v1.9.1'); assert not release['draft'] and not release['prerelease']
 ref=api('git/ref/tags/v1.9.1'); assert ref['object']['sha']=='9ba3fc25c42a57cd89394680d46e5aee79ba3d44'
 asset=next(a for a in release['assets'] if a['name']==p['delta']['name'])
 assert asset['size']==p['delta']['bytes'] and asset['digest']=='sha256:'+p['delta']['sha256']
 with urllib.request.urlopen(asset['browser_download_url'],timeout=60) as response:data=response.read()
 assert hashlib.sha256(data).hexdigest()==p['delta']['sha256']
 p.update(remoteAssetVerified=True,publicDownloadVerified=True)
 save(); print('PASS public delta asset bytes and SHA256 digest')
else:
 p=json.loads((r/'delta-publication.json').read_text())
 expected=pathlib.Path('appcast.xml').read_bytes()
 feed=api('contents/appcast.xml?ref=main'); assert base64.b64decode(feed['content'])==expected
 url='https://raw.githubusercontent.com/ErikVeland/Lemmings/main/appcast.xml'
 for attempt in range(6):
  with urllib.request.urlopen(url,timeout=30) as response:actual=response.read()
  if actual==expected:break
  time.sleep(10)
 assert actual==expected, 'Raw appcast has not refreshed yet'
 p.update(mainFeedVerified=True,rawFeedVerified=True,feedSha256=hashlib.sha256(expected).hexdigest(),publishedAt=datetime.datetime.now(datetime.timezone.utc).isoformat())
 save(); print('PASS main and exact raw Sparkle feed include the verified delta')
