"""Extract L2 animation data without including or executing DOS code."""
from pathlib import Path
import argparse
from rko import Overlay

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("source", type=Path)
parser.add_argument("destination", type=Path)
args = parser.parse_args()
overlay = Overlay(args.source / "PROCESS.RKO")
if overlay.exports.get("DrawLemmSprites") != (1, 0x0A53):
    raise ValueError("Unrecognised L2 explosion animation layout")
points = overlay.code[0x15C4:0x15C4 + 52 * 80 * 2]
if len(points) != 8320:
    raise ValueError("Truncated L2 explosion animation")
args.destination.mkdir(parents=True, exist_ok=True)
(args.destination / "EXPLOSION.DAT").write_bytes(b"L2EP\x34\x00\x50\x00" + points)

# VGA 2074 selects sixteen pre-shifted walking poses. Decode only their
# constant pixel writes into images; no executable overlay ships in the app.
import struct
vga = Overlay(args.source / "VGA.RKO")
if vga.exports.get("DrawLemmings") != (1, 0x1D48):
    raise ValueError("Unrecognised L2 walker graphics layout")
walkers = bytearray()
for start in struct.unpack_from("<16H", vga.code, 0x2074):
    cursor, address, plane, colour, mask = start, 0, 0, 0, 1
    pixels = bytearray(16 * 10)
    for _ in range(256):
        op = vga.code[cursor]
        cursor += 1
        if op == 0xC3:
            break
        if op in (0x81, 0x83):
            register = vga.code[cursor]
            cursor += 1
            size = 2 if op == 0x81 else 1
            amount = int.from_bytes(vga.code[cursor:cursor+size], "little", signed=True)
            cursor += size
            if register not in (0xC7, 0xEF):
                raise ValueError("Unexpected walker address command")
            address += amount if register == 0xC7 else -amount
        elif op == 0x8A:
            source = vga.code[cursor]
            cursor += 1
            colour = {0xC3: 2, 0xC7: 3, 0xC1: 1}[source]
        elif op == 0xB8:
            port, mask = vga.code[cursor:cursor+2]
            cursor += 2
            if port != 2 or mask not in (2, 4, 8):
                raise ValueError("Unexpected walker plane mask")
        elif op == 0xEF:
            plane = {1: 0, 2: 1, 4: 2, 8: 3}[mask]
        elif op == 0x47:
            address += 1
        elif op == 0xAA:
            x, y = address % 96 * 4 + plane, address // 96
            if not (0 <= x < 16 and 0 <= y < 10):
                raise ValueError("Walker pixel outside its image")
            pixels[y * 16 + x] = colour
            address += 1
        else:
            raise ValueError(f"Unexpected walker graphics command {op:02x}")
    else:
        raise ValueError("Unterminated walker graphics")
    walkers.extend(pixels)
(args.destination / "WALKER.DAT").write_bytes(b"L2WK\x10\x00\x0a\x00" + walkers)
