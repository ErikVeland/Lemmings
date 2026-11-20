#!/usr/bin/env python3
"""Package verified alternative resources without changing the shipped app."""

import argparse
import hashlib
import json
from pathlib import Path
import stat
import subprocess
import tempfile
import zipfile
from prepare_music import OUTPUT as MUSIC_OUTPUT


ROOT = Path(__file__).resolve().parents[2]
README = b"""Alternative resource preparation

This archive contains prepared Lix graphics and the licensed Lix soundtrack.
Read the included source records, licence texts and remix audit.
It is not an application, installed skin or App Store release approval.
Classic, Lemmings 2 and Lemmings 3 renderer integration remains unverified.
Original Lemmings graphics, levels and existing fan-remix audio are not included.
"""


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            value.update(chunk)
    return value.hexdigest()


def collect(root):
    """Accept only the prepared resource trees and their provenance records."""
    files = {}
    for name, directory, suffixes in (
        ('graphics', root / '.build/alternative-assets/lix', {'.png', '.json', '.txt', '.md'}),
        ('music', root / MUSIC_OUTPUT.relative_to(ROOT), {'.ogg', '.wav', '.m4a', '.mp3', '.json', '.txt', '.md'}),
    ):
        if directory.is_symlink() or not (directory / 'manifest.json').is_file():
            raise ValueError(f'Missing prepared {name}. Run its preparation script.')
        for path in sorted(directory.rglob('*')):
            if path.is_symlink():
                raise ValueError(f'Resource links are not permitted: {path}')
            if path.is_file():
                if path.suffix.lower() not in suffixes:
                    raise ValueError(f'Unexpected resource type: {path}')
                files[f'{name}/{path.relative_to(directory).as_posix()}'] = path
    for name in ('lix-source.json', 'music-sources.json', 'fan-remix-rights.json'):
        path = root / 'Resources/AlternativeAssets' / name
        if path.is_symlink() or not path.is_file():
            raise ValueError(f'Missing source record: {path}')
        json.loads(path.read_text())
        files[f'provenance/{name}'] = path
    return files


def manifest_for(files):
    rows = [dict(path=name, bytes=path.stat().st_size, sha256=digest(path))
            for name, path in sorted(files.items())]
    rows.append(dict(path='README.txt', bytes=len(README),
                     sha256=hashlib.sha256(README).hexdigest()))
    return dict(schemaVersion=1, kind='alternative-resource-preparation',
                runtimeIntegration='not-integrated', fanRemixAudioIncluded=False,
                files=sorted(rows, key=lambda row: row['path']))


def verify_inputs(root):
    for script in ('prepare-lix-alternative.sh', 'prepare-alternative-music.sh'):
        subprocess.run(['zsh', str(root / 'Scripts' / script), '--verify'], check=True)


def validate_output(root, output, files):
    """Keep generated archives outside the prepared inputs and source records."""
    output = output.resolve()
    for source in (root / '.build/alternative-assets/lix', root / MUSIC_OUTPUT.relative_to(ROOT)):
        directory = source.resolve()
        if output == directory or directory in output.parents:
            raise ValueError('The archive output must be outside prepared resource folders.')
    if output in {path.resolve() for path in files.values()}:
        raise ValueError('The archive output must not replace a source record.')
    if output.suffix.lower() != '.zip':
        raise ValueError('The archive output must use the .zip extension.')
    return output


def write_member(archive, name, data):
    info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
    info.create_system = 3
    info.external_attr = (stat.S_IFREG | 0o644) << 16
    archive.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=6)


def verify(output, expected):
    """Check exact membership and bytes against the current prepared resources."""
    with zipfile.ZipFile(output) as archive:
        names = archive.namelist()
        rows = expected['files']
        if len(names) != len(set(names)) or set(names) != {r['path'] for r in rows} | {'manifest.json'}:
            raise ValueError('The alternative archive contains unexpected or missing files.')
        if json.loads(archive.read('manifest.json')) != expected:
            raise ValueError('The alternative archive manifest is stale or changed.')
        for row in rows:
            info = archive.getinfo(row['path'])
            if stat.S_IFMT(info.external_attr >> 16) != stat.S_IFREG:
                raise ValueError(f'Unexpected archive entry: {row["path"]}')
            data = archive.read(info)
            if len(data) != row['bytes'] or hashlib.sha256(data).hexdigest() != row['sha256']:
                raise ValueError(f'Changed archive content: {row["path"]}')


def build(output, files, manifest):
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=output.parent, suffix='.zip', delete=False) as temporary:
        staging = Path(temporary.name)
    try:
        expected = {row['path']: row for row in manifest['files']}
        with zipfile.ZipFile(staging, 'w') as archive:
            for name, path in sorted(files.items()):
                data = path.read_bytes()
                if hashlib.sha256(data).hexdigest() != expected[name]['sha256']:
                    raise ValueError(f'Resource changed during packaging: {path}')
                write_member(archive, name, data)
            write_member(archive, 'README.txt', README)
            write_member(archive, 'manifest.json', (json.dumps(manifest, indent=2) + '\n').encode())
        verify(staging, manifest)
        staging.replace(output)
    finally:
        staging.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify', action='store_true')
    parser.add_argument('--output', type=Path,
                        default=ROOT / '.build/alternative-assets/open-alternative.zip')
    args = parser.parse_args()
    verify_inputs(ROOT)
    files = collect(ROOT)
    output = validate_output(ROOT, args.output, files)
    manifest = manifest_for(files)
    if args.verify:
        verify(output, manifest)
    else:
        build(output, files, manifest)
    print(f'Alternative archive verified: {len(manifest["files"])} files, '
          f'{output.stat().st_size} bytes, SHA-256 {digest(output)}')


if __name__ == '__main__':
    main()
