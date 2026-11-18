#!/usr/bin/env python3
"""Export genuine product captures and licensed artwork for the website."""
from pathlib import Path
import hashlib
import json
import shutil
from PIL import Image, ImageDraw, ImageFont
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent
ASSETS = ROOT / 'assets'
CAPTURES = Path('/Volumes/Games/CodexBuilds/UltimateLemmix-Store-20261118')
DJ = Path('/Users/veland/GenErik DJ/website/assets')
ASSETS.mkdir(parents=True, exist_ok=True)
records = []

def record(source, outputs, treatment):
    records.append({'source': str(source), 'sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                    'outputs': outputs, 'treatment': treatment})

def responsive(source, name, widths):
    original = Image.open(source).convert('RGB')
    outputs = []
    for width in widths:
        size = (width, round(original.height * width / original.width))
        im = original.resize(size, Image.Resampling.LANCZOS)
        for suffix in ('webp', 'jpg'):
            target = ASSETS / f'{name}-{width}.{suffix}'
            im.save(target, quality=90, **({'method': 6} if suffix == 'webp' else {'optimize': True}))
            outputs.append(target.name)
    record(source, outputs, 'Full actual capture; proportional resize and format conversion only.')

responsive(CAPTURES / 'presentation/submission/Starter.png', 'starter', [800, 1600, 2560])
responsive(CAPTURES / 'presentation/submission/Home.png', 'home', [800, 1600])
responsive(CAPTURES / 'simulator-captures/submission/iPhone-Home.png', 'phone', [402, 804])
responsive(CAPTURES / 'simulator-captures/submission/AppleTV-Home.png', 'tv', [960, 1920])
logo = REPO / 'Resources/UltimateLemmix/MenuArtwork/ultimate-lemmix.png'
shutil.copy2(logo, ASSETS / 'logo.png')
record(logo, ['logo.png'], 'Unmodified current product logo.')
icon = REPO / 'Apps/UltimateLemmixIOS/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png'
Image.open(icon).resize((96, 96), Image.Resampling.NEAREST).save(ASSETS / 'favicon.png')
record(icon, ['favicon.png'], 'Nearest-neighbour resize of clean Store icon.')
for name in ['archivo-latin.woff2', 'archivo-OFL.txt']:
    shutil.copy2(DJ / name, ASSETS / name)

lix = REPO / '.build/approved-alternative-resources/AlternativeAssets/Lix'
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

# The social preview combines the genuine logo and capture without altering either.
social = Image.new('RGB', (1200, 630), '#c6e9ed')
draw = ImageDraw.Draw(social)
font = TTFont(ASSETS / 'archivo-latin.woff2'); font.flavor = None
font_path = ROOT / '.social-font.ttf'; font.save(font_path)
large = ImageFont.truetype(str(font_path), 67)
small = ImageFont.truetype(str(font_path), 24)
brand = Image.open(logo).convert('RGBA'); brand.thumbnail((540, 170), Image.Resampling.LANCZOS)
social.paste(brand, (60, 48), brand)
draw.text((60, 245), 'Everybody counts.', font=large, fill='#143e35')
draw.text((65, 340), 'A little crowd. A route home. Your call.', font=small, fill='#143e35')
draw.text((65, 545), 'Ultimate Lemmix · Mac, iPhone, iPad & Apple TV', font=small, fill='#143e35')
capture = Image.open(CAPTURES / 'presentation/submission/Starter.png').convert('RGB')
capture.thumbnail((490, 307), Image.Resampling.LANCZOS)
social.paste(capture, (670, 165))
social.save(ASSETS / 'social.jpg', quality=93, optimize=True)
font_path.unlink()
(ROOT / 'image-provenance.json').write_text(json.dumps({'captures': records, 'social': 'Authored composition using the unchanged product logo and full Mac starter capture.', 'font': 'Archivo, SIL Open Font License; reused from the existing GenErik DJ website.'}, indent=2) + '\n')
print('Prepared genuine product imagery and local fonts.')
