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
        // Settled tiers transpose the whole track by musical intervals.
        let normalRatios = [0.0, 1, 2, 3, 5].map { pow(2, $0 / 12) }
        let ratios = normalRatios + [min(1.5, normalRatios.last! + 0.1)]
        let steps = GameplaySpeed.ridiculousSteps
        let speed = min(25, max(1, speed))
        for index in 1..<steps.count where speed <= steps[index] {
            let lower = steps[index - 1], upper = steps[index]
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
    public static let ridiculousSteps: [Double] = steps + [25]
    public static let holdDelay = 0.25
    public static let holdStepDuration = 0.5
    public static let transitionDuration = 0.24
    public static let rapidInterval = 0.3
    public var variableEnabled = true
    private var measuredLimit = Double.infinity
    private var sampleSeconds = 0.0
    private var sampleTicks = 0
    public var ridiculousEnabled = false {
        didSet {
            guard !ridiculousEnabled, oldValue else { return }
            let wasHeld = !held.isEmpty
            cancelHolds()
            selected = min(10, selected); cruise = min(10, cruise)
            if wasHeld {
                target = selected; multiplier = selected; transitionFrom = selected
            } else {
                target = min(10, target); multiplier = min(10, multiplier)
                transitionFrom = min(10, transitionFrom)
            }
        }
    }
    public var availableSteps: [Double] {
        (ridiculousEnabled ? Self.ridiculousSteps : Self.steps).filter { $0 <= measuredLimit }
    }
    private var fixedFastSpeed: Double { min(legacyMultiplier, measuredLimit) }
    public var selectableSteps: [Double] { variableEnabled ? availableSteps : fixedFastSpeed > 1 ? [1, fixedFastSpeed] : [1] }
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
    /// A saved mobile fast tier sets the next tap without starting the clock.
    public mutating func setCruise(_ value: Double) {
        if availableSteps.contains(value), value > 1 { cruise = value }
    }
    public var isFast: Bool { target > 1 }
    public var isHeld: Bool { !held.isEmpty }
    /// The held pedal winds pitch up continuously while physics keeps its discrete tiers.
    public func musicPitchSpeed(at now: TimeInterval) -> Double {
        guard variableEnabled, !held.isEmpty, let start = holdStartedAt else { return target }
        let base = availableSteps.firstIndex(of: selected) ?? 0
        let position = min(Double(availableSteps.count - 1), Double(base)
            + max(0, now - start - Self.holdDelay) / Self.holdStepDuration)
        let lower = Int(position), upper = min(availableSteps.count - 1, lower + 1)
        return availableSteps[lower] + (availableSteps[upper] - availableSteps[lower]) * (position - Double(lower))
    }
    public var label: String { "\(Int(target))×" }

    public mutating func update(at now: TimeInterval) {
        if let start = holdStartedAt, !held.isEmpty, variableEnabled, now - start >= Self.holdDelay {
            let base = availableSteps.firstIndex(of: selected) ?? 0
            let step = 1 + Int((now - start - Self.holdDelay) / Self.holdStepDuration)
            changeTarget(availableSteps[min(availableSteps.count - 1, base + step)], at: now)
        }
        multiplier = value(at: now)
    }

    /// Lower the available tiers when the settled game clock cannot sustain its target.
    @discardableResult public mutating func observeThroughput(elapsed: TimeInterval, ticks: Int, ticksPerSecond: Double) -> Bool {
        guard target > 1, abs(multiplier - target) < 0.01,
              elapsed.isFinite, elapsed > 0, elapsed <= 1, ticksPerSecond.isFinite, ticksPerSecond > 0 else {
            resetThroughputSample()
            return false
        }
        sampleSeconds += elapsed
        sampleTicks += ticks
        guard sampleSeconds >= 1 else { return false }
        let expected = sampleSeconds * ticksPerSecond * target
        let delivered = Double(sampleTicks)
        let measured = delivered / (sampleSeconds * ticksPerSecond)
        resetThroughputSample()
        guard delivered + 1 < expected * 0.96 else { return false }
        measuredLimit = availableSteps.last(where: { $0 <= measured }) ?? 1
        selected = min(selected, measuredLimit)
        cruise = min(cruise, measuredLimit)
        changeTarget(measuredLimit, at: 0, immediate: true)
        return true
    }

    private mutating func resetThroughputSample() { sampleSeconds = 0; sampleTicks = 0 }

    /// A tap toggles immediately. Extra clicks cannot restart a stopped burst.
    public mutating func tap(at now: TimeInterval, clickCount: Int = 1, immediate: Bool = true, absorbRapidClicks: Bool = true) {
        if absorbRapidClicks, variableEnabled, !isFast,
           clickCount > 1 || stoppedAt.map({ now >= $0 && now - $0 <= Self.rapidInterval }) == true {
            stoppedAt = now
            return
        }
        if isFast { reset(at: now); return }
        cancelHolds()
        selected = variableEnabled ? cruise : fixedFastSpeed
        changeTarget(selected, at: now, immediate: !variableEnabled)
    }

    /// Apply the chosen tier, including when starting from normal speed.
    public mutating func step(_ direction: Int, at now: TimeInterval) {
        guard variableEnabled else { return }
        let index = availableSteps.firstIndex(of: target) ?? 0
        select(availableSteps[min(availableSteps.count - 1, max(0, index + (direction < 0 ? -1 : 1)))], at: now)
    }

    public mutating func select(_ tier: Double, at now: TimeInterval) {
        guard selectableSteps.contains(tier) else { return }
        cancelHolds()
        selected = tier
        if variableEnabled, tier > 1 { cruise = tier }
        changeTarget(tier, at: now, immediate: !variableEnabled)
    }

    public mutating func press(_ input: Hold, at now: TimeInterval, tapEnabled: Bool = true) {
        guard !held.contains(input), !ignored.contains(input) else { return }
        if held.isEmpty { holdStartedAt = now }
        held.insert(input)
        if input != .shift && tapEnabled { tapCandidates.insert(input) }
        if !variableEnabled { changeTarget(fixedFastSpeed, at: now, immediate: true) }
    }

    public mutating func release(_ input: Hold, at now: TimeInterval, allowTap: Bool = true, retainReachedSpeed: Bool = false) {
        if ignored.remove(input) != nil { return }
        if variableEnabled, input == .key || retainReachedSpeed, held.contains(input),
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
        measuredLimit = .infinity
        reset(at: now); cruise = 2; stoppedAt = nil
    }

    public mutating func setFast(_ enabled: Bool, at now: TimeInterval) {
        cancelHolds()
        if !enabled { newLevel(at: now); return }
        selected = fixedFastSpeed
        if variableEnabled { cruise = fixedFastSpeed }
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
        if value != target { resetThroughputSample() }
        if immediate || value < target {
            target = value; multiplier = value; transitionFrom = value; changedAt = now; return
        }
        guard value != target else { return }
        transitionFrom = self.value(at: now); multiplier = transitionFrom
        target = value; changedAt = now
    }
}
