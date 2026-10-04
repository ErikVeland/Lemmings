from pathlib import Path
from xml.etree import ElementTree as ET
import hashlib,json,plistlib,subprocess,urllib.request
root=Path(__file__).resolve().parent
repo=root.parent.parent
namespace='http://www.andymatuschak.org/xml-namespaces/sparkle'
def api(path):
    return json.loads(subprocess.check_output(['gh','api','repos/ErikVeland/Lemmings/'+path],text=True))
source=(root/'source-commit.txt').read_text().strip()
release=api('releases/tags/v1.7.8')
assert not release['draft'] and not release['prerelease']
assert api('releases/latest')['tag_name']=='v1.7.8'
ref=api('git/ref/tags/v1.7.8')['object']
if ref['type']=='tag':ref=api('git/tags/'+ref['sha'])['object']
assert ref['type']=='commit' and ref['sha']==source
archives=[]
for prefix in ('slim','standard'):
    local=json.loads((root/(prefix+'-final-archive.json')).read_text())
    asset=next(a for a in release['assets'] if a['name']==local['archive'])
    assert asset['state']=='uploaded' and asset['size']==local['size']
    assert asset['digest']=='sha256:'+local['sha256']
    request=urllib.request.Request(asset['browser_download_url'],headers={'Range':'bytes=0-3','User-Agent':'Lemmings-release-verification'})
    with urllib.request.urlopen(request,timeout=60) as response:
        assert response.status in (200,206)
        assert response.read(4)==b'PK\x03\x04'
        status=response.status
    archives.append({'name':asset['name'],'size':asset['size'],'sha256':asset['digest'][7:],'url':asset['browser_download_url'],'downloadHTTPStatus':status})
feed_url='https://raw.githubusercontent.com/ErikVeland/Lemmings/main/appcast.xml'
request=urllib.request.Request(feed_url,headers={'Cache-Control':'no-cache','User-Agent':'Lemmings-release-verification'})
with urllib.request.urlopen(request,timeout=60) as response:
    feed=response.read()
assert feed==(repo/'appcast.xml').read_bytes()
items=ET.fromstring(feed).findall('./channel/item')
matching=[i for i in items if (i.findtext(f'{{{namespace}}}shortVersionString') or i.find('enclosure').get(f'{{{namespace}}}shortVersionString'))=='1.7.8']
assert len(matching)==1
item=matching[0];enclosure=item.find('enclosure')
assert (item.findtext(f'{{{namespace}}}version') or enclosure.get(f'{{{namespace}}}version'))=='62'
assert enclosure.get('url')==archives[1]['url'] and enclosure.get('length')==str(archives[1]['size'])
assert f'Release commit: {source}' in item.findtext('description','')
assert all('-slim.zip' not in e.get('url','') for i in items for e in i.findall('enclosure'))
info=plistlib.loads((root/'standard/Ultimate Lemmings.app/Contents/Info.plist').read_bytes())
subprocess.run([str(root/'verify-signature'),str(root/'updates'/archives[1]['name']),info['SUPublicEDKey'],enclosure.get(f'{{{namespace}}}edSignature')],check=True)
(root/'public-appcast.xml').write_bytes(feed)
report={'url':release['html_url'],'tag':release['tag_name'],'publishedAt':release['published_at'],'sourceCommit':ref['sha'],'latest':True,'archives':archives,'appcastSHA256':hashlib.sha256(feed).hexdigest(),'feedURL':feed_url,'sparkleSignatureVerified':True}
(root/'publication.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
