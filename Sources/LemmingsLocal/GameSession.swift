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

  func tick()
  /// Sounds the last tick asked for. Empty when nothing happened.
  var lastCues: [ClassicSoundEffect] { get }
  /// Returns nil when the assignment lands, or a reason when it does not.
  func assign(skillIndex: Int, to lemmingID: Int) -> String?
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

// MARK: - Classic DOS

final class ClassicSession: GameSession {
  /// Wraps the engine so any earlier tick can be reached exactly.
  private var history: ClassicDOSRewind
  private var beforeNuke: ClassicDOSRewind?
  var simulation: ClassicDOSSimulation { history.simulation }
  let levelWidth: Int
  let levelHeight: Int

  init(simulation: ClassicDOSSimulation, width: Int, height: Int) {
    history = ClassicDOSRewind(simulation: simulation)
    levelWidth = width
    levelHeight = height
  }

  var supportsRewind: Bool { true }
  var currentTick: Int { history.currentTick }

  @discardableResult func rewind(seconds: Double) -> Bool {
    let moved = history.rewind(seconds: seconds)
    if moved { lastCues = []; if !simulation.isNuking { beforeNuke = nil } }
    return moved
  }

  @discardableResult func stepBackward() -> Bool {
    let moved = history.stepBackward()
    if moved { lastCues = []; if !simulation.isNuking { beforeNuke = nil } }
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

  func assign(skillIndex: Int, to lemmingID: Int) -> String? {
    guard skillIndex < ClassicSkill.allCases.count else { return "no such skill" }
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
    beforeNuke = history
    history.beginNuke()
    lastCues = ClassicSoundCue.cues(for: simulation.lastTickEvents)
  }
  func undoNuke() {
    guard let beforeNuke else { return }
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
  let levelWidth: Int
  let levelHeight: Int
  private let skillOrder: [NeoLemmixSkill]

  init(simulation: NeoLemmixSimulation, width: Int, height: Int) {
    self.simulation = simulation
    levelWidth = width
    levelHeight = height
    // Show only the skills this level grants, in a stable order.
    skillOrder = NeoLemmixSkill.allCases.filter { simulation.skills[$0] != nil }
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

  func assign(skillIndex: Int, to lemmingID: Int) -> String? {
    guard skillIndex < skillOrder.count else { return "no such skill" }
    let result = simulation.assign(skill: skillOrder[skillIndex], to: lemmingID)
    if case let .rejected(_, _, reason) = result { return "\(reason)" }
    return nil
  }

  // NeoLemmix routes rate and nuke through the replay command queue, so both
  // stay reproducible.
  func adjustRate(by delta: Int) {
    _ = simulation.enqueue(.setSpawnInterval(simulation.spawnInterval + delta))
  }

  var canUndoNuke: Bool { beforeNuke != nil }
  func nuke() {
    guard !simulation.isComplete, !simulation.isNuking, beforeNuke == nil else { return }
    beforeNuke = simulation
    _ = simulation.enqueue(.nuke)
  }
  func undoNuke() {
    guard let beforeNuke else { return }
    simulation = beforeNuke
    self.beforeNuke = nil
  }
}
