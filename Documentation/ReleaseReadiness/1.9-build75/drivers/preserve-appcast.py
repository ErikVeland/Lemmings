from pathlib import Path
import re,xml.etree.ElementTree as E
r=Path('.build/release-1.9');namespace='{http://www.andymatuschak.org/xml-namespaces/sparkle}'
def key(item):
 enclosure=item.find('enclosure')
 return item.findtext(namespace+'version') or enclosure.get(namespace+'version')
oldtext=(r/'previous-appcast.xml').read_text();newtext=Path('appcast.xml').read_text()
olditems=re.findall(r'<item(?:\s[^>]*)?>.*?</item>',oldtext,re.S)
newkeys={key(item) for item in E.fromstring(newtext).findall('./channel/item')}
missing=[item for item in olditems if key(E.fromstring(item.replace('<item>', '<item xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">',1))) not in newkeys]
assert newtext.count('</channel>')==1
Path('appcast.xml').write_text(newtext.replace('</channel>', '\n'.join(missing)+'\n    </channel>'))
old=E.fromstring(oldtext);new=E.parse('appcast.xml').getroot()
oldbykey={key(i):i for i in old.findall('./channel/item')};newbykey={key(i):i for i in new.findall('./channel/item')}
assert set(oldbykey).issubset(newbykey)
for k,item in oldbykey.items():
 assert [e.attrib for e in item.iter('enclosure')]==[e.attrib for e in newbykey[k].iter('enclosure')]
assert key(new.findall('./channel/item')[0])=='75'
print('PASS all',len(oldbykey),'previous feed entries and enclosure attributes retained')
