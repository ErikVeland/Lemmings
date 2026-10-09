import pathlib,json,subprocess,urllib.request,base64,plistlib
r=pathlib.Path('.build/release-1.8.4'); p=json.loads((r/'publication.json').read_text())
def api(path): return json.loads(subprocess.check_output(['gh','api','repos/ErikVeland/Lemmings/'+path],text=True))
release=api('releases/tags/v1.8.4'); assert not release['draft'] and not release['prerelease']
ref=api('git/ref/tags/v1.8.4'); assert ref['object']['sha']==p['sourceCommit']
assets={x['name']:x for x in release['assets']}
for a in p['assets']:
 remote=assets[a['name']]; assert remote['size']==a['size']; assert remote['digest']=='sha256:'+a['sha256']
 req=urllib.request.Request(remote['browser_download_url'],headers={'Range':'bytes=0-3'})
 with urllib.request.urlopen(req,timeout=90) as response: assert response.read(4)==b'PK\x03\x04'
 a['url']=remote['browser_download_url']; a['remoteDigestVerified']=True; a['zipResponseVerified']=True
feed=api('contents/appcast.xml?ref=main'); assert base64.b64decode(feed['content'])==pathlib.Path('appcast.xml').read_bytes()
info=plistlib.loads((r/'standard/Ultimate Lemmings.app/Contents/Info.plist').read_bytes())
rawURL=info['SUFeedURL']
request=urllib.request.Request(rawURL,headers={'Cache-Control':'no-cache'})
with urllib.request.urlopen(request,timeout=30) as response:
 assert response.read()==pathlib.Path('appcast.xml').read_bytes()
p['rawFeedVerified']=True; p['rawFeedURL']=rawURL
p['releaseURL']=release['html_url']; p['publishedAt']=release['published_at']; p['remoteTagVerified']=True; p['mainFeedVerified']=True
(r/'publication.json').write_text(json.dumps(p,indent=2)+'\n')
print('PASS public release tag, both remote SHA256 digests/sizes/ZIP responses, and live main and raw Sparkle update feeds')
