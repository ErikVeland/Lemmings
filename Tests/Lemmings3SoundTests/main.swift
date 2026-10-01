import Foundation
import NxlvKit

func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw SequelDataError.invalid(message) }
}
let root = URL(fileURLWithPath: "Sources/Ports/LEM3CD")
let bank = try Lemmings3SoundBank(root: root)
let expected: [ClassicSoundEffect: (Int, Double)] = [
    .doorOpen: (4066, 8363), .letsGo: (6346, 7046), .assignSkill: (5112, 14037),
    .fallOut: (3954, 18741), .exitLevel: (9128, 10054), .splat: (3954, 18741), .ohNo: (5368, 10528)
]
try require(bank.clips.count == expected.count, "Missing original L3 voices")
for (effect, values) in expected {
    let clip = bank.clips[effect]!
    try require(clip.samples.count == values.0 && clip.sampleRate == values.1, "L3 voice length or recorded rate changed")
    try require(clip.samples.allSatisfy { $0.isFinite && $0 >= -1 && $0 < 1 }, "L3 voice sample range")
    try require(clip.samples.contains { abs($0) > 0.1 }, "L3 voice decoded to silence")
}
var patch = try Data(contentsOf: root.appendingPathComponent("AUDIO/GRAVIS/I_OK.PAT"))
patch[335] = 0; patch[336] = 128; patch[337] = 255
let unsigned = try Lemmings3SoundBank.Clip(patch: patch)
try require(Array(unsigned.samples.prefix(3)) == [-1, 0, 127.0 / 128], "Unsigned sample conversion")
patch[294] &= ~2
let signed = try Lemmings3SoundBank.Clip(patch: patch)
try require(Array(signed.samples.prefix(3)) == [0, -1, -1.0 / 128], "Signed sample conversion")
for mutation in 0..<7 {
    var bad = patch
    switch mutation {
    case 0: bad.removeLast()
    case 1: bad[0] = 0
    case 2: bad[198] = 2
    case 3: bad[259] = 0; bad[260] = 0
    case 4: bad[294] |= 1
    case 5: bad[294] |= 4
    default: bad[247] = 255; bad[248] = 255; bad[249] = 255; bad[250] = 255
    }
    var rejected = false
    do { _ = try Lemmings3SoundBank.Clip(patch: bad) } catch { rejected = true }
    try require(rejected, "Malformed Gravis voice was accepted")
}
let width = 128, height = 64
var tags = [UInt16](repeating: 0x1000, count: width * height)
for y in 48..<height { for x in 0..<width { tags[y * width + x] = 0x20 } }
var game = try Lemmings3Runtime(configuration: .init(width: width, height: height, attributes: tags,
    entrance: .init(x: 20, y: 40), exits: [.init(x: 110, y: 46)], total: 3, releaseInterval: 1, releaseDelay: 0))
var cues: [ClassicSoundEffect] = []
for _ in 0..<250 {
    let before = Lemmings3SoundCue.Snapshot(game)
    game.step()
    cues += Lemmings3SoundCue.cues(before: before, after: .init(game))
    for cue in Lemmings3SoundCue.positionedCues(before: before, after: .init(game)) where cue.effect == .exitLevel {
        try require(cue.point != nil && abs(cue.point!.x - 110) < 20, "L3 exit voice lost its source position")
    }
}
try require(cues.filter { $0 == .letsGo }.count == 1 && cues.filter { $0 == .doorOpen }.count == 1, "Hatch voices must play once")
try require(game.saved == 3 && cues.filter { $0 == .exitLevel }.count == 3, "Rescue voices must follow new rescues")
try require(!cues.contains(.splat), "Safe run played a death voice")
let before = Lemmings3SoundCue.Snapshot(game)
try require(Lemmings3SoundCue.cues(before: before, after: before).isEmpty, "Paused/completed state repeated audio")
print("PASS six original L3 voices, declared rates, signed/unsigned PCM, malformed files and event timing")

var falling = try Lemmings3Runtime(configuration: .init(width: width, height: height,
    attributes: [UInt16](repeating: 0x1000, count: width * height),
    entrance: .init(x: 20, y: 40), exits: [.init(x: 110, y: 46)], total: 3, releaseInterval: 1, releaseDelay: 0))
var falls: [ClassicSoundEffect] = []
for _ in 0..<100 {
    let before = Lemmings3SoundCue.Snapshot(falling)
    falling.step()
    falls += Lemmings3SoundCue.cues(before: before, after: .init(falling))
    for cue in Lemmings3SoundCue.positionedCues(before: before, after: .init(falling)) where cue.effect == .fallOut {
        try require(cue.point != nil && cue.point!.y >= Double(height), "L3 bottom death lost its source position")
    }
}
try require(falling.lost == 3 && falls.contains(.fallOut) && !falls.contains(.splat), "Bottom falls must have a separate death cue")
print("PASS L3 bottom deaths are distinct from other losses")

var builder = try Lemmings3Runtime(configuration: .init(width: width, height: height, attributes: tags,
    entrance: .init(x: 20, y: 40), exits: [.init(x: 110, y: 46)], total: 1, releaseInterval: 1, releaseDelay: 0,
    pickups: [.init(id: 0, tool: .bricks, x: 20, y: 40)]))
for _ in 0..<12 { builder.step() }
try require(builder.useTool(to: 0, direction: .upRight), "Builder audio fixture did not start")
let beforeBrick = Lemmings3SoundCue.Snapshot(builder)
builder.step()
let brickSounds = Lemmings3SoundCue.positionedCues(before: beforeBrick, after: .init(builder))
try require(brickSounds.count == 1 && brickSounds[0].effect == .builderWarning
    && brickSounds[0].point == GameplaySoundPoint(x: Double(builder.lemmings[0].x), y: Double(builder.lemmings[0].y)),
    "Placed brick did not produce a positioned chink")
try require(Lemmings3SoundCue.positionedCues(before: .init(builder), after: .init(builder)).isEmpty,
    "Paused builder repeated its chink")
print("PASS L3 positioned exit, death and brick cues, with no paused duplicates")
