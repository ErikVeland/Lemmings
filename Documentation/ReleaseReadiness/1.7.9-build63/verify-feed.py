from pathlib import Path
from xml.etree import ElementTree as ET
import hashlib,json,plistlib,subprocess
root=Path(__file__).resolve().parent
repo=root.parent.parent
ns='http://www.andymatuschak.org/xml-namespaces/sparkle'
def value(item,name):
 return item.findtext(f'{{{ns}}}{name}') or item.find('enclosure').get(f'{{{ns}}}{name}')
def entries(path):
 return {(value(i,'shortVersionString'),value(i,'version')):i for i in ET.parse(path).getroot().findall('./channel/item')}
before=entries(root/'appcast-live-before.xml');after=entries(repo/'appcast.xml')
assert set(after)==set(before)|{('1.7.9','63')}
for key,item in before.items():
 assert after[key].find('enclosure').attrib==item.find('enclosure').attrib,key
item=after[('1.7.9','63')];enclosure=item.find('enclosure')
full=json.loads((root/'standard-final-archive.json').read_text())
source=(root/'source-commit.txt').read_text().strip()
archive=root/'updates'/full['archive']
assert full['sourceCommit']==source
assert archive.stat().st_size==full['size']
assert hashlib.file_digest(archive.open('rb'),'sha256').hexdigest()==full['sha256']
assert enclosure.get('url')=='https://github.com/ErikVeland/Lemmings/releases/download/v1.7.9/'+archive.name
assert enclosure.get('length')==str(full['size'])
assert f'Release commit: {source}' in item.findtext('description','')
assert all('-slim.zip' not in i.find('enclosure').get('url','') for i in after.values())
with (root/'standard/Ultimate Lemmings.app/Contents/Info.plist').open('rb') as f: info=plistlib.load(f)
assert info['CFBundleShortVersionString']=='1.7.9' and info['CFBundleVersion']=='63'
subprocess.run([str(root/'verify-signature'),str(archive),info['SUPublicEDKey'],enclosure.get(f'{{{ns}}}edSignature')],check=True)
report={'version':'1.7.9','build':63,'sourceCommit':source,'archive':archive.name,'archiveBytes':full['size'],'archiveSHA256':full['sha256'],'appcastSHA256':hashlib.sha256((repo/'appcast.xml').read_bytes()).hexdigest(),'priorEnclosuresPreserved':len(before),'sparkleSignatureVerified':True,'slimExcludedFromEnclosures':True}
(root/'feed-verification.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
