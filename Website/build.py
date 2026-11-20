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


def screenshot(capture, figure_class, sizes, platform=None):
    name = capture['key']
    label = html.escape(capture['name'], quote=True)
    alt = html.escape(capture['alt'], quote=True)
    caption = html.escape(capture['caption'])
    widths = capture['widths']
    sources = ', '.join(f'/assets/{name}-{width}.webp {width}w' for width in widths)
    jpeg_sources = ', '.join(f'/assets/{name}-{width}.jpg {width}w' for width in widths)
    full = f'/assets/{name}-full.webp'
    hdr = ''
    hdr_link = ''
    if 'hdr' in capture:
        hdr_path = '/assets/' + html.escape(capture['hdr']['output'], quote=True)
        mime = html.escape(capture['hdr']['type'], quote=True)
        hdr = f'<source type="{mime}" media="(dynamic-range: high)" srcset="{hdr_path}">'
        hdr_link = f' <a href="{hdr_path}" aria-label="Full-size HDR for {label}">Full-size HDR</a>'
    platform_attr = f' id="screen-{platform}" data-platform="{platform}"' if platform else ''
    if platform and capture['height'] > capture['width']:
        figure_class += ' portrait'
    return f'''<figure class="{figure_class}"{platform_attr}>
      <picture>{hdr}<source type="image/webp" srcset="{sources}" sizes="{sizes}">
        <img src="/assets/{name}-{widths[-1]}.jpg" srcset="{jpeg_sources}" sizes="{sizes}" alt="{alt}" width="{capture['width']}" height="{capture['height']}" loading="lazy">
      </picture>
      <figcaption>{caption} <a href="{full}" aria-label="Full size for {label}">Full size</a>{hdr_link}</figcaption>
    </figure>'''


def screenshot_gallery(captures):
    platforms = [c for c in captures if 'platformLabel' in c]
    buttons = []
    figures = []
    for index, capture in enumerate(platforms):
        key = capture['platform']
        pressed = 'true' if index == 0 else 'false'
        label = html.escape(capture['platformLabel'])
        buttons.append(f'<button class="moss-button moss-button--compact" type="button" data-capture="{key}" aria-controls="screen-{key}" aria-pressed="{pressed}">{label}</button>')
        figures.append(screenshot(capture, 'platform-capture', '(max-width: 800px) 92vw, 960px', key))
    return ('<div class="capture-picker" data-gallery><div class="capture-tabs" hidden '
            'role="group" aria-label="Choose a platform screenshot">' + ''.join(buttons) +
            '</div>' + ''.join(figures) + '</div>')


def build():
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir()
    asset_sources = sorted(path for path in (ROOT / 'assets').rglob('*') if path.is_file())
    asset_stamp = hashlib.sha256(b''.join(path.relative_to(ROOT).as_posix().encode() + path.read_bytes() for path in asset_sources)).hexdigest()[:12]
    asset_prefix = '/assets/' + asset_stamp + '/'
    asset_directory = OUT / 'assets' / asset_stamp
    shutil.copytree(ROOT / 'assets', asset_directory)
    # Serve the shared and page-specific styles in one cacheable stylesheet.
    stylesheets = ('site.css', 'forest-home.css', 'forest-guide.css', 'forest-shell.css', 'moss-buttons.css')
    style_parts = [(asset_directory / name).read_text() for name in stylesheets]
    (asset_directory / 'site.css').write_text('\n'.join(style_parts))
    for name in stylesheets[1:]:
        (asset_directory / name).unlink()
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
    pages = [{'route':'/', 'file':'home.html', 'title':'296 Journey lessons and thousands of fan puzzles', 'description':'Discover 5,051 Classic fan puzzles in 487 packs, import NeoLemmix adventures, follow the 296-lesson Journey or watch the Duo Desk Clock at work.'}] + manifest
    pages += [{'route':'/404', 'file':'404.html', 'title':'This way is blocked.', 'description':'That page is not here. Return to Ultimate Lemmix.'}, {'route':'/503', 'file':'503.html', 'title':'A short pause.', 'description':'The site is temporarily unavailable. Try again shortly.'}]
    nav = [('/', 'The game'), ('/upgrade', 'Upgrade'), ('/manual', 'Field guide'), ('/support', 'Get help')]
    footer = nav + [('/privacy','Privacy'),('/privacy/choices','Privacy choices'),('/accessibility','Accessibility'),('/terms','Terms'),('/release-notes','Release notes'),('/legal','Legal'),('/credits','Credits')]
    def links(items, route, classes=''):
        style = f' class="{classes}"' if classes else ''
        return ''.join(f'<a{style} href="{url}"' + (' aria-current="page"' if url == route else '') + f'>{label}</a>' for url, label in items)
    for page in pages:
        route = page['route']; home = route == '/'; error = route in ('/404','/503')
        canonical = ORIGIN + route
        title = page['title'] + ' · Ultimate Lemmix'
        body = (ROOT / 'content' / page['file']).read_text()
        body = body.replace('{{contact}}', html.escape(CONFIG['contact'])).replace('{{policy_date}}', CONFIG['policy_date'])
        if home:
            captures = json.loads((ROOT / 'content/screenshots.json').read_text())['captures']
            feature_classes = {'journey': 'puzzle-capture', 'community': 'community-capture',
                               'nuke': 'blast-frame', 'tabletop': 'pose-frame', 'book': 'pose-frame'}
            for capture in captures:
                key = capture['key']
                if key in feature_classes:
                    body = body.replace('{{' + key + '}}', screenshot(capture, feature_classes[key], '(max-width: 800px) 90vw, 560px'))
            body = body.replace('{{platform-gallery}}', screenshot_gallery(captures))
        toc = ''
        if not home:
            headings = re.findall(r'<h2\s+id="([^"]+)"[^>]*>(.*?)</h2>', body)
            if headings:
                toc = '<nav class="contents" aria-label="On this page"><p>On this page</p>' + ''.join(f'<a href="#{identifier}">{re.sub("<[^>]+>", "", label)}</a>' for identifier,label in headings) + '</nav>'
            body = f'<header class="document-title"><p class="trail"><a href="/">Ultimate Lemmix</a> / {html.escape(page["title"])}</p><h1>{html.escape(page["title"])}</h1></header><div class="document-layout">{toc}<article class="prose">{body}</article></div>'
        schema = [{'@context':'https://schema.org','@type':'WebSite','name':CONFIG['name'],'url':ORIGIN+'/', 'inLanguage':'en-AU', 'creator':{'@type':'Person','name':CONFIG['developer']}}]
        if home:
            schema.append({'@context':'https://schema.org','@type':'SoftwareApplication','name':CONFIG['name'],'url':canonical,'applicationCategory':'GameApplication','operatingSystem':['macOS','iOS','iPadOS','tvOS'],'creativeWorkStatus':'Pre-release','softwareVersion':'2.4.2','description':page['description'],'image':ORIGIN+'/assets/app-icon.png','author':{'@type':'Person','name':CONFIG['developer']}})
        elif not error:
            schema.append({'@context':'https://schema.org','@type':'BreadcrumbList','itemListElement':[{'@type':'ListItem','position':1,'name':'Ultimate Lemmix','item':ORIGIN+'/'},{'@type':'ListItem','position':2,'name':page['title'],'item':canonical}]})
        document = f'''<!doctype html>
<html lang="en-AU"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(title)}</title><meta name="description" content="{html.escape(page['description'],quote=True)}">
<link rel="canonical" href="{canonical}">{'<meta name="robots" content="noindex,follow">' if error else ''}
<meta property="og:type" content="website"><meta property="og:site_name" content="Ultimate Lemmix"><meta property="og:locale" content="en_AU"><meta property="og:title" content="{html.escape(title,quote=True)}"><meta property="og:description" content="{html.escape(page['description'],quote=True)}"><meta property="og:url" content="{canonical}"><meta property="og:image" content="{ORIGIN}/assets/social.jpg"><meta property="og:image:width" content="1200"><meta property="og:image:height" content="630"><meta property="og:image:alt" content="The Ultimate Lemmix icon and wordmark beside a Lix watching a firefly above a mossy bridge."><meta name="twitter:card" content="summary_large_image"><meta name="theme-color" content="#10282c">
<link rel="icon" href="/assets/favicon.png" type="image/png" sizes="96x96"><link rel="apple-touch-icon" href="/assets/apple-touch-icon.png" sizes="180x180"><link rel="preload" href="/assets/archivo-latin.woff2" as="font" type="font/woff2" crossorigin><link rel="stylesheet" href="{assets['site.css']}">
<script type="application/ld+json">{json.dumps(schema,ensure_ascii=False).replace('<', chr(92)+'u003c')}</script><script src="{assets['site.js']}" defer></script>
</head><body><a class="skip" href="#main">Skip to content</a>
<header class="forest-trailhead">
  <div class="trailhead-inner">
    <a class="trailhead-brand" href="/" aria-label="Ultimate Lemmix home"><img src="/assets/apple-touch-icon.png" alt="" width="48" height="48"><span>Ultimate Lemmix</span></a>
    <nav class="trail-signs" aria-label="Primary">{links(nav,route,'moss-button moss-button--compact')}</nav>
    <a class="trailhead-release moss-button" href="/release-notes"{' aria-current="page"' if route == '/release-notes' else ''}>App Store preparations <span aria-hidden="true">↗</span></a>
  </div>
</header>
<main id="main" tabindex="-1" class="{'home' if home else 'document'}">{body}</main>
<footer class="site-footer forest-trail-end">
  <div class="trail-end-inner">
    <div class="trail-end-sign">
      <a class="trail-end-brand" href="/" aria-label="Ultimate Lemmix home"><picture><source type="image/webp" srcset="/assets/logo-480.webp 480w, /assets/logo-960.webp 960w" sizes="(max-width: 600px) 200px, 270px"><img src="/assets/logo.png" alt="Ultimate Lemmix" width="2172" height="724" loading="lazy"></picture></a>
      <p class="trail-end-caption">Home, eventually.</p>
    </div>
    <nav class="trail-end-links" aria-label="Footer">
      <div>{links(footer[:4],route)}</div>
      <div>{links(footer[4:8],route)}</div>
      <div>{links(footer[8:],route)}</div>
    </nav>
    <div class="trail-end-colophon"><p>© 2026 Erik Veland</p><a href="mailto:{CONFIG['contact']}">{CONFIG['contact']}</a><p>Preparing for the App Store.</p></div>
  </div>
</footer></body></html>'''
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
