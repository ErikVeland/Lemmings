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

print("PASS cross-build recovery: old-rule replay, saved-state fallback, encoded state, foreign-level refusal")
