#!/usr/bin/env python3
"""Prepare Store catalogues from the pinned Lix sprite and project menu logo."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'Tools/AlternativeAssets'))
from store_resources import clean_icon, convert


def main():
    art = ROOT / '.build/approved-alternative-resources/AlternativeAssets/Lix'
    metadata = json.loads((art / 'sprite-metadata.json').read_bytes())
    icons = clean_icon((art / 'assets' / metadata['sourcePath']).read_bytes(), metadata)
    logo = ROOT / 'Resources/UltimateLemmix/MenuArtwork/ultimate-lemmix.png'
    with tempfile.TemporaryDirectory(prefix='lemmix-store-icons-') as temporary:
        icon = Path(temporary) / 'icon.png'
        icon.write_bytes(icons['AppIcon.png'])
        for platform in ('IOS', 'TVOS'):
            catalogue = ROOT / f'Apps/UltimateLemmix{platform}/Assets.xcassets'
            for path in sorted(catalogue.rglob('*.png')):
                dimensions = subprocess.check_output(['magick', 'identify', '-format', '%wx%h', str(path)], text=True)
                if path.name == 'startup-logo.png':
                    arguments = [logo, '-filter', 'point', '-resize', dimensions, '-background', 'black',
                                 '-gravity', 'center', '-extent', dimensions]
                elif '/Middle.imagestacklayer/' in path.as_posix():
                    arguments = ['-size', dimensions, 'xc:none']
                elif '/Back.imagestacklayer/' in path.as_posix():
                    arguments = ['-size', dimensions, 'xc:#152333']
                else:
                    arguments = [icon, '-filter', 'point', '-resize', dimensions, '-background', '#152333',
                                 '-gravity', 'center', '-extent', dimensions, '-alpha', 'off']
                path.write_bytes(convert([*arguments, '-strip', '-define', 'png:exclude-chunks=date,time', 'png:-']))
    files = []
    for platform in ('IOS', 'TVOS'):
        for path in sorted((ROOT / f'Apps/UltimateLemmix{platform}/Assets.xcassets').rglob('*')):
            if path.is_file():
                data = path.read_bytes()
                files.append({'path': path.relative_to(ROOT).as_posix(), 'bytes': len(data),
                              'sha256': hashlib.sha256(data).hexdigest()})
    record = {'schemaVersion': 1, 'kind': 'ultimate-lemmix-store-catalogues',
              'iconSource': 'Resources/AlternativeAssets/lix-source.json', 'iconLicence': 'CC0-1.0',
              'startupLogoSource': logo.relative_to(ROOT).as_posix(),
              'startupLogoSHA256': hashlib.sha256(logo.read_bytes()).hexdigest(),
              'method': 'Integer-pixel scaling of the approved Lix icon and the project Lemmix menu logo.',
              'files': files}
    (ROOT / 'Apps/UltimateLemmixSupport/icon-source.json').write_text(json.dumps(record, indent=2) + '\n')
    print(f'Prepared and recorded {len(files)} Store catalogue files.')


if __name__ == '__main__':
    main()
