"""Check exit, timeout and fall rules in the pinned Golems assembly."""

import hashlib
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ASSEMBLY = ROOT / ".build/learning-evidence/Golems.Core.dll"
ASSEMBLY_SHA256 = "38cb69f18f5055821a496336a948fc30596e56c607c3ddddfb4675be78a5873e"
METHODS = {
    "GameState.ctor": (0x48A4, "da3409ac72c01b59e85bf68fb9955f5c93b636beda6f93b4c5c9c26fd838a7b1"),
    "GameState.AdvanceCore": (0x67AC, "fef6cc57aae633d447a33f84b73ecf9fe550e96255dbaa5494e0acc815a44e51"),
    "GameState.AdvanceExitingGolem": (0x7CFE, "98de0448ceabff8904e6315161adb6ab9ea5d5a2a69404943988f500fe2b9766"),
    "GameState.AdvanceFallingGolem": (0x6DB0, "bfaaf05ae1000f79dffd84d47b8ad028abc0d05bc2efb69c2c4fd5528562276e"),
    "GameState.AdvanceTime": (0x84D8, "460e38a579a03f2e29c597faf98a11a91bee4c2e66fbf437bc9ba19de1f32eaa"),
}


def main():
    data = ASSEMBLY.read_bytes()
    assert hashlib.sha256(data).hexdigest() == ASSEMBLY_SHA256
    word = lambda offset: struct.unpack_from("<H", data, offset)[0]
    dword = lambda offset: struct.unpack_from("<I", data, offset)[0]
    pe = dword(0x3C)
    section_table = pe + 24 + word(pe + 20)
    sections = [
        (dword(offset + 12), dword(offset + 8), dword(offset + 16), dword(offset + 20))
        for offset in (section_table + index * 40 for index in range(word(pe + 6)))
    ]

    def method_body(rva):
        section = next(item for item in sections
                       if item[0] <= rva < item[0] + max(item[1], item[2]))
        offset = section[3] + rva - section[0]
        if data[offset] & 3 == 3:
            size = dword(offset + 4)
            start = offset + (word(offset) >> 12) * 4
        else:
            assert data[offset] & 3 == 2
            size = data[offset] >> 2
            start = offset + 1
        return data[start:start + size]

    bodies = {}
    for name, (rva, expected) in METHODS.items():
        body = method_body(rva)
        assert hashlib.sha256(body).hexdigest() == expected, name
        bodies[name] = body

    exiting = bodies["GameState.AdvanceExitingGolem"]
    # Frame=(frame+1)&7. A nonzero frame skips the saved-count increment.
    assert bytes.fromhex("03 03 7b 25 03 00 04 17 58 1d 5f d2 7d 25 03 00 04") in exiting
    assert bytes.fromhex("03 7b 25 03 00 04 2d 17") in exiting
    assert bytes.fromhex("02 02 28 7b 00 00 06 17 58 d2 28 7c 00 00 06") in exiting

    falling = bodies["GameState.AdvanceFallingGolem"]
    # Fall height at most 60 bypasses the splat branch; larger falls set activity 1.
    assert bytes.fromhex("03 7b 20 03 00 04 1f 3c 31 36 03 17 28 64 03 00 06") in falling
    native = (ROOT / "Sources/NxlvKit/ClassicDOSSimulation.swift").read_text()
    assert "public static let maximumSafeFallDistance = 60" in native

    core = bodies["GameState.AdvanceCore"]
    # The tick advances lemmings before it advances the clock.
    advance_golems = core.index(bytes.fromhex("02 28 c9 00 00 06"))
    advance_time = core.index(bytes.fromhex("02 28 ef 00 00 06"))
    assert advance_golems < advance_time

    timer = bodies["GameState.AdvanceTime"]
    # The constructor starts with level minutes, zero seconds and one cycle.
    constructor = bodies["GameState.ctor"]
    assert bytes.fromhex(
        "02 04 6f 1b 02 00 06 28 7e 00 00 06 "
        "02 16 28 80 00 00 06 02 17 28 82 00 00 06"
    ) in constructor
    # Zero minutes and seconds sets Done before the cycle decrement.
    assert timer.startswith(bytes.fromhex("02 28 7d 00 00 06 2d 17 02 28 7f 00 00 06 2d 0f"))
    assert bytes.fromhex("02 02 28 69 00 00 06 17 60 28 6a 00 00 06 2a") in timer
    # The signed cycle counter wraps on -17 and then decrements seconds.
    assert bytes.fromhex(
        "02 02 28 81 00 00 06 17 59 67 28 82 00 00 06 "
        "02 28 81 00 00 06 1f ef 33 36 02 16 28 82 00 00 06"
    ) in timer

    minutes, seconds, cycles = 1, 0, 1
    for advance in range(1, 1023):
        if minutes == 0 and seconds == 0:
            break
        cycles -= 1
        if cycles == -17:
            cycles = 0
            if seconds == 0:
                seconds = 59
                minutes -= 1
            else:
                seconds -= 1
    assert advance == 1022
    print("Verified pinned Golems exit, fall limit and one-minute timer: Done is set on advance 1022.")


if __name__ == "__main__":
    main()
