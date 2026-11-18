#!/usr/bin/env python3
"""Encode the project's three authored puzzles for the existing Classic loaders."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT = ROOT / "Resources/UltimateLemmix/Starter"
IDENTIFIER = "ultimate-lemmix-open-starter-v1"
PUZZLES = (
    ("First Steps", 6, 112, 66, None),
    ("Float to Safety", 3, 136, 16, 1),
    ("Over the Rise", 4, 130, 80, 0),
)


def dat_section(data: bytes) -> bytes:
    """Write valid backward DAT literal runs without a proprietary compressor."""
    if not data or len(data) > 65535:
        raise ValueError("A DAT section must contain 1 to 65535 bytes.")
    bits: list[int] = []

    def emit(value: int, count: int) -> None:
        bits.extend((value >> shift) & 1 for shift in range(count - 1, -1, -1))

    reverse = data[::-1]
    for start in range(0, len(reverse), 264):
        run = reverse[start:start + 264]
        if len(run) <= 8:
            emit(0, 2)
            emit(len(run) - 1, 3)
        else:
            emit(7, 3)
            emit(len(run) - 9, 8)
        for value in run:
            emit(value, 8)
    first_count = len(bits) % 8 or 8
    groups = [bits[:first_count]] + [bits[start:start + 8] for start in range(first_count, len(bits), 8)]
    payload = bytes(sum(bit << index for index, bit in enumerate(group)) for group in reversed(groups))
    checksum = 0
    for value in payload:
        checksum ^= value
    if len(payload) + 10 > 65535:
        raise ValueError("The literal DAT section exceeds the format limit.")
    return bytes((first_count, checksum, 0, 0)) + struct.pack(">HHH", len(data), 0, len(payload) + 10) + payload


def level_record(title: str, population: int, floor: int, hatch_y: int, skill: int | None) -> bytes:
    """Encode only project-authored placements, properties and skill counts."""
    data = bytearray(2048)
    struct.pack_into(">HHHH", data, 0, 50, population, population, 3)
    if skill is not None:
        struct.pack_into(">H", data, 8 + skill * 2, population)
    # Unused terrain slots use the native all-ones sentinel.
    data[0x120:0x760] = b"\xff" * 1600
    for slot, (x, y, object_id) in enumerate(((40, hatch_y, 1), (264, floor - 24, 0))):
        struct.pack_into(">hhHH", data, 0x20 + slot * 8, x + 16, y, object_id, 0)
    terrain = [(x, floor, 0) for x in range(0, 352, 16)]
    if skill == 0:
        terrain.append((152, floor - 44, 1))
    for slot, (x, y, piece_id) in enumerate(terrain):
        value = ((x + 16) << 16) | ((y + 4) << 7) | piece_id
        struct.pack_into(">I", data, 0x120 + slot * 4, value)
    data[0x7E0:0x800] = title.encode("ascii").ljust(32, b" ")
    return bytes(data)


def planar(pixels: list[int]) -> tuple[bytes, int]:
    """Encode four colour planes and the independent opacity plane."""
    size = (len(pixels) + 7) // 8
    data = bytearray(size * 5)
    for index, pixel in enumerate(pixels):
        for plane in range(4):
            if pixel & (1 << plane):
                data[plane * size + index // 8] |= 1 << (7 - index % 8)
        if pixel & 0x80 == 0:
            data[4 * size + index // 8] |= 1 << (7 - index % 8)
    return bytes(data), size * 4


def ground_files() -> tuple[bytes, bytes]:
    """Supply independent collision geometry and exit/hatch metadata; Lix supplies the scene art."""
    ground = bytearray(1056)
    terrain = bytearray()
    for piece_id, height in ((0, 16), (1, 44)):
        # These flat colour pixels are a geometry carrier, not an alternative art set.
        pixels, mask = planar([2] * (16 * height))
        struct.pack_into("<BBHHH", ground, 448 + piece_id * 8, 16, height, len(terrain), len(terrain) + mask, 0)
        terrain.extend(pixels)
    objects = bytearray()
    for object_id, width, height, effect in ((0, 24, 24, 1), (1, 32, 20, 0)):
        # Invisible source objects retain the simulation and Lix anchor contracts.
        pixels, mask = planar([0x80] * (width * height))
        offset = object_id * 28
        struct.pack_into("<HBBBBHH", ground, offset, 0, 0, 1, width, height, len(pixels), mask)
        struct.pack_into("<HH", ground, offset + 14, 1 if effect else 0, 5 if effect else 1)
        ground[offset + 18:offset + 21] = bytes((4, 4, effect))
        struct.pack_into("<H", ground, offset + 21, len(objects))
        objects.extend(pixels)
    # The carrier is intentionally neutral. Full presentation comes from CC0 Lix assets.
    ground[984:1008] = bytes((0, 0, 0, 14, 14, 14, 28, 28, 28, 42, 42, 42,
                              0, 28, 0, 0, 42, 0, 56, 56, 56, 14, 14, 28))
    return bytes(ground), dat_section(bytes(terrain)) + dat_section(bytes(objects))


def resources() -> dict[str, bytes]:
    ground, graphics = ground_files()
    files = {
        "LEVEL000.DAT": b"".join(dat_section(level_record(*puzzle)) for puzzle in PUZZLES),
        "GROUND0O.DAT": ground,
        "VGAGR0.DAT": graphics,
    }
    manifest = {
        "schemaVersion": 1,
        "identifier": IDENTIFIER,
        "name": "Open Starter",
        "origin": "Project-authored puzzles and independent geometry. No original game payload.",
        "presentation": "CC0 Lix artwork, packaged separately; these files carry geometry and triggers only.",
        "engine": "Existing unmodified Classic DAT, level, ground and simulation loaders",
        "levelFilePrefix": "LEVEL",
        "levels": [{"title": p[0], "population": p[1], "requiredToSave": p[1],
                    "floorY": p[2], "hatchY": p[3], "requiredSkill": {0: "climber", 1: "floater"}.get(p[4])}
                   for p in PUZZLES],
        "files": [{"path": name, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
                  for name, data in sorted(files.items())],
    }
    files["starter-manifest.json"] = (json.dumps(manifest, indent=2) + "\n").encode()
    return files


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    expected = resources()
    if args.check:
        for name, data in expected.items():
            if (args.output / name).read_bytes() != data:
                raise SystemExit(f"Starter data differs: {name}")
    else:
        args.output.mkdir(parents=True, exist_ok=True)
        for name, data in expected.items():
            (args.output / name).write_bytes(data)
    print(f"{'Verified' if args.check else 'Prepared'} 3 authored Classic levels and geometry: {args.output}")


if __name__ == "__main__":
    main()
