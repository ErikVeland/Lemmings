#!/usr/bin/env python3
"""Prepare the unchanged Lix interface font with its separate font licence."""
import argparse
import hashlib
import json
from pathlib import Path
import tempfile

import prepare_lix

ROOT = Path(__file__).resolve().parents[2]
PIN = ROOT / 'Resources/AlternativeAssets/lix-font-source.json'
OUTPUT = ROOT / '.build/alternative-assets/lix-font'
FONT_SHA256 = '5cde0409cd6f6dff89fefb5349c90b92b62fd27de0fe3a577fb4036d5eeb4f71'
NOTICE_SHA256 = '6b07a2a6b192d39baeca18f3491d7c25a1999ba11384588e0ed0f063a856bfb8'
LICENCE = 'Bitstream-Vera AND LicenseRef-Arev-Fonts'


def sha(data):
    """Identify exact font and notice bytes."""
    return hashlib.sha256(data).hexdigest()


def encoded(value):
    """Write a stable provenance record without machine paths or dates."""
    return (json.dumps(value, indent=2, ensure_ascii=False) + '\n').encode()


def regular(path):
    """Reject source links and paths outside the checkout."""
    path = Path(path)
    try:
        relative = path.relative_to(ROOT)
    except ValueError as error:
        raise ValueError('The Lix font input is outside the checkout.') from error
    if '..' in relative.parts:
        raise ValueError('The Lix font input escapes its checkout path.')
    for item in (path, *path.parents):
        if item == ROOT:
            break
        if item.is_symlink():
            raise ValueError('The Lix font input must not contain links.')
    if not path.is_file():
        raise ValueError('A pinned Lix font input is missing: ' + str(path))
    return path.read_bytes()


def expected_files():
    """Reconstruct the exact font, complete notice and source record from pinned inputs."""
    lock = json.loads(regular(PIN))
    graphics_data = regular(prepare_lix.PIN)
    graphics = json.loads(graphics_data)
    if (lock['graphicsPinSHA256'] != sha(graphics_data)
            or lock['source']['revision'] != graphics['revision']
            or lock['source']['archive'] != graphics['archive']
            or lock['source']['path'] != 'data/fonts/djvusans.ttf'
            or lock['source']['sha256'] != FONT_SHA256
            or lock['licence']['id'] != LICENCE or lock['licence']['cc0'] is not False
            or lock['modified'] is not False or lock['bundlePath'] != 'Fonts/Lix/djvusans.ttf'
            or lock['noticeBundlePath'] != 'Licences/Lix-font-LICENSE.txt'
            or lock['licence']['noticeFile'] != 'Resources/AlternativeAssets/lix-font-LICENSE.txt'
            or lock['licence']['noticeSHA256'] != NOTICE_SHA256):
        raise ValueError('The pinned Lix font scope or licence changed.')
    archive = ROOT / '.build/dependencies' / graphics['archive']['filename']
    regular(archive)
    sources = prepare_lix.read_archive(archive, graphics)
    font = sources['data/fonts/djvusans.ttf']
    notice = regular(ROOT / lock['licence']['noticeFile'])
    if (sha(font) != FONT_SHA256 or len(font) != lock['source']['bytes']
            or sha(notice) != NOTICE_SHA256 or len(notice) != lock['licence']['noticeBytes']):
        raise ValueError('The pinned Lix font or full notice bytes changed.')
    return {'Fonts/Lix/djvusans.ttf': font, 'Licences/Lix-font-LICENSE.txt': notice,
            'Provenance/lix-font-source.json': encoded(lock)}


def manifest(files):
    """Keep the font licence separate from the CC0 artwork manifest."""
    return {'schemaVersion': 1, 'kind': 'lix-interface-font', 'licence': LICENCE,
            'cc0': False, 'modified': False,
            'files': [{'path': name, 'bytes': len(data), 'sha256': sha(data)}
                      for name, data in sorted(files.items())]}


def verify(output=OUTPUT, files=None):
    """Reject extra files, changed font bytes and forged prepared inventories."""
    files = expected_files() if files is None else files
    if output.is_symlink():
        raise ValueError('The prepared Lix font folder must not be a link.')
    names = set()
    for path in output.rglob('*'):
        if path.is_symlink() or not (path.is_file() or path.is_dir()):
            raise ValueError('The prepared Lix font contains a link or unsupported entry.')
        if path.is_file():
            names.add(path.relative_to(output).as_posix())
    if names != set(files) | {'manifest.json'}:
        raise ValueError('The prepared Lix font contains extra or missing files.')
    if json.loads(regular(output / 'manifest.json')) != manifest(files):
        raise ValueError('The prepared Lix font inventory changed.')
    for name, data in files.items():
        if regular(output / name) != data:
            raise ValueError('A prepared Lix font file differs from its pinned source: ' + name)
    return manifest(files)


def prepare():
    """Create only the dedicated font pack and preserve unrelated existing files."""
    files = expected_files()
    for path in (OUTPUT, *OUTPUT.parents):
        if path == ROOT:
            break
        if path.is_symlink():
            raise ValueError('The Lix font output must not contain linked ancestors.')
    if OUTPUT.exists():
        return verify(OUTPUT, files)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.lix-font-', dir=OUTPUT.parent) as temporary:
        staged = Path(temporary) / 'font'
        staged.mkdir()
        for name, data in files.items():
            target = staged / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        (staged / 'manifest.json').write_bytes(encoded(manifest(files)))
        verify(staged, files)
        staged.rename(OUTPUT)
    return verify(OUTPUT, files)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify', action='store_true')
    args = parser.parse_args()
    result = verify() if args.verify else prepare()
    print(f"PASS unchanged Lix font and full notice: {len(result['files'])} files; {LICENCE}; not CC0.")


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError) as error:
        raise SystemExit('FAILED: ' + str(error)) from error
