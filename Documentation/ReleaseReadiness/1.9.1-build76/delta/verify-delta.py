import hashlib, json, pathlib, plistlib, subprocess, xml.etree.ElementTree as E
r=pathlib.Path('.build/delta-1.9.1'); n='{http://www.andymatuschak.org/xml-namespaces/sparkle}'
old=E.parse(r/'previous-appcast.xml').findall('./channel/item'); new=E.parse(r/'appcast.xml').findall('./channel/item')
assert len(old)==len(new)==8
for a,b in zip(old,new):
 assert a.findtext(n+'version')==b.findtext(n+'version')
 assert a.find('enclosure').attrib==b.find('enclosure').attrib
 assert a.findtext('description')==b.findtext('description')
 if a.findtext(n+'version')!='76':
  assert [x.attrib for x in a.iter('enclosure')]==[x.attrib for x in b.iter('enclosure')]
enc=new[0].find(n+'deltas/enclosure'); assert enc.get(n+'deltaFrom')=='75'
p=r/'UltimateLemmings-build76-from75.delta'; assert str(p.stat().st_size)==enc.get('length')
info=plistlib.loads(pathlib.Path('.build/release-1.9.1/standard/Ultimate Lemmings.app/Contents/Info.plist').read_bytes())
subprocess.run(['.build/release-1.9.1/verify-signature',str(p),info['SUPublicEDKey'],enc.get(n+'edSignature')],check=True)
patched=r/'patched/Ultimate Lemmings.app'; target=pathlib.Path('.build/release-1.9.1/standard/Ultimate Lemmings.app')
def entries(root):return {x.relative_to(root):x for x in root.rglob('*')}
a,b=entries(patched),entries(target); assert a.keys()==b.keys()
files=music=0
for k,x in a.items():
 y=b[k]
 assert x.is_symlink()==y.is_symlink() and x.is_dir()==y.is_dir(), str(k)
 if x.is_symlink(): assert x.readlink()==y.readlink(), str(k)
 elif x.is_file():
  assert x.stat().st_size==y.stat().st_size, str(k)
  assert hashlib.file_digest(x.open('rb'),'sha256').digest()==hashlib.file_digest(y.open('rb'),'sha256').digest(), str(k)
  files+=1
  if str(k).startswith('Contents/Resources/Music/'):music+=1
receipt={'version':'1.9.1','build':76,'deltaFrom':75,'delta':{'name':p.name,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'url':enc.get('url'),'edSignature':enc.get(n+'edSignature')},'signatureVerified':True,'patchedPayloadMatchesShippingApp':True,'payloadFilesChecked':files,'musicFilesChecked':music,'publishedItemsPreserved':8,'fullArchiveBytes':2043810178}
(r/'delta-verification.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(f'PASS delta signature, all {files} payload files including {music} music files, and published feed entries')
