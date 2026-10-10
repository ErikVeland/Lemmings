from pathlib import Path
from xml.etree import ElementTree as E
import copy
root = Path('.build/release-1.8.5')
feed = E.parse('appcast.xml')
previous = E.parse(root / 'previous-appcast.xml')
namespace = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
E.register_namespace('sparkle', namespace)
channel = feed.find('./channel')
versions = {item.findtext('{'+namespace+'}version') for item in channel.findall('item')}
for item in previous.findall('./channel/item'):
    if item.findtext('{'+namespace+'}version') not in versions:
        channel.append(copy.deepcopy(item))
items = channel.findall('item')
for item in items:
    channel.remove(item)
for item in sorted(items, key=lambda item: int(item.findtext('{'+namespace+'}version')), reverse=True):
    channel.append(item)
feed.write('appcast.xml', encoding='utf-8', xml_declaration=True)
