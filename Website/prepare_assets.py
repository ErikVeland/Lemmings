#!/usr/bin/env python3
"""Export genuine product captures and licensed artwork for the website."""
from pathlib import Path
import hashlib
import json
import shutil
from PIL import Image, ImageDraw, ImageFont, ImageOps
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent
ASSETS = ROOT / 'assets'
SIMULATOR_CAPTURES = Path('/Volumes/Games/CodexBuilds/UltimateLemmix-Store-20261118')
MAC_CAPTURES = Path('/Volumes/Games/CodexBuilds/Release-Sync-20261120/UltimateLemmix/Website109')
DJ = Path('/Users/veland/GenErik DJ/website/assets')
ASSETS.mkdir(parents=True, exist_ok=True)
records = []

def record(source, outputs, treatment):
    records.append({'source': str(source), 'sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                    'outputs': outputs, 'treatment': treatment})

def responsive(source, name, widths, build):
    original = Image.open(source).convert('RGB')
    outputs = []
    for width in widths:
        size = (width, round(original.height * width / original.width))
        im = original.resize(size, Image.Resampling.LANCZOS)
        for suffix in ('webp', 'jpg'):
            target = ASSETS / f'{name}-{width}.{suffix}'
            im.save(target, quality=90, **({'method': 6} if suffix == 'webp' else {'optimize': True}))
            outputs.append(target.name)
    record(source, outputs, 'Full actual capture with proportional resizing and format conversion.')
    records[-1]['build'] = build

responsive(MAC_CAPTURES / 'Run/Starter.png', 'starter', [800, 1600, 2560], 'Mac 109')
responsive(MAC_CAPTURES / 'Raw/Home.png', 'home', [800, 1600], 'Mac 109')
responsive(MAC_CAPTURES / 'Community/Community.png', 'community', [800, 1600], 'Mac 109 with local packs')
responsive(SIMULATOR_CAPTURES / 'simulator-captures/submission/iPhone-Home.png', 'phone', [402, 804], 'Earlier iPhone Simulator')
responsive(SIMULATOR_CAPTURES / 'simulator-captures/submission/AppleTV-Home.png', 'tv', [960, 1920], 'Earlier Apple TV Simulator')
logo = REPO / 'Resources/UltimateLemmix/MenuArtwork/ultimate-lemmix.png'
shutil.copy2(logo, ASSETS / 'logo.png')
record(logo, ['logo.png'], 'Unmodified current product logo.')
logo_outputs = []
original_logo = Image.open(logo).convert('RGBA')
for width in (480, 960):
    target = ASSETS / f'logo-{width}.webp'
    original_logo.resize((width, round(original_logo.height * width / original_logo.width)),
                         Image.Resampling.LANCZOS).save(target, quality=90, method=6)
    logo_outputs.append(target.name)
record(logo, logo_outputs, 'Proportional responsive conversion of the current logo. No redrawing.')
icon = REPO / 'Resources/UltimateLemmix/AppIcon/UltimateLemmix.png'
app_icon = Image.open(icon).convert('RGB')
icon_sizes = {'favicon.png': 96, 'apple-touch-icon.png': 180, 'app-icon.png': 512}
for name, size in icon_sizes.items():
    app_icon.resize((size, size), Image.Resampling.LANCZOS).save(ASSETS / name, optimize=True)
record(icon, list(icon_sizes), 'Resized from the approved Ultimate Lemmix app icon.')
for name in ['archivo-latin.woff2', 'archivo-OFL.txt']:
    shutil.copy2(DJ / name, ASSETS / name)

lix = Path('/Users/veland/UltimateLemmix/.build/approved-alternative-resources/AlternativeAssets/Lix')
metadata = json.loads((lix / 'sprite-metadata.json').read_text())
sheet_path = lix / 'assets' / metadata['sourcePath']
sheet = Image.open(sheet_path).convert('RGBA')
frames = next(row for row in metadata['rows'] if row['activity'] == 'walker')['frames']
strip = Image.new('RGBA', (34 * len(frames), 34))
for index, frame in enumerate(frames):
    x, y = frame['x'], frame['y']
    sprite = sheet.crop((x, y, x + 34, y + 34))
    pixels = list(sprite.getdata())
    keys = {(0, 0, 0), tuple(metadata['gridRGBA'][:3])}
    sprite.putdata([(r, g, b, 0 if (r, g, b) in keys else a) for r, g, b, a in pixels])
    strip.paste(sprite, (34 * index, 0))
    if index == 0:
        sprite.save(ASSETS / 'walker.png')
strip.save(ASSETS / 'walk-strip.png')
record(sheet_path, ['walker.png', 'walk-strip.png'], 'Extracted published walker frames using pinned metadata and the existing black/grid transparency keys. No redrawing.')
shutil.copy2(lix / 'licences/copying.txt', ASSETS / 'Lix-copying.txt')
shutil.copy2(REPO / 'THIRD_PARTY_NOTICES.md', ASSETS / 'application-notices.txt')
notices = MAC_CAPTURES / 'Proof.app/Contents/Resources/Licences'
for notice in ('Lix-font-LICENSE.txt', 'Lix-music-credits.txt'):
    shutil.copy2(notices / notice, ASSETS / notice)

# Use the woodland illustration for link previews and keep the square app icon visible.
woodland = ASSETS / 'moss-bridge.webp'
social = ImageOps.fit(Image.open(woodland).convert('RGB'), (1200, 630), centering=(0.53, 0.5))
draw = ImageDraw.Draw(social)
brand = original_logo.copy()
brand.thumbnail((435, 160), Image.Resampling.LANCZOS)
social.paste(brand, (52, 162), brand)
social.paste(app_icon.resize((100, 100), Image.Resampling.LANCZOS), (57, 48))
font = TTFont(ASSETS / 'archivo-latin.woff2')
font.flavor = None
font_path = ROOT / '.social-font.ttf'
font.save(font_path)
title_font = ImageFont.truetype(str(font_path), 49)
draw.text((56, 324), 'Everybody counts.', font=title_font, fill='#fff5da', stroke_width=1, stroke_fill='#162b30')
font_path.unlink()
social.save(ASSETS / 'social.jpg', quality=91, optimize=True)
(ROOT / 'image-provenance.json').write_text(json.dumps({
    'captures': records,
    'illustration': 'Project artwork generated from the approved Ultimate Lemmix icon. The mobile image is a crop of the woodland scene.',
    'social': 'The woodland illustration with the approved app icon and wordmark.',
    'font': 'Archivo, SIL Open Font License; reused from the existing GenErik DJ website.'
}, indent=2) + '\n')
print('Prepared genuine product imagery and local fonts.')
