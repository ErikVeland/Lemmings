#!/usr/bin/env python3
"""Build the Lemmix product site as complete, independent HTML routes."""
from pathlib import Path
import hashlib
import html
import json
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent
CONFIG = json.loads((ROOT / 'site.json').read_text())
OUT = ROOT / 'dist'
ORIGIN = CONFIG['origin']


def build():
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir()
    asset_sources = sorted(path for path in (ROOT / 'assets').rglob('*') if path.is_file())
    asset_stamp = hashlib.sha256(b''.join(path.relative_to(ROOT).as_posix().encode() + path.read_bytes() for path in asset_sources)).hexdigest()[:12]
    asset_prefix = '/assets/' + asset_stamp + '/'
    asset_directory = OUT / 'assets' / asset_stamp
    shutil.copytree(ROOT / 'assets', asset_directory)
    assets = {}
    for name in ['site.css', 'site.js']:
        path = asset_directory / name
        path.write_text(path.read_text().replace('/assets/', asset_prefix))
        hashed = path.stem + '.' + hashlib.sha256(path.read_bytes()).hexdigest()[:12] + path.suffix
        path.rename(path.with_name(hashed))
        assets[name] = asset_prefix + hashed
    manifest = json.loads((ROOT / 'content/manifest.json').read_text())
    if isinstance(manifest, dict):
        manifest = manifest['pages']
    pages = [{'route':'/', 'file':'home.html', 'title':'Everybody counts.', 'description':'Meet Ultimate Lemmix: a little crowd, a route home, and your plan. Three original puzzles, local Hot Seat and ways to try again. Preparing for the App Store.'}] + manifest
    pages += [{'route':'/404', 'file':'404.html', 'title':'This way is blocked.', 'description':'That page is not here. Return to Ultimate Lemmix.'}, {'route':'/503', 'file':'503.html', 'title':'A short pause.', 'description':'The site is temporarily unavailable. Try again shortly.'}]
    nav = [('/', 'The game'), ('/manual', 'Field guide'), ('/support', 'Get help')]
    footer = nav + [('/privacy','Privacy'),('/privacy/choices','Privacy choices'),('/accessibility','Accessibility'),('/terms','Terms'),('/release-notes','Release notes'),('/legal','Legal'),('/credits','Credits')]
    def links(items, route):
        return ''.join(f'<a href="{url}"' + (' aria-current="page"' if url == route else '') + f'>{label}</a>' for url, label in items)
    for page in pages:
        route = page['route']; home = route == '/'; error = route in ('/404','/503')
        canonical = ORIGIN + route
        title = page['title'] + ' · Ultimate Lemmix'
        body = (ROOT / 'content' / page['file']).read_text()
        body = body.replace('{{contact}}', html.escape(CONFIG['contact'])).replace('{{policy_date}}', CONFIG['policy_date'])
        toc = ''
        if not home:
            headings = re.findall(r'<h2\s+id="([^"]+)"[^>]*>(.*?)</h2>', body)
            if headings:
                toc = '<nav class="contents" aria-label="On this page"><p>On this page</p>' + ''.join(f'<a href="#{identifier}">{re.sub("<[^>]+>", "", label)}</a>' for identifier,label in headings) + '</nav>'
            body = f'<header class="document-title"><p class="trail"><a href="/">Ultimate Lemmix</a> / {html.escape(page["title"])}</p><h1>{html.escape(page["title"])}</h1></header><div class="document-layout">{toc}<article class="prose">{body}</article></div>'
        schema = [{'@context':'https://schema.org','@type':'WebSite','name':CONFIG['name'],'url':ORIGIN+'/', 'inLanguage':'en-AU', 'creator':{'@type':'Person','name':CONFIG['developer']}}]
        if home:
            schema.append({'@context':'https://schema.org','@type':'SoftwareApplication','name':CONFIG['name'],'url':canonical,'applicationCategory':'GameApplication','operatingSystem':['macOS','iOS','iPadOS','tvOS'],'creativeWorkStatus':'Pre-release','softwareVersion':'2.4.2','description':page['description'],'image':ORIGIN+'/assets/social.jpg','author':{'@type':'Person','name':CONFIG['developer']}})
        elif not error:
            schema.append({'@context':'https://schema.org','@type':'BreadcrumbList','itemListElement':[{'@type':'ListItem','position':1,'name':'Ultimate Lemmix','item':ORIGIN+'/'},{'@type':'ListItem','position':2,'name':page['title'],'item':canonical}]})
        document = f'''<!doctype html>
<html lang="en-AU"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(title)}</title><meta name="description" content="{html.escape(page['description'],quote=True)}">
<link rel="canonical" href="{canonical}">{'<meta name="robots" content="noindex,follow">' if error else ''}
<meta property="og:type" content="website"><meta property="og:site_name" content="Ultimate Lemmix"><meta property="og:locale" content="en_AU"><meta property="og:title" content="{html.escape(title,quote=True)}"><meta property="og:description" content="{html.escape(page['description'],quote=True)}"><meta property="og:url" content="{canonical}"><meta property="og:image" content="{ORIGIN}/assets/social.jpg"><meta property="og:image:width" content="1200"><meta property="og:image:height" content="630"><meta property="og:image:alt" content="Ultimate Lemmix logo and a genuine Mac starter-level capture. Everybody counts."><meta name="twitter:card" content="summary_large_image"><meta name="theme-color" content="#c6e9ed">
<link rel="icon" href="/assets/favicon.png" type="image/png"><link rel="preload" href="/assets/archivo-latin.woff2" as="font" type="font/woff2" crossorigin><link rel="stylesheet" href="{assets['site.css']}">
<script type="application/ld+json">{json.dumps(schema,ensure_ascii=False).replace('<', chr(92)+'u003c')}</script><script src="{assets['site.js']}" defer></script>
</head><body><a class="skip" href="#main">Skip to content</a>
<header class="site-header"><a class="brand" href="/" aria-label="Ultimate Lemmix home"><img src="/assets/walker.png" alt="" width="34" height="34"><span>Ultimate Lemmix</span></a><nav aria-label="Primary">{links(nav,route)}</nav><a class="release-link" href="/release-notes">App Store preparations <span aria-hidden="true">↗</span></a></header>
<main id="main" tabindex="-1" class="{'home' if home else 'document'}">{body}</main>
<footer class="site-footer"><div class="footer-scene" aria-hidden="true"><img src="/assets/walker.png" alt="" width="68" height="68"><span>Home, eventually.</span></div><div class="footer-body"><a href="/" class="footer-brand"><img src="/assets/logo.png" alt="Ultimate Lemmix" width="2172" height="724" loading="lazy"></a><nav aria-label="Footer">{links(footer,route)}</nav><div class="footer-note"><p>Made by Erik Veland.<br>A little care goes a long way.</p><p><a href="mailto:{CONFIG['contact']}">{CONFIG['contact']}</a><br>© 2026 Erik Veland</p><p>Preparing for the App Store.<br>No public release yet.</p></div></div></footer></body></html>'''
        target = OUT / ('index.html' if home else route.lstrip('/') + '/index.html')
        document = re.sub(r'/assets/(?!' + asset_stamp + '/)', asset_prefix, document)
        target.parent.mkdir(parents=True, exist_ok=True); target.write_text(document)
    public = [p['route'] for p in pages if p['route'] not in ('/404','/503')]
    (OUT/'sitemap.xml').write_text('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'+''.join(f'<url><loc>{ORIGIN}{route}</loc></url>' for route in public)+'</urlset>\n')
    (OUT/'robots.txt').write_text(f'User-agent: *\nAllow: /\nSitemap: {ORIGIN}/sitemap.xml\n')
    revision = subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    (OUT/'build.json').write_text(json.dumps({'source_revision':revision,'canonical_origin':ORIGIN,'routes':public},indent=2)+'\n')
    print(f'Built {len(pages)} routes in {OUT}')

if __name__ == '__main__':
    build()
