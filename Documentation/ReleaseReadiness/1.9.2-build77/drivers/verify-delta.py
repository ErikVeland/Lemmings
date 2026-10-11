import hashlib, json, pathlib, plistlib, subprocess, xml.etree.ElementTree as E
r=pathlib.Path('.build/release-1.9.2'); n='{http://www.andymatuschak.org/xml-namespaces/sparkle}'
old=E.parse(r/'previous-appcast.xml').findall('./channel/item'); new=E.parse('appcast.xml').findall('./channel/item')
assert len(old)==8 and len(new)==9
new_by_build={item.findtext(n+'version'):item for item in new}
for a in old:
 b=new_by_build[a.findtext(n+'version')]
 assert [e.attrib for e in a.iter('enclosure')]==[e.attrib for e in b.iter('enclosure')]
 assert a.findtext('description')==b.findtext('description')
enc=new[0].find(n+'deltas/enclosure'); assert enc.get(n+'deltaFrom')=='76'
p=r/'updates/UltimateLemmings-build77-from76.delta'; assert str(p.stat().st_size)==enc.get('length')
info=plistlib.loads(pathlib.Path('.build/release-1.9.2/standard/Ultimate Lemmings.app/Contents/Info.plist').read_bytes())
subprocess.run(['.build/release-1.9.1/verify-signature',str(p),info['SUPublicEDKey'],enc.get(n+'edSignature')],check=True)
patched=r/'delta-patched/Ultimate Lemmings.app'; target=pathlib.Path('.build/release-1.9.2/standard/Ultimate Lemmings.app')
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
receipt={'version':'1.9.2','build':77,'deltaFrom':76,'delta':{'name':p.name,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'url':enc.get('url'),'edSignature':enc.get(n+'edSignature')},'signatureVerified':True,'patchedPayloadMatchesShippingApp':True,'payloadFilesChecked':files,'musicFilesChecked':music,'publishedItemsPreserved':8,'fullArchiveBytes':(r/'updates/UltimateLemmings-1.9.2-build77.zip').stat().st_size}
(r/'delta-verification.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(f'PASS delta signature, all {files} payload files including {music} music files, and published feed entries')
