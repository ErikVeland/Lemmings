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
try require(brickSounds.count == 1 && brickSounds[0].effect == .brickPlace
    && brickSounds[0].point == GameplaySoundPoint(x: Double(builder.lemmings[0].x), y: Double(builder.lemmings[0].y)),
    "Placed brick did not produce a positioned chink")
try require(Lemmings3SoundCue.positionedCues(before: .init(builder), after: .init(builder)).isEmpty,
    "Paused builder repeated its chink")
print("PASS L3 positioned exit, death and brick cues, with no paused duplicates")

func collectSteps(_ game: inout Lemmings3Runtime, count: Int) -> [PositionedSoundCue] {
    var result: [PositionedSoundCue] = []
    for _ in 0..<count {
        let before = Lemmings3SoundCue.Snapshot(game)
        game.step()
        result += Lemmings3SoundCue.positionedCues(before: before, after: .init(game))
    }
    return result
}

let effectWidth = 256, effectHeight = 96
var effectTags = [UInt16](repeating: 0x1000, count: effectWidth * effectHeight)
for y in 48..<effectHeight { for x in 0..<effectWidth { effectTags[y * effectWidth + x] = 0x20 } }
@MainActor func effectFixture(tool: Lemmings3Runtime.Tool, background: [UInt16]? = nil) throws -> Lemmings3Runtime {
    try .init(configuration: .init(width: effectWidth, height: effectHeight, attributes: effectTags,
        entrance: .init(x: 20, y: 40), exits: [.init(x: 235, y: 47)], total: 1,
        releaseInterval: 1, releaseDelay: 0, pickups: [.init(id: 0, tool: tool, x: 20, y: 40)],
        backgroundAttributes: background))
}
var collecting = try Lemmings3Runtime(configuration: .init(width: effectWidth, height: effectHeight,
    attributes: effectTags, entrance: .init(x: 20, y: 40), exits: [.init(x: 235, y: 47)], total: 1,
    releaseInterval: 1, releaseDelay: 0,
    pickups: [.init(id: 0, tool: .bricks, x: 20, y: 40), .init(id: 1, tool: .clock, x: 20, y: 40)]))
let pickupSounds = collectSteps(&collecting, count: 12)
try require(pickupSounds.filter { $0.effect == .toolPickup }.count == 1
    && pickupSounds.filter { $0.effect == .clockPickup }.count == 1 && collecting.bonusSeconds == 60,
    "Tool and clock pickups must each sound at collection without changing their reward")
let restoredPickupState = Lemmings3SoundCue.Snapshot(collecting)
try require(Lemmings3SoundCue.positionedCues(before: restoredPickupState, after: restoredPickupState).isEmpty,
    "Restored pickup state replayed old presentation events")
try require(!collectSteps(&collecting, count: 5).contains { [.toolPickup, .clockPickup].contains($0.effect) },
    "Collected items repeated their sound")

for tool in [Lemmings3Runtime.Tool.bomb, .grenade, .hadoken] {
    var launching = try effectFixture(tool: tool)
    _ = collectSteps(&launching, count: 12)
    let beforeLaunch = Lemmings3SoundCue.Snapshot(launching)
    try require(launching.useTool(to: 0, direction: .right), "Projectile sound fixture rejected its tool")
    let launch = Lemmings3SoundCue.positionedCues(before: beforeLaunch, after: .init(launching))
    try require(launch.filter { $0.effect == .projectileLaunch }.count == 1 && launch.first?.point != nil,
        "Accepted projectile use must sound immediately at its source")
    if tool != .hadoken {
        try require(launching.assign(.blocker, to: 0), "Blast fixture could not hold its carrier")
        let detonation = collectSteps(&launching, count: 200)
        try require(detonation.filter { $0.effect == .explode }.count == 1
            && !detonation.contains { $0.effect == .projectileLaunch },
            "Detonation must sound once and must not repeat the launch")
        try require(!detonation.contains { $0.effect == .splat },
            "A blast-acknowledged death played a second death voice")
    }
}

var verticalBuilder = try effectFixture(tool: .bricks)
_ = collectSteps(&verticalBuilder, count: 12)
try require(verticalBuilder.useTool(to: 0, direction: .up), "Final-brick sound fixture rejected building")
let construction = collectSteps(&verticalBuilder, count: 140)
try require(construction.filter { $0.effect == .builderWarning }.count == 3
    && construction.filter { $0.effect == .brickPlace }.count == 5,
    "Construction must reserve urgent warnings for the final three bricks")

var steelBackground = [UInt16](repeating: 0x1000, count: effectWidth * effectHeight)
for y in 32..<48 { for x in 20..<100 { steelBackground[y * effectWidth + x] = 0x20 } }
var steelWorker = try effectFixture(tool: .spade, background: steelBackground)
_ = collectSteps(&steelWorker, count: 12)
try require(steelWorker.useTool(to: 0, direction: .right), "Steel sound fixture rejected its spade")
let steelContact = collectSteps(&steelWorker, count: 8)
try require(steelContact.filter { $0.effect == .hitSteel }.count == 1
    && steelWorker.lemmings[0].quantity == Lemmings3Runtime.Tool.spade.initialQuantity,
    "Steel contact must sound once without consuming a tool")

var waterTags = effectTags
for y in 0..<48 { for x in 0..<effectWidth { waterTags[y * effectWidth + x] |= 0x800 } }
for swimmer in [false, true] {
    var water = try Lemmings3Runtime(configuration: .init(width: effectWidth, height: effectHeight,
        attributes: waterTags, entrance: .init(x: 20, y: 40), exits: [.init(x: 235, y: 47)], total: 1,
        releaseInterval: 1, releaseDelay: 0,
        pickups: swimmer ? [.init(id: 0, tool: .swimmer, x: 20, y: 39)] : []))
    let waterSounds = collectSteps(&water, count: swimmer ? 30 : 100)
    try require(waterSounds.filter { $0.effect == (swimmer ? .waterEntry : .drown) }.count == 1,
        "Water contact must distinguish swimming from drowning")
    try require(!waterSounds.contains { $0.effect == .splat || (swimmer && $0.effect == .drown) },
        "Water feedback added a late death voice or reported a living swimmer as drowning")
}

var trapTags = effectTags
trapTags[39 * effectWidth + 20] |= 0x4000
var trapping = try Lemmings3Runtime(configuration: .init(width: effectWidth, height: effectHeight,
    attributes: trapTags, entrance: .init(x: 20, y: 40), exits: [.init(x: 235, y: 47)], total: 1,
    releaseInterval: 1, releaseDelay: 0,
    traps: [.init(id: 0, cells: [.init(x: 20, y: 39)], frameCount: 4, frameDelay: 1)]))
let trapSounds = collectSteps(&trapping, count: 20)
try require(trapping.lost == 1 && trapSounds.filter { $0.effect == .trapTrigger }.count == 1
    && !trapSounds.contains { $0.effect == .splat },
    "Trap sound must land on capture and must not repeat at final removal")

var arrivals = try Lemmings3Runtime(configuration: .init(width: effectWidth, height: effectHeight,
    attributes: effectTags, entrance: .init(x: 20, y: 40), exits: [.init(x: 100, y: 47)], total: 1,
    releaseInterval: 1, releaseDelay: 0,
    extras: (0..<3).map { _ in .init(x: 100, y: 48, direction: 1) }))
var largestRescueBatch = 0
for _ in 0..<20 {
    let before = Lemmings3SoundCue.Snapshot(arrivals)
    arrivals.step()
    largestRescueBatch = max(largestRescueBatch,
        Lemmings3SoundCue.cues(before: before, after: .init(arrivals)).filter { $0 == .exitLevel }.count)
}
try require(arrivals.saved == 3 && largestRescueBatch == 3, "Simultaneous L3 rescues lost individual voices")
print("PASS causal L3 pickup, clock, launch, blast, brick warning, steel, water, trap and individual rescue sounds")
