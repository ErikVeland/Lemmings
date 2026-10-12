import Foundation

public enum FailureMoodDecision {
  /**
   * Counts deaths until rescue becomes impossible. Nil means the target is safe.
   */
  public static func deathsUntilUnrecoverable(saved: Int, active: Int, unreleased: Int, required: Int) -> Int? {
    guard saved < required else { return nil }
    return max(0, saved + max(0, active) + max(0, unreleased) - required + 1)
  }

  public static func deathCounter(saved: Int, active: Int, unreleased: Int, required: Int, total: Int,
                           isComplete: Bool, didWin: Bool) -> (visible: String, accessibility: String) {
    if didWin || saved >= required { return ("SAFE", "Rescue target met") }
    let limit = max(0, total - required + 1)
    let remaining = isComplete ? 0 : min(limit,
      deathsUntilUnrecoverable(saved: saved, active: active, unreleased: unreleased, required: required) ?? 0)
    return ("\(remaining)/\(limit) 💀", "\(remaining) of \(limit) deaths remain before failure")
  }

  /// Returns true when no remaining lemming can meet the rescue requirement.
  public static func isUnrecoverable(saved: Int, active: Int, unreleased: Int, required: Int) -> Bool {
    deathsUntilUnrecoverable(saved: saved, active: active, unreleased: unreleased, required: required) == 0
  }
}

/// A short transition into the unmistakable, but reversible, failed-run mood.
@MainActor public final class FailureMoodTransition {
  nonisolated(unsafe) private var timer: Timer?
  private let duration: Double
  private let recoveryDuration: Double
  private var currentDuration: Double = 0.9
  public init(duration: Double = 0.9, recoveryDuration: Double? = nil) {
    self.duration = duration
    self.recoveryDuration = recoveryDuration ?? duration
  }
  private var startedAt = 0.0
  private var startAmount: CGFloat = 0
  private var targetAmount: CGFloat = 0

  public private(set) var amount: CGFloat = 0
  public var onChange: ((CGFloat) -> Void)?

  public func set(active: Bool, now: TimeInterval = ProcessInfo.processInfo.systemUptime, animated: Bool = true) {
    let target: CGFloat = active ? 1 : 0
    if !animated {
      guard target != targetAmount || amount != target else { return }
      timer?.invalidate(); timer = nil
      targetAmount = target; amount = target
      onChange?(amount)
      return
    }
    guard target != targetAmount else { return }
    targetAmount = target
    timer?.invalidate()
    startAmount = amount
    startedAt = now
    currentDuration = active ? duration : recoveryDuration
    timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        self.advance(at: ProcessInfo.processInfo.systemUptime)
      }
    }
    onChange?(amount)
  }

  public func advance(at now: TimeInterval) {
    guard timer != nil else { return }
    let progress = min(1, max(0, (now - startedAt) / currentDuration))
    let eased = progress * progress * (3 - 2 * progress)
    amount = startAmount + (targetAmount - startAmount) * CGFloat(eased)
    onChange?(amount)
    if progress >= 1 { timer?.invalidate(); timer = nil }
  }

  deinit { timer?.invalidate() }
}

/// Restore the track after a nuke without clearing the failed-run visuals.
@MainActor public final class FailureMusicTransition {
  private let transition: FailureMoodTransition
  private var nukeSlowdownStarted = false
  private var lastNukeTick: Int?
  public private(set) var rate: Double = 1
  public var onChange: ((Double) -> Void)?

  public init(duration: Double = 0.9, recoveryDuration: Double = NukeMusicSweep.returnDuration) {
    transition = FailureMoodTransition(duration: duration, recoveryDuration: recoveryDuration)
    transition.onChange = { [weak self] amount in
      guard let self else { return }
      self.rate = 1 - 0.28 * Double(amount)
      self.onChange?(self.rate)
    }
  }

  public func update(failed: Bool, isNuking: Bool, allPopped: Bool,
              remainingTicks: Int? = nil, oneCountTicks: Int = 17, tick: Int = 0,
              now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
    if !isNuking {
      nukeSlowdownStarted = false
      lastNukeTick = nil
    } else {
      if let lastNukeTick, tick < lastNukeTick { nukeSlowdownStarted = false }
      if let remainingTicks, remainingTicks <= max(1, oneCountTicks) { nukeSlowdownStarted = true }
      lastNukeTick = tick
    }
    // Hold after the first countdown reaches one until the final audible pop.
    transition.set(active: (failed || nukeSlowdownStarted) && !(isNuking && allPopped), now: now)
  }

  public func advance(at now: TimeInterval) { transition.advance(at: now) }
}


/// Follow simulation time so pause, speed changes and rewind move the filter
/// with the visible countdown rather than with a separate wall-clock fade.
@MainActor public final class NukeMusicSweep {
  public init() {}
  private var startTick: Int?
  private var returnStartedAt: TimeInterval?
  private var returnAmount: CGFloat = 0
  public static let returnDuration: TimeInterval = 2.4
  public private(set) var amount: CGFloat = 0
  public var onChange: ((CGFloat) -> Void)?

  public func update(active: Bool, tick: Int, durationTicks: Int, remainingTicks: Int? = nil,
              allPopped: Bool = false, now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
    guard active else { reset(); return }
    if allPopped {
      if returnStartedAt == nil {
        returnStartedAt = now
        returnAmount = amount
      }
      advanceReturn(at: now)
      return
    }
    // Rewind can bring a countdown back after the return sweep has begun.
    returnStartedAt = nil
    let duration = max(1, durationTicks)
    if startTick == nil || tick < startTick! {
      let elapsed = remainingTicks.map { max(0, duration - $0) } ?? 0
      startTick = tick - elapsed
    }
    let next = CGFloat(min(1, max(0, Double(tick - startTick!) / Double(duration))))
    guard next != amount else { return }
    amount = next
    onChange?(amount)
  }

  /// Keep opening the filter after simulation ticks stop on the result screen.
  public func advanceReturn(at now: TimeInterval) {
    guard let returnStartedAt else { return }
    let progress = min(1, max(0, (now - returnStartedAt) / Self.returnDuration))
    let eased = progress * progress * (3 - 2 * progress)
    let next = returnAmount * CGFloat(1 - eased)
    guard next != amount else { return }
    amount = next
    onChange?(amount)
  }

  public func reset() {
    startTick = nil
    returnStartedAt = nil
    returnAmount = 0
    guard amount != 0 else { return }
    amount = 0
    onChange?(0)
  }
}

