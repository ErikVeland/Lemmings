import Foundation
import NxlvKit

// A saved run must survive any later build. These checks save Classic runs
// the way earlier builds did and restore them with the current engine.
// Usage: CrossBuildRecoveryTests OH_NO_DATA_DIRECTORY

struct Failure: Error, CustomStringConvertible { let description: String }
func require(_ condition: Bool, _ message: String) throws { if !condition { throw Failure(description: message) } }

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
let set = try ClassicDataSet.detect(directory: directory)
let assets = try ClassicMainDATAssets.load(from: directory)

func session(level index: Int, mechanics: ClassicDOSMechanics) throws -> ClassicSession {
    let level = set.campaign.levels[index].level
    let rendered = try ClassicLevelRenderer.render(level, groundSet: ClassicGroundSet.load(style: level.groundStyle, from: directory),
        specialGraphic: level.specialStyle == 0 ? nil : ClassicSpecialGraphic.load(index: level.specialStyle - 1, from: directory))
    let simulation = try ClassicDOSSimulation(level: level, renderedLevel: rendered, mainDATAssets: assets, mechanics: mechanics)
    return ClassicSession(simulation: simulation, width: rendered.width, height: rendered.height)
}

/// Plays a short run with one skill, then returns its checkpoint as an older build wrote it.
func savedRun(_ played: ClassicSession, snapshot: Bool) throws -> RunRecovery {
    var assigned = false
    while played.currentTick < 400 {
        played.tick()
        if !assigned, let lemming = played.simulation.lemmings.first(where: { $0.isActive && $0.action == .walking }) {
            assigned = played.assign(skillIndex: ClassicSkill.allCases.firstIndex(of: .bomber)!, to: lemming.id) == nil
        }
    }
    try require(assigned, "test run could not assign a skill")
    var recovery = RunRecovery(engine: "an earlier engine", profileID: "player", runID: UUID(), dataSetID: set.identifierKey,
        levelIndex: 0, levelFingerprint: "an earlier fingerprint", initialStateHash: played.initialStateHash,
        tick: played.currentTick, events: played.recoveryEvents,
        stateHash: ClassicDOSReplayRecorder.stateHash(of: played.simulation), usedRewind: false,
        nukeCount: 0, rewindCount: 0, undoCount: 0, selectedSkill: 0, scrollX: 0, scrollY: 0)
    if snapshot { recovery.classicState = played.simulation }
    return recovery
}

// 1. A run saved under the original rules, before Oh No! had its own rules,
// continues under those rules in this build. Havoc 20 is level 100.
let before = try session(level: 99, mechanics: .original)
let old = try savedRun(before, snapshot: false)
let resumed = try session(level: 99, mechanics: .ohNoMore)
try resumed.restore(old)
try require(ClassicDOSReplayRecorder.stateHash(of: resumed.simulation) == old.stateHash, "old-rule run restored to a different state")
for _ in 0..<300 { before.tick(); resumed.tick() }
try require(ClassicDOSReplayRecorder.stateHash(of: resumed.simulation) == ClassicDOSReplayRecorder.stateHash(of: before.simulation),
    "old-rule run diverged after restore")
try require(resumed.initialStateHash == before.initialStateHash, "restored run would save with the wrong starting rules")

// 2. A run that this build cannot replay continues from its saved state.
var unreplayable = try savedRun(try session(level: 99, mechanics: .ohNoMore), snapshot: true)
unreplayable = RunRecovery(engine: unreplayable.engine, profileID: "player", runID: unreplayable.runID,
    dataSetID: unreplayable.dataSetID, levelIndex: 0, levelFingerprint: "x", initialStateHash: "a start this build never makes",
    tick: unreplayable.tick, events: unreplayable.events, stateHash: unreplayable.stateHash, usedRewind: false,
    nukeCount: 0, rewindCount: 0, undoCount: 0, selectedSkill: 0, scrollX: 0, scrollY: 0)
unreplayable.classicState = try savedRun(try session(level: 99, mechanics: .ohNoMore), snapshot: true).classicState
let fromState = try session(level: 99, mechanics: .ohNoMore)
try fromState.restore(unreplayable)
try require(ClassicDOSReplayRecorder.stateHash(of: fromState.simulation) == unreplayable.stateHash, "saved state was not restored")
try require(fromState.usedRewind, "a run restored from its saved state must count as assisted")
try require(!resumed.usedRewind, "a replayed old-rule run must keep its unassisted status")

// 3. The saved state still survives a JSON round trip, as the file store writes it.
let decoded = try JSONDecoder().decode(RunRecovery.self, from: JSONEncoder().encode(unreplayable))
let fromFile = try session(level: 99, mechanics: .ohNoMore)
try fromFile.restore(decoded)
try require(ClassicDOSReplayRecorder.stateHash(of: fromFile.simulation) == unreplayable.stateHash, "saved state did not survive encoding")

// 4. Nothing to restore from: a different level with no saved state is refused.
var foreign = try savedRun(try session(level: 0, mechanics: .ohNoMore), snapshot: false)
foreign.classicState = nil
do {
    try session(level: 99, mechanics: .ohNoMore).restore(foreign)
    throw Failure(description: "a run from another level was accepted")
} catch RunRecoveryError.differentGame {}

func neoSession(changedTerrain: Bool = false) throws -> NeoLemmixSession {
    var terrain = try NeoLemmixTerrain(width: 96, height: 64)
    for x in 0..<96 { _ = terrain.setSolid(true, x: x, y: 48) }
    if changedTerrain { _ = terrain.setSolid(true, x: 40, y: 47) }
    let configuration = try NeoLemmixConfiguration(
        totalLemmings: 1,
        requiredToSave: 1,
        spawnInterval: 12,
        entrances: [],
        preplacedLemmings: [
            NeoLemmixPreplacedLemming(
                position: NeoLemmixPoint(x: 20, y: 48),
                direction: .right
            ),
        ],
        skills: [.builder: .finite(2), .jumper: .finite(2)]
    )
    return NeoLemmixSession(
        simulation: try NeoLemmixSimulation(terrain: terrain, configuration: configuration),
        width: terrain.width,
        height: terrain.height
    )
}

func neoCheckpoint(_ played: NeoLemmixSession) -> RunRecovery {
    var checkpoint = RunRecovery(
        engine: "an earlier NeoLemmix engine",
        profileID: "player",
        runID: UUID(),
        dataSetID: "neolemmix",
        levelIndex: 0,
        levelFingerprint: "fixture-level",
        initialStateHash: "verified-by-state-equality",
        tick: played.currentTick,
        events: [],
        stateHash: "verified-by-state-equality",
        usedRewind: false,
        nukeCount: 0,
        rewindCount: 0,
        undoCount: 0,
        selectedSkill: 0,
        scrollX: 0,
        scrollY: 0
    )
    checkpoint.neo = played.recovery
    checkpoint.sourcePath = "/fixture.nxlv"
    return checkpoint
}

// 5. NeoLemmix input replay restores exactly and continues deterministically.
let neoBefore = try neoSession()
guard let builder = neoBefore.skills.firstIndex(where: { $0.name == "Builder" }) else {
    throw Failure(description: "NeoLemmix recovery fixture has no Builder")
}
try require(neoBefore.assign(skillIndex: builder, to: 0) == nil, "NeoLemmix recovery assignment failed")
for _ in 0..<24 { neoBefore.tick() }
neoBefore.adjustRate(by: -2)
for _ in 0..<8 { neoBefore.tick() }
let neoSaved = neoCheckpoint(neoBefore)
let neoResumed = try neoSession()
try neoResumed.restore(neoSaved)
try require(neoResumed.simulation == neoBefore.simulation, "NeoLemmix replay restore changed state")
for _ in 0..<80 { neoBefore.tick(); neoResumed.tick() }
try require(neoResumed.simulation == neoBefore.simulation, "NeoLemmix replay restore diverged")
try require(!neoResumed.usedRewind, "Exact NeoLemmix replay restore became assisted")

// 6. A later build may use the retained state only when the source content is unchanged.
var fallback = neoSaved
var driftedInitial = fallback.neo!.initialState
_ = driftedInitial.enqueue(.nuke)
fallback.neo = NeoRunRecovery(
    initialState: driftedInitial,
    state: fallback.neo!.state,
    inputs: fallback.neo!.inputs
)
let neoFromState = try neoSession()
try neoFromState.restore(try JSONDecoder().decode(
    RunRecovery.self,
    from: JSONEncoder().encode(fallback)
))
try require(neoFromState.simulation == fallback.neo!.state, "NeoLemmix saved-state fallback changed state")
try require(neoFromState.usedRewind, "NeoLemmix saved-state fallback was not marked assisted")
do {
    try neoSession(changedTerrain: true).restore(fallback)
    throw Failure(description: "NeoLemmix recovery accepted changed level content")
} catch RunRecoveryError.differentGame {}

// 7. A saved L3 attempt keeps the old Hadoken rule after the pickup was changed
// from one use to eight. Rewind must replay from that same old initial state.
func l3Initial(hadokenQuantity: Int, changedTerrain: Bool = false) throws -> Lemmings3Runtime {
    let width = 64, height = 64
    var attributes = Array(repeating: UInt16(0x1000), count: width * height)
    for x in 0..<width { attributes[48 * width + x] = 0x2020 }
    if changedTerrain { attributes[40 * width + 40] = 0x2020 }
    return try Lemmings3Runtime(configuration: .init(
        width: width, height: height, attributes: attributes,
        entrance: .init(x: 16, y: 48), exits: [.init(x: 56, y: 48)],
        total: 1, releaseInterval: 23, releaseDelay: 1, timeLimit: 100,
        pickups: [.init(id: 0, tool: .hadoken, x: 16, y: 36, quantity: hadokenQuantity)]))
}

let oldL3Initial = try l3Initial(hadokenQuantity: 1)
let currentL3Initial = try l3Initial(hadokenQuantity: 8)
var oldL3Game = oldL3Initial
oldL3Game.step(); oldL3Game.step()
try require(oldL3Game.lemmings.first?.tool == .hadoken && oldL3Game.lemmings.first?.quantity == 1,
    "old L3 fixture did not collect the one-use Hadoken")
let oldL3Input = L3RunRecovery.Input(tick: oldL3Game.tick, action: "use", lemming: 0, direction: "right")
try require(L3RunRecovery.apply(oldL3Input, to: &oldL3Game), "old L3 fixture could not use the Hadoken")
for _ in 0..<5 { oldL3Game.step() }
try require(!oldL3Game.isComplete, "old L3 fixture completed before its checkpoint")
let l3Journal = L3RunRecovery(progress: .init(index: 0, population: 1, completed: [:], tribe: .classic),
    inputs: [oldL3Input], skillAssignments: [:], toolUses: [:])
func l3Checkpoint(initialHash: String, stateHash: String, tick: Int) -> RunRecovery {
    var checkpoint = RunRecovery(engine: "an earlier L3 engine", profileID: "player", runID: UUID(),
        dataSetID: "lemmings3", levelIndex: 0, levelFingerprint: "fixture-level",
        initialStateHash: initialHash, tick: tick, events: [], stateHash: stateHash,
        usedRewind: false, nukeCount: 0, rewindCount: 0, undoCount: 0, selectedSkill: 0,
        scrollX: 0, scrollY: 0)
    checkpoint.sourcePath = "/fixture/LEM3CD"
    checkpoint.l3 = l3Journal
    return checkpoint
}
let oldL3Checkpoint = l3Checkpoint(initialHash: L3RunRecovery.stateHash(oldL3Initial),
    stateHash: L3RunRecovery.stateHash(oldL3Game), tick: oldL3Game.tick)
let resumedL3 = try l3Journal.restore(initial: currentL3Initial, checkpoint: oldL3Checkpoint)
try require(L3RunRecovery.stateHash(resumedL3.initial) == oldL3Checkpoint.initialStateHash,
    "old L3 run lost its starting rules for rewind and later saves")
try require(L3RunRecovery.stateHash(resumedL3.game) == oldL3Checkpoint.stateHash,
    "old L3 run restored to a different state")
let currentL3Game = try L3RunRecovery.replay(initial: currentL3Initial,
    inputs: [oldL3Input], through: oldL3Game.tick)
let currentL3Checkpoint = l3Checkpoint(initialHash: L3RunRecovery.stateHash(currentL3Initial),
    stateHash: L3RunRecovery.stateHash(currentL3Game), tick: currentL3Game.tick)
let currentL3Restored = try l3Journal.restore(initial: currentL3Initial, checkpoint: currentL3Checkpoint)
try require(L3RunRecovery.stateHash(currentL3Restored.initial) == currentL3Checkpoint.initialStateHash &&
    L3RunRecovery.stateHash(currentL3Restored.game) == currentL3Checkpoint.stateHash,
    "current-rule L3 checkpoint did not restore exactly")
let rewoundL3 = try L3RunRecovery.replay(initial: resumedL3.initial, inputs: [], through: 1)
try require(rewoundL3.lemmings.first?.quantity == 1, "old L3 run rewound with the eight-use Hadoken")
var oldL3Continued = oldL3Game, resumedL3Continued = resumedL3.game
for _ in 0..<15 { oldL3Continued.step(); resumedL3Continued.step() }
try require(L3RunRecovery.stateHash(oldL3Continued) == L3RunRecovery.stateHash(resumedL3Continued),
    "old L3 run diverged after restore")
do {
    _ = try l3Journal.restore(initial: try l3Initial(hadokenQuantity: 8, changedTerrain: true),
        checkpoint: oldL3Checkpoint)
    throw Failure(description: "L3 recovery accepted changed terrain")
} catch RunRecoveryError.differentGame {}
do {
    _ = try l3Journal.restore(initial: currentL3Initial,
        checkpoint: l3Checkpoint(initialHash: oldL3Checkpoint.initialStateHash,
            stateHash: "wrong saved state", tick: oldL3Game.tick))
    throw Failure(description: "L3 recovery accepted a mismatched saved state")
} catch RunRecoveryError.invalid {}

print("PASS cross-build recovery: Classic, NeoLemmix and L3 legacy replay, continuation, and changed-content refusal")
