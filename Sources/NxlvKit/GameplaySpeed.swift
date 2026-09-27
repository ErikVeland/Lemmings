import Foundation

/// A short glide in musical pitch, separate from simulation and music tempo.
public struct GameplayMusicPitch: Sendable {
    public static let transitionDuration = 0.12
    public private(set) var cents: Double = 0
    private var target: Double = 0
    private var from: Double = 0
    private var changedAt: TimeInterval = 0

    public init() {}

    public static func ratio(for speed: Double) -> Double {
        let ratios = [1.0, 1.04, 1.09, 1.18, 1.35]
        let speed = min(10, max(1, speed))
        for index in 1..<GameplaySpeed.steps.count where speed <= GameplaySpeed.steps[index] {
            let lower = GameplaySpeed.steps[index - 1], upper = GameplaySpeed.steps[index]
            let blend = (speed - lower) / (upper - lower)
            return ratios[index - 1] * pow(ratios[index] / ratios[index - 1], blend)
        }
        return ratios.last!
    }

    public mutating func update(speed: Double, at now: TimeInterval) {
        let t = min(1, max(0, (now - changedAt) / Self.transitionDuration))
        cents = from + (target - from) * t * t * (3 - 2 * t)
        let next = 1200 * log2(Self.ratio(for: speed))
        if next != target { from = cents; target = next; changedAt = now }
    }
}

/// Speed changes the clock, never the size of a physics tick.
public struct GameplaySpeed: Sendable {
    public enum Hold: Hashable, Sendable { case key, shift, controller, mouse }
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
    public private(set) var cruise: Double = 2
    private var transitionFrom: Double = 1
    private var changedAt: TimeInterval = 0
    private var holdStartedAt: TimeInterval?
    private var held: Set<Hold> = []
    private var tapCandidates: Set<Hold> = []
    private var ignored: Set<Hold> = []
    private var stoppedAt: TimeInterval?

    public init(legacyMultiplier: Double = 3) { self.legacyMultiplier = legacyMultiplier }
    public var isFast: Bool { target > 1 }
    public var isHeld: Bool { !held.isEmpty }
    public var label: String { "\(Int(target))×" }

    public mutating func update(at now: TimeInterval) {
        if let start = holdStartedAt, !held.isEmpty, variableEnabled, now - start >= Self.holdDelay {
            let base = Self.steps.firstIndex(of: selected) ?? 0
            let step = 1 + Int((now - start - Self.holdDelay) / Self.holdStepDuration)
            changeTarget(Self.steps[min(Self.steps.count - 1, base + step)], at: now)
        }
        multiplier = value(at: now)
    }

    /// A tap toggles immediately. Extra clicks cannot restart a stopped burst.
    public mutating func tap(at now: TimeInterval, clickCount: Int = 1, immediate: Bool = true, absorbRapidClicks: Bool = true) {
        if absorbRapidClicks, variableEnabled, !isFast,
           clickCount > 1 || stoppedAt.map({ now >= $0 && now - $0 <= Self.rapidInterval }) == true {
            stoppedAt = now
            return
        }
        if isFast { reset(at: now); return }
        cancelHolds()
        selected = variableEnabled ? cruise : legacyMultiplier
        changeTarget(selected, at: now, immediate: !variableEnabled)
    }

    /// Apply the chosen tier, including when starting from normal speed.
    public mutating func step(_ direction: Int, at now: TimeInterval) {
        guard variableEnabled else { return }
        cancelHolds()
        let index = Self.steps.firstIndex(of: target) ?? 0
        selected = Self.steps[min(Self.steps.count - 1, max(0, index + (direction < 0 ? -1 : 1)))]
        if selected > 1 { cruise = selected }
        changeTarget(selected, at: now)
    }

    public mutating func press(_ input: Hold, at now: TimeInterval, tapEnabled: Bool = true) {
        guard !held.contains(input), !ignored.contains(input) else { return }
        if held.isEmpty { holdStartedAt = now }
        held.insert(input)
        if input != .shift && tapEnabled { tapCandidates.insert(input) }
        if !variableEnabled { changeTarget(legacyMultiplier, at: now, immediate: true) }
    }

    public mutating func release(_ input: Hold, at now: TimeInterval, allowTap: Bool = true) {
        if ignored.remove(input) != nil { return }
        if variableEnabled, input == .key, held.contains(input),
           now - (holdStartedAt ?? now) >= Self.holdDelay {
            update(at: now)
            selected = target
            if target > 1 { cruise = target }
        }
        let canTap = tapCandidates.remove(input) != nil
        guard held.remove(input) != nil, held.isEmpty else { return }
        let wasTap = allowTap && canTap && now - (holdStartedAt ?? now) < Self.holdDelay
        holdStartedAt = nil
        if wasTap && variableEnabled { tap(at: now, absorbRapidClicks: input != .mouse) }
        else { changeTarget(selected, at: now, immediate: true) }
    }

    /// Emergency exits preserve the chosen tier but invalidate held releases.
    public mutating func reset(at now: TimeInterval) {
        cancelHolds(); selected = 1; stoppedAt = now
        changeTarget(1, at: now, immediate: true)
    }

    /// Each level begins at normal speed with a conservative first fast tier.
    public mutating func newLevel(at now: TimeInterval) {
        reset(at: now); cruise = 2; stoppedAt = nil
    }

    public mutating func setFast(_ enabled: Bool, at now: TimeInterval) {
        cancelHolds()
        if !enabled { newLevel(at: now); return }
        selected = legacyMultiplier
        if variableEnabled { cruise = legacyMultiplier }
        changeTarget(selected, at: now, immediate: true)
    }

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
        if immediate || value < target {
            target = value; multiplier = value; transitionFrom = value; changedAt = now; return
        }
        guard value != target else { return }
        transitionFrom = self.value(at: now); multiplier = transitionFrom
        target = value; changedAt = now
    }
}
