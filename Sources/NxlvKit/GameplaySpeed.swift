import Foundation

/// Presentation speed changes the clock, never the size of a physics tick.
public struct GameplaySpeed: Sendable {
    public enum Hold: Hashable, Sendable { case key, shift, controller }
    public static let steps: [Double] = [1, 2, 3, 5, 10]
    public static let holdDelay = 0.25
    public static let holdStepDuration = 0.5
    public static let transitionDuration = 0.24
    public static let rapidInterval = 0.3
    public var variableEnabled = true
    public let legacyMultiplier: Double
    public private(set) var selected: Double = 1
    public private(set) var target: Double = 1
    public private(set) var multiplier: Double = 1
    private var transitionFrom: Double = 1
    private var changedAt: TimeInterval = 0
    private var holdStartedAt: TimeInterval?
    private var held: Set<Hold> = []
    private var tapCandidates: Set<Hold> = []
    private var ignored: Set<Hold> = []
    private var lastTap: TimeInterval?
    /// A single click waits out the double-click window before it changes tier,
    /// so a double click toggles cleanly instead of stepping up and back.
    private var pendingTapAt: TimeInterval?
    /// What a double click restores when the game is already stopped.
    private var lastCruise: Double = 2
    /// When the last double click stopped the game. Mashing the button is an
    /// emergency stop, so further taps in that burst must not start it again.
    private var stoppedAt: TimeInterval?

    public init(legacyMultiplier: Double = 3) { self.legacyMultiplier = legacyMultiplier }
    public var isFast: Bool { target > 1 || multiplier > 1.001 }
    public var isHeld: Bool { !held.isEmpty }
    public var label: String { "\(Int(target))×" }

    public mutating func update(at now: TimeInterval) {
        // Compare with a tolerance. Frame times rarely land on the boundary, and
        // a subtraction like 2.3 - 2.0 is a shade under the interval in binary.
        if let pending = pendingTapAt, now >= pending,
           now - pending >= Self.rapidInterval - 0.001 {
            commitTap(at: now)
        }
        if let start = holdStartedAt, !held.isEmpty, variableEnabled, now - start >= Self.holdDelay {
            let base = Self.steps.firstIndex(of: selected) ?? 0
            let step = 1 + Int((now - start - Self.holdDelay) / Self.holdStepDuration)
            changeTarget(Self.steps[min(Self.steps.count - 1, base + step)], at: now)
        }
        multiplier = value(at: now)
    }

    /// `immediate` skips the double-click wait. Key taps use it, because the
    /// keyboard already has its own rapid-tap stop. A click on the speed button
    /// waits, so a double click can claim it.
    public mutating func tap(at now: TimeInterval, clickCount: Int = 1, immediate: Bool = false) {
        if variableEnabled, clickCount >= 2 || lastTap.map({ now >= $0 && now - $0 <= Self.rapidInterval }) == true {
            // A double click toggles. Stop if the game is moving, otherwise go
            // back to the speed it was last running at.
            let pendingStep = pendingTapAt != nil
            pendingTapAt = nil
            if isFast || selected > 1 || pendingStep {
                if selected > 1 { lastCruise = selected }
                reset(at: now)
                stoppedAt = now
            } else if stoppedAt.map({ now >= $0 && now - $0 <= Self.rapidInterval }) != true {
                selected = lastCruise
                changeTarget(selected, at: now)
                stoppedAt = nil
            }
            lastTap = now
            return
        }
        lastTap = now
        cancelHolds()
        // Defer the tier change so the double-click window can claim it first.
        if variableEnabled {
            if immediate { commitTap(at: now) } else { pendingTapAt = now }
            return
        }
        selected = selected > 1 ? 1 : legacyMultiplier
        changeTarget(selected, at: now, immediate: true)
    }

    private mutating func commitTap(at now: TimeInterval) {
        pendingTapAt = nil
        let index = Self.steps.firstIndex(of: selected) ?? 0
        selected = Self.steps[(index + 1) % Self.steps.count]
        if selected > 1 { lastCruise = selected }
        changeTarget(selected, at: now)
    }

    public mutating func step(_ direction: Int, at now: TimeInterval) {
        guard variableEnabled else { return }
        cancelHolds(); pendingTapAt = nil; lastTap = nil
        let index = Self.steps.firstIndex(of: selected) ?? 0
        selected = Self.steps[min(Self.steps.count - 1, max(0, index + (direction < 0 ? -1 : 1)))]
        changeTarget(selected, at: now)
    }

    public mutating func press(_ input: Hold, at now: TimeInterval, tapEnabled: Bool = true) {
        guard !held.contains(input), !ignored.contains(input) else { return }
        let canTap = input != .shift && tapEnabled
        if canTap, variableEnabled,
           let lastTap, now >= lastTap, now - lastTap <= Self.rapidInterval {
            // Same emergency stop as a double click, so a further rapid tap
            // cannot start the game moving again.
            reset(at: now); stoppedAt = now; self.lastTap = now
            ignored.insert(input); return
        }
        if held.isEmpty { holdStartedAt = now }
        held.insert(input)
        if canTap { tapCandidates.insert(input) }
        if !variableEnabled { changeTarget(legacyMultiplier, at: now, immediate: true) }
    }

    public mutating func release(_ input: Hold, at now: TimeInterval, allowTap: Bool = true) {
        if ignored.remove(input) != nil { return }
        let canTap = tapCandidates.remove(input) != nil
        guard held.remove(input) != nil, held.isEmpty else { return }
        let wasTap = allowTap && canTap && now - (holdStartedAt ?? now) < Self.holdDelay
        holdStartedAt = nil
        if wasTap && variableEnabled { tap(at: now, immediate: true) }
        else { changeTarget(selected, at: now, immediate: !variableEnabled) }
    }

    public mutating func reset(at now: TimeInterval) {
        cancelHolds(); pendingTapAt = nil; lastTap = nil; selected = 1
        changeTarget(1, at: now, immediate: true)
    }

    /// Compatibility for callers that explicitly request the original fast speed.
    public mutating func setFast(_ enabled: Bool, at now: TimeInterval) {
        cancelHolds(); pendingTapAt = nil; lastTap = nil; selected = enabled ? legacyMultiplier : 1
        changeTarget(selected, at: now, immediate: true)
    }

    /// A focus loss has no matching key-up event in this window.
    public mutating func cancelInput(at now: TimeInterval) {
        reset(at: now); ignored.removeAll()
    }

    public mutating func suspend(at now: TimeInterval) {
        cancelHolds(); changeTarget(selected, at: now, immediate: true)
    }

    private mutating func cancelHolds() {
        ignored.formUnion(held); held.removeAll(); tapCandidates.removeAll(); holdStartedAt = nil
    }
    private func value(at now: TimeInterval) -> Double {
        let t = min(1, max(0, (now - changedAt) / Self.transitionDuration))
        return transitionFrom + (target - transitionFrom) * t * t * (3 - 2 * t)
    }
    private mutating func changeTarget(_ value: Double, at now: TimeInterval, immediate: Bool = false) {
        if immediate { target = value; multiplier = value; transitionFrom = value; changedAt = now; return }
        guard value != target else { return }
        transitionFrom = self.value(at: now); multiplier = transitionFrom
        target = value; changedAt = now
    }
}
