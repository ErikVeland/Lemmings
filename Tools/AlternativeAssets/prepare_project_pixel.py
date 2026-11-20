#!/usr/bin/env python3
"""Package the same pixel font glyphs that Ultimate Lemmings uses."""
import hashlib
import json
import os
from pathlib import Path

from prepare_original_font import read_regular, validate_frame

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SOURCE = ROOT / '.build/mac-artwork/export/lemmings'
FONT_SHA256 = '0a11289b889d131a4ddbca48c427320f18ce842a5d9d1ba959fc38a0256b0dfa'
FONT_PREFIX = 'Fonts/LixInterface/'
NOTICE = FONT_PREFIX + 'NOTICE.md'


def verify_packaged_font(files):
    """Reject a prepared package that contains an old or changed font bank."""
    glyphs = {
        name.removeprefix(FONT_PREFIX): data for name, data in files.items()
        if name == FONT_PREFIX + 'manifest.json'
        or (name.startswith(FONT_PREFIX) and name.endswith('.rgba'))
    }
    digest = hashlib.sha256()
    for name, data in sorted(glyphs.items()):
        digest.update(name.encode() + b'\0' + data)
    if digest.hexdigest() != FONT_SHA256:
        raise ValueError('The Ultimate Lemmings pixel font differs from the verified glyphs and metrics.')


def resources():
    """Copy only the two font faces and their counters from the verified source bank."""
    source = Path(os.environ.get('ULTIMATE_LEMMIX_PIXEL_FONT_DIR', DEFAULT_SOURCE))
    manifest = source / 'manifest.json'
    if not manifest.is_file():
        raise ValueError('The Ultimate Lemmings pixel font source is missing. Set '
                         'ULTIMATE_LEMMIX_PIXEL_FONT_DIR to its MacArtwork/lemmings directory.')
    original = json.loads(read_regular(manifest, 100_000))
    if not isinstance(original, dict) or not all(isinstance(original.get(key), dict) for key in ('banks', 'names')):
        raise ValueError('The Ultimate Lemmings pixel font manifest has an unexpected layout.')
    glyphs, banks, names = {}, {}, {}
    for bank, face, width, height in (('1301', 'Charset1', 12, 18), ('1302', 'Charset2', 16, 20)):
        source_rows = original['banks'].get(bank)
        if (original['names'].get(bank) != face or not isinstance(source_rows, list)
                or len(source_rows) < 107 or source_rows[0] is not None):
            raise ValueError('The Ultimate Lemmings pixel font bank has an unexpected layout.')
        # The source atlas and panel artwork are outside the font itself.
        rows = source_rows[:107]
        rows[95] = None
        for index, row in enumerate(rows):
            if index in (0, 95):
                continue
            cell_width, cell_height = (width, height) if index < 95 else (6, 9)
            validate_frame(row, bank, index, cell_width, cell_height)
            data = read_regular(source / row['file'], cell_width * cell_height * 4)
            if len(data) != row['width'] * row['height'] * 4:
                raise ValueError('An Ultimate Lemmings pixel font glyph is truncated.')
            glyphs[row['file']] = data
        banks[bank], names[bank] = rows, face

    glyphs['manifest.json'] = json.dumps(
        {'version': 1, 'banks': banks, 'names': names, 'objects': {}},
        sort_keys=True, separators=(',', ':'),
    ).encode()
    files = {FONT_PREFIX + name: data for name, data in glyphs.items()}
    verify_packaged_font(files)
    files[NOTICE] = (
        '# Ultimate Lemmings shared pixel font\n\n'
        'The project owner confirmed permission to use the customised pixel font in Ultimate Lemmings, '
        'Ultimate Lemmix and their App Store marketing. The font is covered by the project’s own licence.\n\n'
        'This bundle contains the two font faces and counter glyphs. The source atlas and game panel are excluded.\n'
    ).encode()
    provenance = {
        'schemaVersion': 1,
        'sourceTypeface': 'Ultimate Lemmings shared pixel font',
        'glyphsAndMetricsSHA256': FONT_SHA256,
        'glyphFiles': len(glyphs) - 1,
        'notice': NOTICE,
    }
    files[FONT_PREFIX + 'provenance.json'] = (json.dumps(provenance, indent=2, sort_keys=True) + '\n').encode()
    return files
