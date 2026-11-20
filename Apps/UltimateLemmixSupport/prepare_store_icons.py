#!/usr/bin/env python3
"""Prepare Store catalogues from the approved Lemmix icon and menu logo."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'Tools/AlternativeAssets'))
from mobile_resources import ICON_SOURCE, TV_CHARACTER_MASK, icons
from store_resources import convert


def main():
    icons(write=True)
    logo = ROOT / 'Resources/UltimateLemmix/MenuArtwork/ultimate-lemmix.png'
    for platform in ('IOS', 'TVOS'):
        catalogue = ROOT / f'Apps/UltimateLemmix{platform}/Assets.xcassets'
        path = catalogue / 'StartupLogo.imageset/startup-logo.png'
        dimensions = subprocess.check_output(['magick', 'identify', '-format', '%wx%h', str(path)], text=True)
        path.write_bytes(convert([logo, '-filter', 'point', '-resize', dimensions, '-background', 'black',
                                  '-gravity', 'center', '-extent', dimensions, '-strip', '-define',
                                  'png:exclude-chunks=date,time', 'png:-']))
    files = []
    for platform in ('IOS', 'TVOS'):
        for path in sorted((ROOT / f'Apps/UltimateLemmix{platform}/Assets.xcassets').rglob('*')):
            if path.is_file():
                data = path.read_bytes()
                files.append({'path': path.relative_to(ROOT).as_posix(), 'bytes': len(data),
                              'sha256': hashlib.sha256(data).hexdigest()})
    record = {'schemaVersion': 1, 'kind': 'ultimate-lemmix-store-catalogues',
              'iconSource': ICON_SOURCE.relative_to(ROOT).as_posix(),
              'iconSHA256': hashlib.sha256(ICON_SOURCE.read_bytes()).hexdigest(),
              'tvCharacterMask': TV_CHARACTER_MASK.relative_to(ROOT).as_posix(),
              'tvCharacterMaskSHA256': hashlib.sha256(TV_CHARACTER_MASK.read_bytes()).hexdigest(),
              'startupLogoSource': logo.relative_to(ROOT).as_posix(),
              'startupLogoSHA256': hashlib.sha256(logo.read_bytes()).hexdigest(),
              'method': 'Lanczos resizing for app icons, a character mask for TV depth, and point sampling for the menu logo.',
              'files': files}
    (ROOT / 'Apps/UltimateLemmixSupport/icon-source.json').write_text(json.dumps(record, indent=2) + '\n')
    print(f'Prepared and recorded {len(files)} Store catalogue files.')


if __name__ == '__main__':
    main()
