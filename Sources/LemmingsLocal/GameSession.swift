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
  /// Returns nil when the assignment lands, or a reason when it does not.
  func assign(skillIndex: Int, to lemmingID: Int) -> String?
  func adjustRate(by delta: Int)
  func nuke()
}

// MARK: - Classic DOS

final class ClassicSession: GameSession {
  private(set) var simulation: ClassicDOSSimulation
  let levelWidth: Int
  let levelHeight: Int

  init(simulation: ClassicDOSSimulation, width: Int, height: Int) {
    self.simulation = simulation
    levelWidth = width
    levelHeight = height
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

  func tick() { _ = simulation.tick() }

  func assign(skillIndex: Int, to lemmingID: Int) -> String? {
    guard skillIndex < ClassicSkill.allCases.count else { return "no such skill" }
    let result = simulation.assign(ClassicSkill.allCases[skillIndex], to: lemmingID)
    return result == .assigned ? nil : result.rawValue
  }

  func adjustRate(by delta: Int) { simulation.setReleaseRate(simulation.releaseRate + delta) }
  func nuke() { simulation.beginNuke() }
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

  func nuke() { _ = simulation.enqueue(.nuke) }
}
