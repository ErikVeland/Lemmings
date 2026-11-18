#!/usr/bin/env python3
"""Export the project's compact pixel lettering into fixed interface cells."""
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]


def resources():
    source = ROOT / 'Sources/LemmingsGameArt/GamePixelTypography.swift'
    text = source.read_text().split('private static let glyphs', 1)[0]
    columns = {key: [int(value) for value in values.split(',')]
               for key, values in re.findall(r'"([^"\\]+)":\[([\d,]+)\]', text)}
    columns.update({
        '"': [0, 3, 0, 3, 0], '#': [20, 127, 20, 127, 20],
        '$': [36, 42, 127, 42, 18], '&': [54, 73, 85, 34, 80],
        ';': [0, 64, 54, 0, 0], '@': [62, 65, 93, 85, 30],
        '[': [0, 127, 65, 65, 0], '\\': [2, 4, 8, 16, 32],
        ']': [0, 65, 65, 127, 0], '^': [4, 2, 1, 2, 4],
        '_': [64, 64, 64, 64, 64], '`': [0, 1, 2, 0, 0],
        '{': [0, 8, 54, 65, 0], '|': [0, 0, 127, 0, 0],
        '}': [0, 65, 54, 8, 0], '~': [8, 4, 8, 16, 8],
    })
    files, banks, names = {}, {}, {}
    prefix = 'Fonts/LixInterface/'

    def frame(character, width, height, scale, filename, black=False):
        bits = columns.get(character.upper())
        if bits is None:
            raise ValueError('The project pixel font is missing a required character: ' + character)
        pixels = bytearray(width * height * 4)
        dx, dy = (width - 5 * scale) // 2, (height - 7 * scale) // 2
        for x, column in enumerate(bits):
            for y in range(7):
                if not column & (1 << y):
                    continue
                color = bytes((0, 0, 0, 255) if black else (48, 128 + y * 8, 208, 255))
                for sy in range(scale):
                    for sx in range(scale):
                        index = ((dy + y * scale + sy) * width + dx + x * scale + sx) * 4
                        pixels[index:index + 4] = color
        files[prefix + filename] = bytes(pixels)
        return {'x': 0, 'y': 0, 'width': width, 'height': height, 'file': filename}

    for bank, face, width, height in [('1', 'Charset1', 12, 18), ('2', 'Charset2', 16, 20)]:
        frames = [None]
        for scalar in range(33, 127):
            frames.append(frame(chr(scalar), width, height, 2, f'{face}-{scalar}.rgba'))
        frames.append(None)
        for digit in range(10):
            frames.append(frame(str(digit), 6, 9, 1, f'{face}-digit-{digit}.rgba', black=True))
        blank = f'{face}-digit-blank.rgba'
        files[prefix + blank] = bytes(6 * 9 * 4)
        frames.append({'x': 0, 'y': 0, 'width': 6, 'height': 9, 'file': blank})
        banks[bank], names[bank] = frames, face
    manifest = {'version': 1, 'monochrome': False, 'names': names, 'banks': banks, 'objects': {}}
    files[prefix + 'manifest.json'] = (json.dumps(manifest, indent=2, sort_keys=True) + '\n').encode()
    provenance = {'schemaVersion': 1, 'sourceTypeface': 'Ultimate Lemmix project pixel lettering',
                  'source': source.relative_to(ROOT).as_posix(),
                  'sourceSHA256': hashlib.sha256(source.read_bytes()).hexdigest(),
                  'originalGameAssets': False, 'lowercase': 'uppercase pixel forms',
                  'method': 'Integer-scaled project glyph columns with fixed cells and authored punctuation.',
                  'files': {name: hashlib.sha256(data).hexdigest() for name, data in sorted(files.items())}}
    files[prefix + 'provenance.json'] = (json.dumps(provenance, indent=2, sort_keys=True) + '\n').encode()
    return files
