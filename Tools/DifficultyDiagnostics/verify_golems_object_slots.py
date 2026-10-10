"""Check the pinned Golems assembly's 32-slot gadget handling."""

import hashlib
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ASSEMBLY = ROOT / ".build/learning-evidence/Golems.Core.dll"
ASSEMBLY_SHA256 = "38cb69f18f5055821a496336a948fc30596e56c607c3ddddfb4675be78a5873e"
METHODS = {
    # These RVAs and method names come from this exact assembly's .NET MethodDef table.
    "Level.ReadFrom": (0x10A6C, "97b105f728c4063cdea5bcfaa33168af47776786131bf786c6906fcc01b2ef54"),
    "GameState.ctor": (0x48A4, "da3409ac72c01b59e85bf68fb9955f5c93b636beda6f93b4c5c9c26fd838a7b1"),
    "GameState.InitializeGadgets": (0x5C20, "317654b93b17d0148b884ac4a3fb0cf2a9d8855ff7978bdfd15e248fc16880c1"),
    "GameState.UpdateGolemEffects": (0x8070, "6fc0a9377dfed801ca9a40700ec30d6bd1dd250239e36648c631d361f520cbec"),
    "GameState.AdvanceGadgets": (0x8454, "403e624801e99e3db2bacd4f719f096e0d2c892d92e0360c05d9a782468d6a8a"),
}


def main():
    data = ASSEMBLY.read_bytes()
    assert hashlib.sha256(data).hexdigest() == ASSEMBLY_SHA256

    def word(offset):
        return struct.unpack_from("<H", data, offset)[0]

    def dword(offset):
        return struct.unpack_from("<I", data, offset)[0]

    pe = dword(0x3C)
    section_table = pe + 24 + word(pe + 20)
    sections = []
    for index in range(word(pe + 6)):
        offset = section_table + index * 40
        sections.append((dword(offset + 12), dword(offset + 8),
                         dword(offset + 16), dword(offset + 20)))

    def method_body(rva):
        section = next((item for item in sections
                        if item[0] <= rva < item[0] + max(item[1], item[2])), None)
        assert section is not None
        offset = section[3] + rva - section[0]
        assert data[offset] & 3 == 3  # Fat .NET method header.
        size = dword(offset + 4)
        start = offset + (word(offset) >> 12) * 4
        return data[start:start + size]

    bodies = {}
    for name, (rva, expected) in METHODS.items():
        body = method_body(rva)
        assert hashlib.sha256(body).hexdigest() == expected, name
        bodies[name] = body

    # ldc.i4.s 32; newarr LevelGadget and Gadget, respectively.
    assert bytes.fromhex("1f 20 8d 2a 00 00 02") in bodies["Level.ReadFrom"]
    assert bytes.fromhex("1f 20 8d 52 00 00 02 7d 79 00 00 04") in bodies["GameState.ctor"]
    # Initialise every level gadget, then advance the complete runtime array.
    assert bytes.fromhex("06 03 7c 4f 01 00 04 28 6d 00 00 0a") in bodies["GameState.InitializeGadgets"]
    assert bytes.fromhex("06 02 7b 79 00 00 04 8e 69 32") in bodies["GameState.AdvanceGadgets"]
    # Collision effects use a gadget index to address that runtime array.
    assert bytes.fromhex("02 7b 79 00 00 04 12 00 28 07 00 00 06 8f 52 00 00 02") in bodies["GameState.UpdateGolemEffects"]
    print("Verified Golems preview 7 reads, initialises, advances and addresses 32 gadget slots.")


if __name__ == "__main__":
    main()
