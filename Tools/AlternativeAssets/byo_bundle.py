#!/usr/bin/env python3
"""
Prepare the asset-free player-owned import helper and its checksum record.
"""

import argparse
import hashlib
import json
from pathlib import Path
import stat
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / '.build/byo-integration'
ARCHIVE_NAME = 'Ultimate-Lemmix-BYO.zip'
SOURCE = ROOT / 'Resources/UltimateLemmix/byo-integration.json'
README = b"""Ultimate Lemmix: player-owned game import

This helper contains a JSON import contract and this guide.
It contains no game artwork, levels, music, original binaries or executable code.
It does not download game files or grant rights to original game content.

1. Open Ultimate Lemmix.
2. Choose Import Game Data.
3. Choose Classic, Lemmings 2 or Lemmings 3.
4. Select your local game folder.

The app checks file limits and rejects symbolic links.
It copies and validates the files before replacing an existing import.
The source folder stays in its original location.
Read byo-integration.json for the expected folder layouts and engine limits.

The independent Open Starter campaign needs no original game files.
This helper archive is not an application or a complete original game.
"""


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def payloads(source=SOURCE):
    """
    Accept only the asset-free contract and the authored guide.
    """
    data = source.read_bytes()
    contract = json.loads(data)
    if (contract.get('schemaVersion') != 1 or contract.get('requiresPlayerFiles') is not True
            or contract.get('containsCommercialAssets') is not False
            or contract.get('containsExecutableCode') is not False
            or contract.get('networkAccess') is not False or contract.get('downloads') != []):
        raise ValueError('The helper contract must remain asset-free and contain no downloads.')
    return {'byo-integration.json': data, 'README.txt': README}


def manifest_for(files):
    return {
        'schemaVersion': 1,
        'kind': 'asset-free-byo-integration',
        'containsCommercialAssets': False,
        'containsExecutableCode': False,
        'files': [{'path': name, 'bytes': len(data), 'sha256': sha256(data)}
                  for name, data in sorted(files.items())],
    }


def write_member(archive, name, data):
    info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
    info.create_system = 3
    info.external_attr = (stat.S_IFREG | 0o644) << 16
    archive.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=6)


def verify_archive(path, files, manifest):
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)) or set(names) != set(files) | {'manifest.json'}:
            raise ValueError('The helper archive contains unexpected or missing files.')
        for name in names:
            info = archive.getinfo(name)
            if stat.S_IFMT(info.external_attr >> 16) != stat.S_IFREG:
                raise ValueError('The helper archive must contain regular files only.')
        if json.loads(archive.read('manifest.json')) != manifest:
            raise ValueError('The helper archive manifest has changed.')
        for name, data in files.items():
            if archive.read(name) != data:
                raise ValueError(f'The helper archive content has changed: {name}.')


def verify(output=OUTPUT, source=SOURCE):
    """
    Check exact archive membership, current contract bytes and sibling checksums.
    """
    files = payloads(source)
    manifest = manifest_for(files)
    path = output / ARCHIVE_NAME
    verify_archive(path, files, manifest)
    expected = dict(manifest, archiveBytes=path.stat().st_size, archiveSHA256=sha256(path.read_bytes()))
    if json.loads((output / 'manifest.json').read_text()) != expected:
        raise ValueError('The helper checksum record has changed.')
    if (output / 'README.txt').read_bytes() != README:
        raise ValueError('The helper guide has changed.')
    actual = {item.name for item in output.iterdir()}
    if actual != {ARCHIVE_NAME, 'manifest.json', 'README.txt'}:
        raise ValueError('The helper folder contains unrecorded files.')
    return expected


def build(output=OUTPUT, source=SOURCE):
    """
    Write a deterministic helper archive without copying any game data.
    """
    files = payloads(source)
    manifest = manifest_for(files)
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=output, suffix='.zip', delete=False) as temporary:
        staging = Path(temporary.name)
    try:
        with zipfile.ZipFile(staging, 'w') as archive:
            for name, data in sorted(files.items()):
                write_member(archive, name, data)
            write_member(archive, 'manifest.json', (json.dumps(manifest, indent=2) + '\n').encode())
        verify_archive(staging, files, manifest)
        staging.replace(output / ARCHIVE_NAME)
    finally:
        staging.unlink(missing_ok=True)
    path = output / ARCHIVE_NAME
    record = dict(manifest, archiveBytes=path.stat().st_size, archiveSHA256=sha256(path.read_bytes()))
    (output / 'manifest.json').write_text(json.dumps(record, indent=2) + '\n')
    (output / 'README.txt').write_bytes(README)
    return verify(output, source)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify', action='store_true')
    args = parser.parse_args()
    record = verify() if args.verify else build()
    print(f'Asset-free import helper verified: {OUTPUT / ARCHIVE_NAME}, '
          f'{record["archiveBytes"]} bytes, SHA-256 {record["archiveSHA256"]}')


if __name__ == '__main__':
    main()
