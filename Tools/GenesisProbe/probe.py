#!/usr/bin/env python3
"""Reads the level parameter table out of the Mega Drive Lemmings ROM.

The ROM stores one 48 byte record per level: a 16 byte header then a 32 byte
title. The header is release rate, lemming count, save requirement and time in
minutes, then one byte per skill in the DOS skill order.

This reads parameters and titles only. It does not read level geometry, which
lives elsewhere in the ROM and is not decoded yet.
"""
import sys
from pathlib import Path

ROM = Path(sys.argv[1] if len(sys.argv) > 1
           else "Sources/Ports/Lemmings Genesis/Lemmings.bin")
TABLE = 0x14000
RECORD = 48
SKILLS = ["climber", "floater", "bomber", "blocker", "builder", "basher", "miner", "digger"]


def printable(b):
    return all(32 <= c <= 126 for c in b)


def records(data, base=TABLE):
    offset = base
    while offset + RECORD <= len(data):
        title = data[offset + 16:offset + RECORD]
        if not printable(title):
            return
        header = data[offset:offset + 16]
        yield offset, header, title.decode("latin1").strip()
        offset += RECORD


def main():
    data = ROM.read_bytes()
    rows = list(records(data))
    print(f"{ROM.name}: {len(data)} bytes, {len(rows)} level records at 0x{TABLE:X}")
    for index, (offset, header, title) in enumerate(rows):
        skills = ", ".join(f"{name}={header[4 + i]}"
                           for i, name in enumerate(SKILLS) if header[4 + i])
        print(f"{index:3d} 0x{offset:06X} rate={header[0]:3d} lemmings={header[1]:3d} "
              f"save={header[2]:3d} minutes={header[3]:2d}  {title!r}  [{skills}]")


if __name__ == "__main__":
    main()
