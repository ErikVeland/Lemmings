#!/usr/bin/env python3
"""Prepare original lettering for a separate personal Mac preview, not a store bundle."""

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE_DISK = ROOT / 'Sources/Ports/lemmings_1_5_2/Lemmings_1_5_2.dsk'
SOURCE = ROOT / '.build/mac-artwork/export/lemmings'
OUTPUT = ROOT / '.build/personal-preview-assets/Fonts/OriginalLemmings'
PACK_ID = 'ultimate-lemmix-personal-original-lettering-v1'
DISK_SHA256 = 'fdcae811b0c5b967f543f9943df0c51e262b4671351c768f27823c27e45e2bd3'
EXPORT_SHA256 = '1dada9e2603d899d9490292555f887365f73120fe291ae866a36383d785bb41e'
CURRENT_EXPORT_SHA256 = '5f18a5d04833309b96302938f2f12b64ae7bd47eae4bce404ab9ecab62a51c34'
GLYPHS_SHA256 = 'd6defafa920060a4b09423299b99f61c4370a099362c944d0d3a33ef9e74587c'


def digest(data):
    """Identify exact local bytes without implying permission to redistribute."""
    return hashlib.sha256(data).hexdigest()


def encoded(value):
    """Serialise stable records without machine paths or timestamps."""
    return (json.dumps(value, indent=2, ensure_ascii=False) + '\n').encode()


def read_regular(path, maximum):
    """Reject links, missing files and oversized inputs."""
    if path.is_symlink() or not path.is_file() or path.stat().st_size > maximum:
        raise ValueError('An original-font source file is missing, linked or oversized: ' + path.name)
    return path.read_bytes()


def validate_frame(row, bank, index, width, height):
    """Accept only the expected printable-character frame and dimensions."""
    if (not isinstance(row, dict) or set(row) != {'x', 'y', 'width', 'height', 'file'}
            or row['file'] != f'{bank}-{index}.rgba'
            or any(type(row[key]) is not int for key in ('x', 'y', 'width', 'height'))
            or row['x'] < 0 or row['y'] < 0 or row['width'] <= 0 or row['height'] <= 0
            or row['x'] + row['width'] > width or row['y'] + row['height'] > height):
        raise ValueError('An original-font glyph has an unexpected path or shape.')


def expected_files(source_root=ROOT):
    """Select only the pinned original printable ASCII glyphs and provenance."""
    source_disk = source_root / SOURCE_DISK.relative_to(ROOT)
    source = source_root / SOURCE.relative_to(ROOT)
    disk = read_regular(source_disk, 3_000_000)
    manifest_data = read_regular(source / 'manifest.json', 100_000)
    if digest(disk) != DISK_SHA256 or digest(manifest_data) not in {EXPORT_SHA256, CURRENT_EXPORT_SHA256}:
        raise ValueError('The local Macintosh font source differs from the reviewed source.')
    manifest = json.loads(manifest_data)
    files, banks, names = {}, {}, {}
    for bank, name, width, height in (
            ('1301', 'Charset1', 12, 18), ('1302', 'Charset2', 16, 20)):
        if manifest['names'].get(bank) != name:
            raise ValueError('The original font bank name changed.')
        rows = manifest['banks'][bank][:95]
        if len(rows) != 95 or rows[0] is not None or any(row is None for row in rows[1:]):
            raise ValueError('The original font does not contain the reviewed printable ASCII range.')
        for index, row in enumerate(rows):
            if row is None:
                continue
            validate_frame(row, bank, index, width, height)
            data = read_regular(source / row['file'], width * height * 4)
            if len(data) != row['width'] * row['height'] * 4:
                raise ValueError('An original-font glyph is truncated.')
            files[row['file']] = data
        banks[bank], names[bank] = rows, name
    aggregate = hashlib.sha256()
    for name, data in sorted(files.items()):
        aggregate.update(name.encode() + b'\0' + data)
    if len(files) != 188 or sum(map(len, files.values())) != 150_120 or aggregate.hexdigest() != GLYPHS_SHA256:
        raise ValueError('The original-font pixels differ from the reviewed glyphs.')
    files['manifest.json'] = encoded({'version': 1, 'banks': banks, 'names': names, 'objects': {}})
    files['NOTICE.txt'] = (
        'ORIGINAL LEMMINGS LETTERING — PERSONAL MAC PREVIEW ONLY\n\n'
        'These are original Macintosh Lemmings game pixels, not CC0 artwork.\n'
        'They come from the supplied local Lemmings 1.5.2 disk through the\n'
        'repository Macintosh artwork decoder. Original rights remain with\n'
        'their owners. No independent redistribution grant is recorded here.\n'
        'Do not include this pack in a clean Ultimate Lemmix store build.\n'
        'The pack contains printable ASCII font glyphs only. It contains no\n'
        'logos, publisher screens, gameplay sprites, terrain or level data.\n'
        'The app must set UltimateLemmixPersonalPreview=true to load this path.\n'
    ).encode()
    files['provenance.json'] = encoded({
        'schemaVersion': 1, 'id': PACK_ID, 'kind': 'original-commercial-game-lettering',
        'distributionScope': 'personal-local-mac-preview-only',
        'redistributionCleared': False, 'cc0': False, 'storeBundleAllowed': False,
        'sourceDisk': {'path': SOURCE_DISK.relative_to(ROOT).as_posix(), 'sha256': DISK_SHA256},
        'sourceExport': {'path': (SOURCE / 'manifest.json').relative_to(ROOT).as_posix(),
                         'sha256': digest(manifest_data)},
        'sourceDecoder': 'Tools/MacArtwork/prepare.py',
        'glyphAggregateSHA256': GLYPHS_SHA256, 'glyphFiles': 188, 'glyphBytes': 150_120,
        'characterRange': {'first': 32, 'last': 126},
        'faces': [{'name': 'Charset1', 'cellWidth': 12, 'cellHeight': 18},
                  {'name': 'Charset2', 'cellWidth': 16, 'cellHeight': 20}],
        'files': [{'path': name, 'bytes': len(data), 'sha256': digest(data)}
                  for name, data in sorted(files.items())],
    })
    return files


def safe_output(output):
    """Keep writes in the fixed personal-preview build folder and reject links."""
    if output != OUTPUT:
        raise ValueError('Original fonts may be prepared only in the personal-preview output folder.')
    for path in (output, *output.parents):
        if path == ROOT:
            break
        if path.is_symlink():
            raise ValueError('Personal-preview output folders must not be links.')


def verify(output, files):
    """Verify exact membership and every source-derived byte, not mutable inventory claims."""
    safe_output(output)
    actual = set()
    for path in output.rglob('*'):
        if path.is_symlink() or not (path.is_dir() or path.is_file()):
            raise ValueError('The personal font pack contains a link or unsupported entry.')
        if path.is_file():
            actual.add(path.relative_to(output).as_posix())
    if actual != set(files):
        raise ValueError('The personal font pack contains missing or extra files.')
    for name, data in files.items():
        if read_regular(output / name, len(data)) != data:
            raise ValueError('A personal font-pack file changed: ' + name)


def prepare(output, files):
    """Publish a new exact pack and refuse to replace unrelated or modified output."""
    safe_output(output)
    if output.exists():
        if not output.is_dir():
            raise ValueError('The personal font output is not a directory.')
        verify(output, files)
        return
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = Path(tempfile.mkdtemp(prefix='.original-font-', dir=output.parent))
    try:
        for name, data in files.items():
            (temporary / name).write_bytes(data)
        temporary.rename(output)
    finally:
        if temporary.exists():
            shutil.rmtree(temporary)
    verify(output, files)


class FontSafetyTests(unittest.TestCase):
    def test_glyph_paths_and_dimensions(self):
        row = {'x': 0, 'y': 1, 'width': 12, 'height': 17, 'file': '1301-1.rgba'}
        validate_frame(row, '1301', 1, 12, 18)
        for mutation in ({'file': '../private'}, {'file': '/private'}, {'width': 13},
                         {'height': 18}, {'x': -1}, {'width': True}):
            with self.assertRaises(ValueError):
                validate_frame({**row, **mutation}, '1301', 1, 12, 18)

    def test_no_store_output(self):
        with self.assertRaises(ValueError):
            safe_output(ROOT / '.build/ultimate-lemmix-app-store/Ultimate Lemmix.app/Contents/Resources')

    def test_no_linked_inputs(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'source').write_bytes(b'pixels')
            (root / 'linked').symlink_to(root / 'source')
            with self.assertRaises(ValueError):
                read_regular(root / 'linked', 100)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify', action='store_true')
    parser.add_argument('--self-test', action='store_true')
    parser.add_argument('--source-root', type=Path, default=ROOT)
    args = parser.parse_args()
    if args.self_test:
        result = unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(FontSafetyTests))
        return 0 if result.wasSuccessful() else 1
    files = expected_files(args.source_root)
    if args.verify:
        verify(OUTPUT, files)
    else:
        prepare(OUTPUT, files)
    print(f'PASS personal original lettering: 188 glyphs, 150,120 pixel bytes; {OUTPUT}')
    print('Original game artwork. Not CC0 or cleared for store redistribution.')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError) as error:
        raise SystemExit('FAILED: ' + str(error))
