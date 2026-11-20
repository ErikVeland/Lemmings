#!/usr/bin/env python3
"""Check generated routes, references, metadata and image dimensions."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit, unquote
import json
import re

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'dist'
ORIGIN = json.loads((ROOT / 'site.json').read_text())['origin']

class Page(HTMLParser):
    def __init__(self, path):
        super().__init__(convert_charrefs=True)
        self.path = path
        self.ids = set()
        self.links = []
        self.title = 0
        self.h1 = 0
        self.canonical = []
        self.errors = []
        self.feed(path.read_text())

    def handle_starttag(self, tag, attributes):
        a = dict(attributes)
        if a.get('id'):
            if a['id'] in self.ids:
                self.errors.append('Duplicate ID: ' + a['id'])
            self.ids.add(a['id'])
        if tag == 'h1': self.h1 += 1
        if tag == 'title': self.title += 1
        if tag == 'html' and a.get('lang') != 'en-AU': self.errors.append('Incorrect language')
        if tag == 'img' and not all(key in a for key in ('alt','width','height')):
            self.errors.append('Image needs alt and intrinsic dimensions')
        if tag == 'link' and a.get('rel') == 'canonical': self.canonical.append(a.get('href'))
        for key in ('href','src','poster'):
            if key in a:
                if not a[key] or a[key] == '#': self.errors.append('Empty link')
                self.links.append(a[key])
        if 'srcset' in a:
            self.links += [item.strip().split()[0] for item in a['srcset'].split(',')]

pages = {path: Page(path) for path in OUT.rglob('*.html')}
errors = []
titles = set()
for path, page in pages.items():
    route = '/' + path.parent.relative_to(OUT).as_posix()
    if route == '/.': route = '/'
    if page.canonical != [ORIGIN + route]: page.errors.append('Incorrect canonical URL')
    if page.h1 != 1 or page.title != 1: page.errors.append('Requires exactly one title and h1')
    text = path.read_text()
    title = re.search(r'<title>(.*?)</title>', text).group(1)
    if title in titles: page.errors.append('Duplicate title')
    titles.add(title)
    if re.search(r'\b(?:TODO|lorem ipsum|placeholder)\b|\{\{', text, re.I): page.errors.append('Unfinished content')
    for link in page.links:
        url = urlsplit(link)
        if url.scheme or url.netloc: continue
        if not url.path:
            target = path
        else:
            target = (OUT / unquote(url.path).lstrip('/')) if url.path.startswith('/') else path.parent / unquote(url.path)
            if target.is_dir(): target /= 'index.html'
        if not target.is_file(): page.errors.append('Missing internal target: ' + link)
        elif url.fragment and target in pages and unquote(url.fragment) not in pages[target].ids:
            page.errors.append('Missing anchor: ' + link)
    for issue in page.errors: errors.append(f'{route}: {issue}')
for css in (OUT / 'assets').rglob('*.css'):
    for url in re.findall(r'url\([\'"]?([^\)\'\"]+)', css.read_text()):
        if url.startswith('/') and not (OUT/url.lstrip('/')).is_file(): errors.append('Missing CSS asset: '+url)
assert len(pages) == 13, 'Expected all thirteen routes, including error pages'
assert not errors, '\n'.join(errors)
print(f'PASS {len(pages)} complete routes, internal links and anchors, metadata, images and CSS references')
