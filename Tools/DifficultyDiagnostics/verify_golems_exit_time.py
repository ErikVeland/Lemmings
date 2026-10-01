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
    "GameState.InitializeReleasePoints": (0x5CF0, "20799b18e66404d2b0be873ea841d3a77f4bb9e0cb024f282bd71f29d8291c08"),
    "GameState.AdvanceRelease": (0x68B8, "3d065401840b15707ed5ee749c48b16e3708af38da7f27b8df17913d6f1b3e0a"),
    "GameState.GetEffect": (0x8328, "4c7a87c935396cae905b3f43d462d3c6b6086133dddc80c4077f980b1e12dccb"),
    "LevelRenderer.RenderGadgetEffect": (0x9E10, "6344d09146b8e3434b249accca0c4d7e0b08dcb721e0c5b62018645674f3c43e"),
    "Golem.get_Activities": (0x184A6, "620eda81b82e7ecb84197f360c07908711584901343357f014fbd5540babcadb"),
    "Golem.set_Activity": (0x184C0, "96f3e1bdba78115027b5d542fa6c9aff03d02b152e4e33c66d713ffe033febed"),
    "GameState.CanAcceptBuilder": (0x8B4E, "40f3d13356df2173fa6d30668154c120664a118cc6bdaf08c9f7d4fc468649d8"),
    "GameState.CanAcceptBasher": (0x8B69, "b0ed1123af57f680b88dd2dfc147c514b0a16f9a7c45db9f1d58c9aad80aa200"),
    "GameState.TryGetActionArguments": (0x59B4, "78970ce1c1ae20b2980d022f6cd048beac0b9b7385c8ddf9aa7694a213bf804c"),
    "GameState.TryAdvance": (0x5A3B, "5667dd39aeb600ede7f51e3efabbe414fe622dc29afef88aaef56f642af73ef2"),
    "GameState.TryPerformAction": (0x5E68, "a90c66132fea3babb97b8fd40fd831008726650ee0551768c980e550babf2848"),
    "GameState.GetAssignBuildSkillGolemIndex": (0x6474, "05dde6ca851a433411de33faa7ceffc4bb561438f89bd827d0e1b7dd32495d28"),
    "GameState.AssignBuildSkill": (0x64F4, "0abbe345c92bbc6b3777891f1c7fb15962d83e5433d5c3904315fde50b86d3d8"),
    "ReplayableGameState.AdvanceCore": (0xC4B0, "0907c120a0653b0b4d6457569b87e70ce29fb47ecbafe752c5cce46a1199a568"),
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

    effect = bodies["GameState.GetEffect"]
    # Golems looks up a 4-pixel effect cell: x >> 2 and
    # 1 + ((YPlus16 - 16) >> 2). It does not test a pixel rectangle.
    assert effect.startswith(bytes.fromhex(
        "03 7b 17 03 00 04 04 58 18 63 0a "
        "17 03 7b 18 03 00 04 1f 10 59 05 58 18 63 58 0b"
    ))
    assert bytes.fromhex("07 20 a0 01 00 00 5a 06 58 a3 03 00 00 02") in effect
    release_points = bodies["GameState.InitializeReleasePoints"]
    release = bodies["GameState.AdvanceRelease"]
    # A hatch stores YPlus16 as placement y + 16 + 14, then copies it
    # unchanged into the released lemming. Native hatch foot is y + 14.
    assert bytes.fromhex("08 7b 6b 01 00 04 1f 10 58 1f 0e 58") in release_points
    assert bytes.fromhex("06 7b 16 03 00 04 7d 18 03 00 04") in release
    rendered_effect = bodies["LevelRenderer.RenderGadgetEffect"]
    # The renderer places gadget effect cells using quantised gadget x/y.
    assert bytes.fromhex("28 35 02 00 06 18 63") in rendered_effect
    assert bytes.fromhex("28 36 02 00 06 18 63") in rendered_effect

    # GolemActivity.Falling is enum value 3 in this pinned assembly. The setter
    # stores non-special activities as 1 << (activity - 1). The Builder guard
    # rejects a lemming whose activities intersect 0x7aef, including bit 2.
    assert bodies["Golem.get_Activities"] == bytes.fromhex("02 7b 1b 03 00 04 2a")
    assert bytes.fromhex("02 17 03 17 59 1f 1f 5f 62 d1 7d 1b 03 00 04") in bodies[
        "Golem.set_Activity"]
    assert bodies["GameState.CanAcceptBuilder"] == bytes.fromhex(
        "02 28 62 03 00 06 2d 10 02 28 61 03 00 06 "
        "20 ef 7a 00 00 5f 16 fe 01 2a 16 2a")
    assert bodies["GameState.CanAcceptBasher"] == bytes.fromhex(
        "02 28 62 03 00 06 2d 10 02 28 61 03 00 06 "
        "20 6f 7b 00 00 5f 16 fe 01 2a 16 2a")
    assert 0x7AEF & (1 << (3 - 1)) and 0x7B6F & (1 << (3 - 1))

    # Replay actions use TryAdvance -> TryPerformAction -> AssignBuildSkill.
    # The interactive target selector applies CanAcceptBuilder, but this replay
    # path does not call that selector or its activity predicate.
    assert bytes.fromhex("6f ae 00 00 06") in bodies["ReplayableGameState.AdvanceCore"]
    assert bytes.fromhex("28 b5 00 00 06") in bodies["GameState.TryAdvance"]
    action = bodies["GameState.TryPerformAction"]
    assert bytes.fromhex("28 ac 00 00 06") in action
    assert bytes.fromhex("28 c0 00 00 06") in action
    assert bytes.fromhex("28 bf 00 00 06") not in action
    assert bytes.fromhex("28 02 01 00 06") in bodies["GameState.GetAssignBuildSkillGolemIndex"]
    assert bytes.fromhex("28 02 01 00 06") not in bodies["GameState.AssignBuildSkill"]

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
    print("Verified pinned Golems interactive fall guards, replay assignment path, effect-cell lookup, exit, fall limit and one-minute timer: Done is set on advance 1022.")


if __name__ == "__main__":
    main()
