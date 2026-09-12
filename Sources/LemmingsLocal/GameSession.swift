import AppKit
import NxlvKit

/// One lemming, reduced to what the views need to draw it.
struct SessionLemming {
  let id: Int
  let x: Int
  let y: Int
  let pose: ClassicLemmingPose
  let facingLeft: Bool
  let animationFrame: Int
  let countdown: Int?
}

struct SessionSkill {
  let name: String
  let count: Int
  /// A supply that never runs out, which NeoLemmix levels may declare.
  let isInfinite: Bool
}

enum AssignmentState { case eligible, alreadyAssigned, unavailable }

/// The behavior the app needs from either ruleset.
///
/// The DOS and NeoLemmix engines share no types, so this is the seam that lets
/// one playfield, panel and run loop drive both.
protocol GameSession: AnyObject {
  var levelWidth: Int { get }
  var levelHeight: Int { get }
  var ticksPerSecond: Int { get }

  var lemmings: [SessionLemming] { get }
  var entranceX: Int? { get }
  var exitX: Int? { get }
  var entranceY: Int? { get }
  var exitY: Int? { get }

  var released: Int { get }
  var total: Int { get }
  var saved: Int { get }
  var required: Int { get }
  var rate: Int { get }
  var rateLabel: String { get }
  var remainingSeconds: Int? { get }
  var isComplete: Bool { get }
  var didWin: Bool { get }
  var isNuking: Bool { get }

  var skills: [SessionSkill] { get }
  var skillAssignments: [String: Int] { get }
  var usedRewind: Bool { get }
  var nukeCount: Int { get }
  var rewindCount: Int { get }
  var undoCount: Int { get }

  func tick()
  /// Sounds the last tick asked for. Empty when nothing happened.
  var lastCues: [ClassicSoundEffect] { get }
  /// Returns nil when the assignment lands, or a reason when it does not.
  func assign(skillIndex: Int, to lemmingID: Int) -> String?
  func assignmentState(skillIndex: Int, to lemmingID: Int) -> AssignmentState
  func adjustRate(by delta: Int)
  func nuke()
  var canUndoNuke: Bool { get }
  func undoNuke()

  /// Rewind needs a deterministic engine. Not every ruleset has one yet.
  var supportsRewind: Bool { get }
  var currentTick: Int { get }
  @discardableResult func rewind(seconds: Double) -> Bool
  @discardableResult func stepBackward() -> Bool
  @discardableResult func stepForward() -> Bool
}

extension GameSession {
  func canAssign(skillIndex: Int, to lemmingID: Int) -> Bool {
    assignmentState(skillIndex: skillIndex, to: lemmingID) == .eligible
  }
  func isPerforming(skill: String, lemmingID: Int) -> Bool {
    guard let lemming = lemmings.first(where: { $0.id == lemmingID }) else { return false }
    if skill == "bomber" { return lemming.countdown != nil }
    let poses: [String: ClassicLemmingPose] = ["blocker": .blocking, "builder": .building,
      "basher": .bashing, "miner": .mining, "digger": .digging]
    return poses[skill] == lemming.pose
  }
  var exitX: Int? { nil }
  var entranceY: Int? { nil }
  var exitY: Int? { nil }
  var skillAssignments: [String: Int] { [:] }
  var usedRewind: Bool { false }
  var nukeCount: Int { 0 }
  var rewindCount: Int { 0 }
  var undoCount: Int { 0 }
}

// MARK: - Classic DOS

final class ClassicSession: GameSession {
  /// Wraps the engine so any earlier tick can be reached exactly.
  let initialStateHash: String
  let initialSimulation: ClassicDOSSimulation
  private var history: ClassicDOSRewind
  private var beforeNuke: ClassicDOSRewind?
  private(set) var usedRewind = false
  private(set) var nukeCount = 0
  private(set) var rewindCount = 0
  private(set) var undoCount = 0
  var skillAssignments: [String: Int] {
    var result: [String: Int] = [:]
    for skill in ClassicSkill.allCases {
      let used = (simulation.configuration.initialSkills[skill] ?? 0) - simulation.remainingSkillCount(skill)
      if used > 0 { result[skill.rawValue] = used }
    }
    return result
  }
  var simulation: ClassicDOSSimulation { history.simulation }
  let levelWidth: Int
  let levelHeight: Int

  init(simulation: ClassicDOSSimulation, width: Int, height: Int) {
    initialSimulation = simulation
    initialStateHash = ClassicDOSReplayRecorder.stateHash(of: simulation)
    history = ClassicDOSRewind(simulation: simulation)
    levelWidth = width
    levelHeight = height
  }

  var recoveryEvents: [ClassicDOSReplayEvent] {
    history.commands.map { ClassicDOSReplayEvent(tick: $0.tick, action: $0.action, afterTick: true) }
  }

  /// Rebuild from valid level data and reject any input or final-state mismatch.
  func restore(_ recovery: RunRecovery) throws {
    _ = try recovery.validated()
    guard currentTick == 0, recovery.initialStateHash == initialStateHash else { throw RunRecoveryError.differentGame }
    let restored = ClassicSession(simulation: simulation, width: levelWidth, height: levelHeight)
    func advance(to tick: Int) throws {
      while restored.currentTick < tick && !restored.isComplete { restored.tick() }
      guard restored.currentTick == tick else { throw RunRecoveryError.invalid }
    }
    for event in recovery.events {
      try advance(to: event.tick)
      guard !restored.isComplete else { throw RunRecoveryError.invalid }
      switch event.action {
      case let .assign(id, skill):
        guard let index = ClassicSkill.allCases.firstIndex(of: skill),
          restored.assign(skillIndex: index, to: id) == nil else { throw RunRecoveryError.invalid }
      case let .releaseRate(value):
        restored.history.setReleaseRate(value)
        guard restored.rate == value else { throw RunRecoveryError.invalid }
      case .nuke:
        guard !restored.isNuking else { throw RunRecoveryError.invalid }
        restored.nuke()
      }
    }
    if restored.currentTick > recovery.tick {
      guard restored.history.seek(toTick: recovery.tick) else { throw RunRecoveryError.invalid }
      if !restored.isNuking { restored.beforeNuke = nil }
    } else { try advance(to: recovery.tick) }
    guard !restored.isComplete, ClassicDOSReplayRecorder.stateHash(of: restored.simulation) == recovery.stateHash else {
      throw RunRecoveryError.invalid
    }
    history = restored.history; beforeNuke = restored.beforeNuke
    usedRewind = recovery.usedRewind; nukeCount = recovery.nukeCount
    rewindCount = recovery.rewindCount; undoCount = recovery.undoCount
    lastCues = []
  }

  var supportsRewind: Bool { true }
  var currentTick: Int { history.currentTick }

  @discardableResult func rewind(seconds: Double) -> Bool {
    let moved = history.rewind(seconds: seconds)
    if moved { usedRewind = true; rewindCount += 1; lastCues = []; if !simulation.isNuking { beforeNuke = nil } }
    return moved
  }

  @discardableResult func stepBackward() -> Bool {
    let moved = history.stepBackward()
    if moved { usedRewind = true; rewindCount += 1; lastCues = []; if !simulation.isNuking { beforeNuke = nil } }
    return moved
  }

  @discardableResult func stepForward() -> Bool {
    guard !history.simulation.isComplete else { return false }
    tick()
    return true
  }

  var ticksPerSecond: Int { ClassicDOSRules.ticksPerSecond }

  var lemmings: [SessionLemming] {
    simulation.lemmings.filter(\.isActive).map {
      SessionLemming(
        id: $0.id, x: $0.foot.x, y: $0.foot.y,
        pose: spritePose(for: $0.action),
        facingLeft: $0.direction == .left,
        animationFrame: $0.animationFrame,
        countdown: $0.bomberCountdown)
    }
  }

  var entranceX: Int? { simulation.configuration.entrances.first?.x }
  var entranceY: Int? { simulation.configuration.entrances.first?.y }
  var exitY: Int? {
    simulation.configuration.triggers.first { $0.effect == .exit }.map { ($0.bounds.y1 + $0.bounds.y2) / 2 }
  }
  var exitX: Int? {
    simulation.configuration.triggers.first { $0.effect == .exit }.map { ($0.bounds.x1 + $0.bounds.x2) / 2 }
  }
  var released: Int { simulation.releasedCount }
  var total: Int { simulation.configuration.totalLemmings }
  var saved: Int { simulation.savedCount }
  var required: Int { simulation.configuration.requiredToSave }
  var rate: Int { simulation.releaseRate }
  var rateLabel: String { "Rate" }
  var remainingSeconds: Int? { simulation.remainingTimeSeconds }
  var isComplete: Bool { simulation.isComplete }
  var didWin: Bool { simulation.didWin }
  var isNuking: Bool { simulation.isNuking }

  var skills: [SessionSkill] {
    ClassicSkill.allCases.map {
      SessionSkill(
        name: $0.rawValue.capitalized,
        count: simulation.remainingSkillCount($0),
        isInfinite: false)
    }
  }

  private(set) var lastCues: [ClassicSoundEffect] = []

  func tick() { lastCues = ClassicSoundCue.cues(for: history.tick()) }

  /// Probe a value copy so targeting follows the engine without changing the run.
  func assignmentState(skillIndex: Int, to lemmingID: Int) -> AssignmentState {
    guard ClassicSkill.allCases.indices.contains(skillIndex) else { return .unavailable }
    let skill = ClassicSkill.allCases[skillIndex]
    var probe = simulation
    let result = probe.assign(skill, to: lemmingID)
    if result == .assigned { return .eligible }
    if let lemming = simulation.lemmings.first(where: { $0.id == lemmingID && $0.isActive }),
       (skill == .climber && lemming.hasClimber) || (skill == .floater && lemming.hasFloater) { return .alreadyAssigned }
    if result == .alreadyHasSkill || (result == .invalidAction && isPerforming(skill: skill.rawValue, lemmingID: lemmingID)) { return .alreadyAssigned }
    return .unavailable
  }

  func assign(skillIndex: Int, to lemmingID: Int) -> String? {
    guard ClassicSkill.allCases.indices.contains(skillIndex) else { return "no such skill" }
    let result = history.assign(ClassicSkill.allCases[skillIndex], to: lemmingID)
    // An assignment happens between ticks and produces its own events. Publish
    // them here, or the click that starts a digger would make no sound: the
    // next tick overwrites `lastTickEvents` before anything reads it.
    lastCues = ClassicSoundCue.cues(for: simulation.lastTickEvents)
    return result == .assigned ? nil : result.rawValue
  }

  func adjustRate(by delta: Int) { history.setReleaseRate(simulation.releaseRate + delta) }
  var canUndoNuke: Bool { beforeNuke != nil }
  func nuke() {
    guard !simulation.isComplete, !simulation.isNuking, beforeNuke == nil else { return }
    nukeCount += 1
    beforeNuke = history
    history.beginNuke()
    lastCues = ClassicSoundCue.cues(for: simulation.lastTickEvents)
  }
  func undoNuke() {
    guard let beforeNuke else { return }
    usedRewind = true; undoCount += 1
    history = beforeNuke
    self.beforeNuke = nil
    lastCues = []
  }
}

// MARK: - NeoLemmix

/// Maps a NeoLemmix action onto the DOS sprite set.
///
/// NeoLemmix styles ship their own lemming sprites. Until those load, the
/// imported DOS sprites stand in, so actions with no DOS equivalent reuse the
/// nearest pose.
func spritePose(for action: NeoLemmixAction) -> ClassicLemmingPose {
  switch action {
  case .walking, .reaching, .shimmying, .sliding, .disarming: return .walking
  case .ascending, .jumping: return .jumping
  case .falling: return .falling
  case .climbing: return .climbing
  case .hoisting, .dehoisting: return .postClimb
  case .floating, .gliding: return .floating
  case .swimming, .drowning: return .drowning
  case .blocking: return .blocking
  case .building, .platforming, .stacking: return .building
  case .bashing: return .bashing
  case .mining: return .mining
  case .digging: return .digging
  case .shrugging: return .shrugging
  case .ohNo, .stoning: return .ohNo
  case .exploding, .stoneFinish: return .explosion
  case .splatting: return .splatting
  case .exiting: return .exiting
  case .vaporizing: return .frying
  case .removed: return .walking
  }
}

final class NeoLemmixSession: GameSession {
  private(set) var simulation: NeoLemmixSimulation
  private var beforeNuke: NeoLemmixSimulation?
  private let initialSimulation: NeoLemmixSimulation
  private var recoveryInputs: [NeoRunRecovery.Input] = []
  private var beforeNukeInputCount = 0
  private var beforeNukeSkills: [String: Int] = [:]
  private(set) var skillAssignments: [String: Int] = [:]
  private(set) var usedRewind = false
  private(set) var nukeCount = 0
  private(set) var rewindCount = 0
  private(set) var undoCount = 0
  let levelWidth: Int
  let levelHeight: Int
  private let skillOrder: [NeoLemmixSkill]

  init(simulation: NeoLemmixSimulation, width: Int, height: Int) {
    self.simulation = simulation
    initialSimulation = simulation
    levelWidth = width
    levelHeight = height
    // Show only the skills this level grants, in a stable order.
    skillOrder = NeoLemmixSkill.allCases.filter { simulation.skills[$0] != nil }
  }

  var recovery: NeoRunRecovery {
    NeoRunRecovery(initialState: initialSimulation, state: simulation, inputs: recoveryInputs)
  }

  func restore(_ checkpoint: RunRecovery) throws {
    _ = try checkpoint.validated()
    guard let saved = checkpoint.neo, currentTick == 0,
      saved.initialState == initialSimulation else { throw RunRecoveryError.differentGame }
    let restored = NeoLemmixSession(simulation: initialSimulation, width: levelWidth, height: levelHeight)
    func advance(to tick: Int) throws {
      while restored.currentTick < tick && !restored.isComplete { restored.tick() }
      guard restored.currentTick == tick else { throw RunRecoveryError.invalid }
    }
    for input in saved.inputs {
      try advance(to: input.tick)
      switch input.action {
      case let .assign(skill, lemming):
        guard restored.assign(skillIndex: skill, to: lemming) == nil else { throw RunRecoveryError.invalid }
      case let .rate(delta):
        guard (-10_000...10_000).contains(delta) else { throw RunRecoveryError.invalid }
        restored.adjustRate(by: delta)
      case .nuke:
        guard !restored.isNuking, !restored.canUndoNuke else { throw RunRecoveryError.invalid }
        restored.nuke()
      }
    }
    try advance(to: checkpoint.tick)
    guard !restored.isComplete, restored.simulation == saved.state else { throw RunRecoveryError.invalid }
    simulation = restored.simulation; recoveryInputs = restored.recoveryInputs
    beforeNuke = restored.beforeNuke; beforeNukeSkills = restored.beforeNukeSkills
    beforeNukeInputCount = restored.beforeNukeInputCount
    skillAssignments = restored.skillAssignments
    usedRewind = checkpoint.usedRewind; nukeCount = checkpoint.nukeCount
    rewindCount = checkpoint.rewindCount; undoCount = checkpoint.undoCount
  }

  var ticksPerSecond: Int { NeoLemmixRules.ticksPerSecond }

  var lemmings: [SessionLemming] {
    simulation.lemmings.filter(\.isActive).map {
      SessionLemming(
        id: $0.id, x: $0.position.x, y: $0.position.y,
        pose: spritePose(for: $0.action),
        facingLeft: $0.direction == .left,
        animationFrame: $0.animationFrame,
        countdown: $0.bomberCountdown)
    }
  }

  var entranceX: Int? { simulation.configuration.entrances.first?.position.x }
  var entranceY: Int? { simulation.configuration.entrances.first?.position.y }
  var exitY: Int? {
    simulation.configuration.zones.first { $0.effect == .exit }.map { $0.bounds.y + $0.bounds.height / 2 }
  }
  var exitX: Int? {
    simulation.configuration.zones.first { $0.effect == .exit }.map { $0.bounds.x + $0.bounds.width / 2 }
  }
  var released: Int { simulation.releasedCount }
  var total: Int { simulation.configuration.totalLemmings }
  var saved: Int { simulation.savedCount }
  var required: Int { simulation.configuration.requiredToSave }
  var rate: Int { simulation.spawnInterval }
  var rateLabel: String { "Interval" }
  var remainingSeconds: Int? {
    simulation.remainingTimeTicks.map {
      ($0 + NeoLemmixRules.ticksPerSecond - 1) / NeoLemmixRules.ticksPerSecond
    }
  }
  var isComplete: Bool { simulation.isComplete }
  var didWin: Bool { simulation.didWin }
  var isNuking: Bool { simulation.isNuking }

  var skills: [SessionSkill] {
    skillOrder.map { skill in
      switch simulation.skills[skill] {
      case let .finite(count):
        return SessionSkill(name: skill.rawValue.capitalized, count: count, isInfinite: false)
      case .infinite:
        return SessionSkill(name: skill.rawValue.capitalized, count: 0, isInfinite: true)
      case nil:
        return SessionSkill(name: skill.rawValue.capitalized, count: 0, isInfinite: false)
      }
    }
  }

  /// NeoLemmix events are not mapped to sounds yet.
  let lastCues: [ClassicSoundEffect] = []

  var supportsRewind: Bool { false }
  var currentTick: Int { simulation.tickCount }
  @discardableResult func rewind(seconds: Double) -> Bool { false }
  @discardableResult func stepBackward() -> Bool { false }
  @discardableResult func stepForward() -> Bool {
    guard !simulation.isComplete else { return false }
    tick()
    return true
  }

  func tick() { _ = simulation.tick() }

  func assignmentState(skillIndex: Int, to lemmingID: Int) -> AssignmentState {
    guard skillOrder.indices.contains(skillIndex) else { return .unavailable }
    let skill = skillOrder[skillIndex]
    var probe = simulation
    if case let .rejected(_, _, reason) = probe.assign(skill: skill, to: lemmingID) {
      if let lemming = simulation.lemmings.first(where: { $0.id == lemmingID && $0.canReceiveSkills }),
         lemming.traits.contains(where: { $0.rawValue == skill.rawValue }) { return .alreadyAssigned }
      if reason == .duplicatePermanentSkill || (reason == .invalidCurrentAction && isPerforming(skill: skill.rawValue, lemmingID: lemmingID)) { return .alreadyAssigned }
      return .unavailable
    }
    return .eligible
  }

  func assign(skillIndex: Int, to lemmingID: Int) -> String? {
    guard skillOrder.indices.contains(skillIndex) else { return "no such skill" }
    let result = simulation.assign(skill: skillOrder[skillIndex], to: lemmingID)
    if case let .rejected(_, _, reason) = result { return "\(reason)" }
    recoveryInputs.append(.init(tick: currentTick, action: .assign(skill: skillIndex, lemming: lemmingID)))
    skillAssignments[skillOrder[skillIndex].rawValue, default: 0] += 1
    return nil
  }

  // NeoLemmix routes rate and nuke through the replay command queue, so both
  // stay reproducible.
  func adjustRate(by delta: Int) {
    recoveryInputs.append(.init(tick: currentTick, action: .rate(delta: delta)))
    _ = simulation.enqueue(.setSpawnInterval(simulation.spawnInterval + delta))
  }

  var canUndoNuke: Bool { beforeNuke != nil }
  func nuke() {
    guard !simulation.isComplete, !simulation.isNuking, beforeNuke == nil else { return }
    nukeCount += 1
    beforeNukeInputCount = recoveryInputs.count
    recoveryInputs.append(.init(tick: currentTick, action: .nuke))
    beforeNuke = simulation
    beforeNukeSkills = skillAssignments
    _ = simulation.enqueue(.nuke)
  }
  func undoNuke() {
    guard let beforeNuke else { return }
    recoveryInputs = Array(recoveryInputs.prefix(beforeNukeInputCount))
    simulation = beforeNuke
    skillAssignments = beforeNukeSkills; usedRewind = true; undoCount += 1
    self.beforeNuke = nil
  }
}
