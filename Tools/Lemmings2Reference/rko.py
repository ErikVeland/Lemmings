"""Inspect local L2 overlays without executing or redistributing original code.

Requires Capstone only for disassembly. Offsets are relative to the selected
overlay's code segment, before the original loader applies relocations.
"""

import argparse
from pathlib import Path
import struct


class Overlay:
    def __init__(self, path):
        raw = Path(path).read_bytes()
        self.path = path
        (symbol_count, export_count, data_size, data_relocations,
         code_size, external_relocations, internal_relocations) = struct.unpack_from("<HHIHHHH", raw)
        cursor = 16
        self.symbols = []
        for _ in range(symbol_count):
            length = raw[cursor]
            if length < 1 or raw[cursor + length] != 0:
                raise ValueError("Invalid RKO symbol string")
            self.symbols.append(raw[cursor + 1:cursor + length].decode("ascii"))
            cursor += length + 1
        self.exports = {}
        for _ in range(export_count):
            symbol, segment, offset = struct.unpack_from("<BBH", raw, cursor)
            self.exports[self.symbols[symbol]] = (segment, offset)
            cursor += 4
        self.data = raw[cursor:cursor + data_size]
        cursor += data_size + data_relocations * 3
        self.code_offset = cursor
        self.code = raw[cursor:cursor + code_size]
        cursor += code_size
        self.references = {}
        for _ in range(external_relocations):
            symbol, relocation_type, offset = struct.unpack_from("<BBH", raw, cursor)
            self.references[offset] = self.symbols[symbol]
            cursor += 4
        # Three-byte internal fixups are not symbol references. Their first
        # byte selects a segment, not an entry in the symbol string table.
        cursor += internal_relocations * 3
        if cursor != len(raw):
            raise ValueError(f"RKO size mismatch: {cursor} != {len(raw)}")

    def disassemble(self, start, end):
        from capstone import Cs, CS_ARCH_X86, CS_MODE_16
        decoder = Cs(CS_ARCH_X86, CS_MODE_16)
        for ins in decoder.disasm(self.code[start:end], start):
            refs = [self.references[p] for p in range(ins.address, ins.address + ins.size)
                    if p in self.references]
            suffix = " ; " + ", ".join(dict.fromkeys(refs)) if refs else ""
            print(f"{ins.address:04x}  {ins.mnemonic:8} {ins.op_str}{suffix}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("overlay")
    parser.add_argument("--start", type=lambda s: int(s, 0))
    parser.add_argument("--end", type=lambda s: int(s, 0))
    parser.add_argument("--symbol")
    parser.add_argument("--skills", action="store_true")
    args = parser.parse_args()
    overlay = Overlay(args.overlay)
    print(f"{args.overlay}: code at file 0x{overlay.code_offset:x}, {len(overlay.code)} bytes")
    if args.skills:
        for skill in range(0x7a):
            target = struct.unpack_from("<H", overlay.code, 0x29a + skill * 2)[0]
            print(f"{skill:02x}: {target:04x}")
    elif args.start is not None or args.symbol:
        start = args.start
        if args.symbol:
            segment, start = overlay.exports[args.symbol]
            if segment != 1:
                raise ValueError("Requested symbol is data, not code")
        overlay.disassemble(start, args.end if args.end is not None else start + 256)
    else:
        for name, (segment, offset) in overlay.exports.items():
            print(f"{name:24} {'code' if segment else 'data'} {offset:04x}")
