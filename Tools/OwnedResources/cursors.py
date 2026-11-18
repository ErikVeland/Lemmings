#!/usr/bin/env python3
"""Recover the two exact cursor PNGs from a player-supplied preservation app."""
from __future__ import annotations

import argparse
import base64
import binascii
import hashlib
import json
from pathlib import Path
import plistlib
import re
import struct

PINS = {
    'Cursors/original-cross.png': '68d2bea78b11e2a115cdb4b752ff8e96d773419910874401d3a76e853d52d200',
    'Cursors/original-reticule.png': '5985e79a9f75434962a8a5bafef576cfb78d625dc4ffdd74a02cc3b78fbd03aa',
}
PNG = b'\x89PNG\r\n\x1a\n'
MAX_IMAGE = 2_000_000
MAX_EXECUTABLE = 512 * 1024 * 1024
BASE64_BYTES = frozenset(b'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=\r\n\t ')


class CursorError(ValueError):
    """The supplied source does not contain both verified cursor images."""


def _accept(data: bytes, found: dict[str, bytes]) -> None:
    if not 24 <= len(data) <= MAX_IMAGE or not data.startswith(PNG):
        return
    if data[12:16] != b'IHDR' or struct.unpack('>II', data[16:24]) != (28, 28):
        return
    digest = hashlib.sha256(data).hexdigest()
    for path, expected in PINS.items():
        if digest == expected:
            found[path] = data


def extract(binary: bytes) -> dict[str, bytes]:
    """Read only hash-pinned cursor candidates; never execute the supplied bytes."""
    if len(binary) > MAX_EXECUTABLE:
        raise CursorError('The supplied executable exceeds the cursor recovery size limit.')
    found: dict[str, bytes] = {}
    for match in re.finditer(re.escape(PNG), binary):
        start = match.start()
        offset = start + len(PNG)
        while offset + 12 <= len(binary) and offset - start <= MAX_IMAGE:
            length = struct.unpack('>I', binary[offset:offset + 4])[0]
            end = offset + length + 12
            if length > MAX_IMAGE or end > len(binary) or end - start > MAX_IMAGE:
                break
            kind = binary[offset + 4:offset + 8]
            offset = end
            if kind == b'IEND':
                _accept(binary[start:end], found)
                break
    for match in re.finditer(b'iVBORw0KGgo', binary):
        start = match.start()
        end = start
        while end < min(len(binary), start + 16384) and binary[end] in BASE64_BYTES:
            end += 1
        candidate = re.sub(rb'\s+', b'', binary[start:end])
        padding = candidate.find(b'=')
        if padding != -1:
            end = padding + (2 if candidate[padding:padding + 2] == b'==' else 1)
            candidate = candidate[:end]
        try:
            _accept(base64.b64decode(candidate, validate=True), found)
        except (binascii.Error, ValueError):
            continue
    return found


def _contained(path: Path, root: Path) -> None:
    if path != root and root not in path.parents:
        raise CursorError('Cursor recovery must stay inside the selected source.')
    current = path
    while True:
        if current.is_symlink():
            raise CursorError('Cursor recovery does not follow symbolic links.')
        if current == root:
            return
        current = current.parent


def _source_paths(source: Path) -> tuple[Path, Path | None]:
    source = source.expanduser().absolute()
    if source.is_file():
        return source.parent, source
    app = source if source.suffix.lower() == '.app' else None
    if source.name == 'Resources' and source.parent.name == 'Contents' and source.parent.parent.suffix.lower() == '.app':
        app = source.parent.parent
    if app is not None:
        resources = app / 'Contents/Resources'
        info = app / 'Contents/Info.plist'
        _contained(resources, app)
        _contained(info, app)
        try:
            name = plistlib.loads(info.read_bytes()).get('CFBundleExecutable')
        except (OSError, ValueError, plistlib.InvalidFileException):
            name = None
        if isinstance(name, str) and name and Path(name).name == name and name not in {'.', '..'}:
            executable = app / 'Contents/MacOS' / name
            _contained(executable, app)
            return resources, executable
        return resources, None
    return source, None


def collect(source: Path) -> dict[str, bytes]:
    """Recover a complete pair from resource files or the same supplied app's executable."""
    resources, executable = _source_paths(source)
    found: dict[str, bytes] = {}
    for path in PINS:
        file = resources / path
        if file.is_file() and not file.is_symlink() and file.stat().st_size <= MAX_IMAGE:
            _contained(file, resources)
            _accept(file.read_bytes(), found)
    if len(found) != len(PINS) and executable is not None and executable.is_file() and not executable.is_symlink():
        if executable.stat().st_size > MAX_EXECUTABLE:
            raise CursorError('The supplied executable exceeds the cursor recovery size limit.')
        found.update(extract(executable.read_bytes()))
    if set(found) != set(PINS):
        raise CursorError('Both original cursors were not found. Supply the full preservation app or its prepared cursor files.')
    return found


def stage(output: Path, files: dict[str, bytes], source: str) -> None:
    """Stage two verified PNGs and keep their provenance outside the imported family."""
    if set(files) != set(PINS):
        raise CursorError('The cursor export is incomplete.')
    verified: dict[str, bytes] = {}
    for data in files.values():
        _accept(data, verified)
    if verified != files:
        raise CursorError('The cursor export does not match its pinned source images.')
    directory = output / 'Cursors'
    if directory.is_symlink() or output.is_symlink():
        raise CursorError('The cursor output must not be a symbolic link.')
    if directory.exists() and {p.name for p in directory.iterdir()} - {'original-cross.png', 'original-reticule.png'}:
        raise CursorError('The cursor output contains unrelated files.')
    directory.mkdir(parents=True, exist_ok=True)
    for path, data in files.items():
        destination = output / path
        if destination.is_symlink():
            raise CursorError('The cursor output must not be a symbolic link.')
        destination.write_bytes(data)
    provenance = {'schemaVersion': 1, 'source': source, 'files': PINS,
        'notice': 'Original supplied Amiga game artwork. No redistribution clearance is asserted. Exclude these PNGs from clean Store and asset-free helper bundles.'}
    provenance_file = output / 'original-cursors-provenance.json'
    if provenance_file.is_symlink():
        raise CursorError('The cursor provenance output must not be a symbolic link.')
    provenance_file.write_text(json.dumps(provenance, indent=2) + '\n')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    choice = parser.add_mutually_exclusive_group(required=True)
    choice.add_argument('--source', type=Path)
    choice.add_argument('--fixtures', action='store_true')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.fixtures:
        fixtures = Path(__file__).resolve().parents[2] / 'Tests/DialogCursorTests/Fixtures'
        files = dict(zip(PINS, ((fixtures / name).read_bytes() for name in ['amiga-cursor.png', 'amiga-reticule.png'])))
        source = 'Tests/DialogCursorTests/Fixtures'
    else:
        files = collect(args.source)
        source = str(args.source)
    stage(args.output, files, source)
    print('Prepared both hash-verified original cursor PNGs; excluded from clean distribution.')


if __name__ == '__main__':
    main()
