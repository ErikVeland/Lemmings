"""Verify that the embedded control tiles retain the original Amiga pixels."""
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
print(f'Source SHA-256: {sha256(data).hexdigest()}')
