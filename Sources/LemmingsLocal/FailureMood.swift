import AppKit

enum FailureMoodDecision {
  /**
   * Counts deaths until rescue becomes impossible. Nil means the target is safe.
   */
  static func deathsUntilUnrecoverable(saved: Int, active: Int, unreleased: Int, required: Int) -> Int? {
    guard saved < required else { return nil }
    return max(0, saved + max(0, active) + max(0, unreleased) - required + 1)
  }

  static func deathCounter(saved: Int, active: Int, unreleased: Int, required: Int, total: Int,
                           isComplete: Bool, didWin: Bool) -> (visible: String, accessibility: String) {
    if didWin || saved >= required { return ("SAFE", "Rescue target met") }
    let limit = max(0, total - required + 1)
    let remaining = isComplete ? 0 : min(limit,
      deathsUntilUnrecoverable(saved: saved, active: active, unreleased: unreleased, required: required) ?? 0)
    return ("\(remaining)/\(limit) 💀", "\(remaining) of \(limit) deaths remain before failure")
  }

  /// Returns true when no remaining lemming can meet the rescue requirement.
  static func isUnrecoverable(saved: Int, active: Int, unreleased: Int, required: Int) -> Bool {
    deathsUntilUnrecoverable(saved: saved, active: active, unreleased: unreleased, required: required) == 0
  }
}

/// A short transition into the unmistakable, but reversible, failed-run mood.
@MainActor final class FailureMoodTransition {
  nonisolated(unsafe) private var timer: Timer?
  private let duration: Double
  init(duration: Double = 0.9) { self.duration = duration }
  private var startedAt = 0.0
  private var startAmount: CGFloat = 0
  private var targetAmount: CGFloat = 0

  private(set) var amount: CGFloat = 0
  var onChange: ((CGFloat) -> Void)?

  func set(active: Bool) {
    let target: CGFloat = active ? 1 : 0
    guard target != targetAmount else { return }
    targetAmount = target
    timer?.invalidate()
    startAmount = amount
    startedAt = ProcessInfo.processInfo.systemUptime
    timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        let progress = min(1, max(0, (ProcessInfo.processInfo.systemUptime - self.startedAt) / self.duration))
        let eased = progress * progress * (3 - 2 * progress)
        self.amount = self.startAmount + (self.targetAmount - self.startAmount) * CGFloat(eased)
        self.onChange?(self.amount)
        if progress >= 1 {
          self.timer?.invalidate()
          self.timer = nil
        }
      }
    }
    onChange?(amount)
  }

  deinit { timer?.invalidate() }
}

@MainActor enum FailureMoodOverlay {
  static func draw(in rect: CGRect, amount: CGFloat) {
    guard amount > 0 else { return }
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    context.saveGState()
    context.setBlendMode(.color)
    context.setFillColor(NSColor(calibratedWhite: 0.28, alpha: 0.72 * amount).cgColor)
    context.fill(rect)
    context.setBlendMode(.normal)
    context.setFillColor(NSColor.black.withAlphaComponent(0.26 * amount).cgColor)
    context.fill(rect)
    context.restoreGState()
  }
}

/// Follow simulation time so pause, speed changes and rewind move the filter
/// with the visible countdown rather than with a separate wall-clock fade.
@MainActor final class NukeMusicSweep {
  private var startTick: Int?
  private var returnStartedAt: TimeInterval?
  private var returnAmount: CGFloat = 0
  static let returnDuration: TimeInterval = 0.28
  private(set) var amount: CGFloat = 0
  var onChange: ((CGFloat) -> Void)?

  func update(active: Bool, tick: Int, durationTicks: Int, remainingTicks: Int? = nil,
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
  func advanceReturn(at now: TimeInterval) {
    guard let returnStartedAt else { return }
    let progress = min(1, max(0, (now - returnStartedAt) / Self.returnDuration))
    let eased = progress * progress * (3 - 2 * progress)
    let next = returnAmount * CGFloat(1 - eased)
    guard next != amount else { return }
    amount = next
    onChange?(amount)
  }

  func reset() {
    startTick = nil
    returnStartedAt = nil
    returnAmount = 0
    guard amount != 0 else { return }
    amount = 0
    onChange?(0)
  }
}
