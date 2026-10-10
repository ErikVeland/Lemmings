import pathlib, subprocess, json, hashlib, plistlib, xml.etree.ElementTree as E, urllib.request
root=pathlib.Path('.build/release-1.8.4'); ns='{http://www.andymatuschak.org/xml-namespaces/sparkle}'
feed=E.parse('appcast.xml'); prev=E.parse(root/'previous-appcast.xml')
def entries(t): return {i.findtext(ns+'version'):i for i in t.findall('./channel/item')}
old,new=entries(prev),entries(feed)
for k,i in old.items():
 assert k in new
 assert [e.attrib for e in i.iter('enclosure')]==[e.attrib for e in new[k].iter('enclosure')]
item=new['73']; enc=item.find('enclosure'); app=root/'standard/Ultimate Lemmings.app'
info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
archive=root/'updates/UltimateLemmings-1.8.4-build73.zip'
subprocess.run([str(root/'verify-signature'),str(archive),info['SUPublicEDKey'],enc.get(ns+'edSignature')],check=True)
revision=(root/'source-commit.txt').read_text().strip()
result={'version':'1.8.4','build':73,'sourceCommit':revision,'oldFeedEntriesPreserved':len(old),'assets':[]}
for variant,folder,suffix in [('standard','updates',''),('slim','downloads','-slim')]:
 p=root/folder/f'UltimateLemmings-1.8.4-build73{suffix}.zip'
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(8*1024*1024),b''):h.update(b)
 result['assets'].append({'name':p.name,'size':p.stat().st_size,'sha256':h.hexdigest(),'notary':json.loads((root/f'{variant}-notary.json').read_text())})
(root/'publication.json').write_text(json.dumps(result,indent=2)+'\n')
print('PASS local signatures, archive digests and preserved update entries')
