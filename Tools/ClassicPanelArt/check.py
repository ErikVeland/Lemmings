"""Verify that the embedded control tiles retain the original Amiga pixels."""
from collections import Counter
from hashlib import sha256
from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
source = root / 'Sources/Ports/amiga_extracted/lemmings/panel1'
data = source.read_bytes()
assert len(data) == 12800
swift = (root / 'Sources/LemmingsLocal/PanelGlyphs.swift').read_text()
for name, slot in [('pause', 10), ('nuke', 11)]:
    expected = []
    for y in range(17, 39):
        row = ''
        for x in range(slot * 32 + 2, slot * 32 + 30):
            value = sum(((data[plane * 3200 + y * 80 + x // 8] >> (7 - x % 8)) & 1) << plane
                        for plane in range(4))
            row += format(value, 'x')
        expected.append(row)
    block = swift.split(f'case .{name}:', 1)[1].split('case .', 1)[0]
    actual = re.findall(r'"([0-9a-f]+)"', block)
    assert actual == expected, f'{name} pixels differ from the Amiga panel'
    print(f'PASS original {name}: 28×22 indexed pixels')

# Rock behind the skill sprites. Take the same crop from the ten skill cells.
# Below the counter box, a pixel is the rock colour most cells agree on. Lemming
# pixels are not rock colours, so they do not vote. Where no clear majority
# exists, copy the nearest settled pixel in the same row, about half a cell
# away. The counter box covers the top eight rows, so mirror the rows below it.
def pixel(x, y):
    return sum(((data[plane * 3200 + y * 80 + x // 8] >> (7 - x % 8)) & 1) << plane for plane in range(4))

rock_colours = {0x5, 0x9, 0xa, 0xb, 0xc, 0xd, 0xe}
lower = {}
for y in range(25, 39):
    for x in range(2, 30):
        votes = Counter(v for v in (pixel(c * 32 + x, y) for c in range(10)) if v in rock_colours)
        if votes:
            value, count = votes.most_common(1)[0]
            if count > sum(votes.values()) / 2 and count >= 4:
                lower[(x, y)] = value
missing = [(x, y) for y in range(25, 39) for x in range(2, 30) if (x, y) not in lower]
while missing:
    for x, y in missing:
        for d in [14, -14, 13, -13, 15, -15, 12, -12, 16, -16, 11, -11, 17, -17, 10, -10, 18, -18]:
            if (x + d, y) in lower:
                lower[(x, y)] = lower[(x + d, y)]
                break
    missing = [key for key in missing if key not in lower]
expected = []
for y in range(17, 39):
    row = ''
    for x in range(2, 30):
        top = pixel(2 * 32 + x, y)
        value = lower[(x, y)] if y >= 25 else (top if top in rock_colours else lower[(x, 49 - y)])
        row += format(value, 'x')
    expected.append(row)
block = swift.split('case .rock:\n', 1)[1].split('case .', 1)[0]
assert re.findall(r'"([0-9a-f]+)"', block) == expected, 'rock pixels differ from the Amiga skill cells'
print('PASS panel rock: 28×22 indexed pixels from the ten skill cells')
print(f'Source SHA-256: {sha256(data).hexdigest()}')
