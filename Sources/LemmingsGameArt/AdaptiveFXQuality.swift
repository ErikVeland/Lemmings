import Foundation

/// Presentation budgets never change game ticks, input or recorded events.
public enum FXQuality: Int, CaseIterable, Sendable {
    case minimal, balanced, full
    public var bloomScale: Double { [0.25, 0.5, 1][rawValue] }
    public var overlayScale: Double { [0.5, 0.75, 1][rawValue] }
    public var effectHz: Double { [30, 45, 60][rawValue] }
    public var trailLimit: Int { [6, 12, 24][rawValue] }
    public var trailEchoLimit: Int { [2, 3, 5][rawValue] }
    public var explosionLimit: Int { [2, 4, 8][rawValue] }
}

public struct AdaptiveFXQuality: Sendable {
    public private(set) var quality: FXQuality
    public private(set) var smoothedCost: Double = 0
    private var lastSample: Double?
    private var pressureSince: Double?
    private var spareSince: Double?
    private var lastChange: Double = -.infinity

    public init(initial: FXQuality = .full) { quality = initial }

    /// Brief spikes are ignored. Recovery needs twelve seconds of spare capacity.
    public mutating func observe(cpuSeconds: Double, gpuSeconds: Double, now: Double,
                                 ceiling: FXQuality = .full) {
        guard now.isFinite, cpuSeconds.isFinite, gpuSeconds.isFinite,
              cpuSeconds >= 0, gpuSeconds >= 0 else { return }
        let elapsed = lastSample.map { now - $0 } ?? 0
        if elapsed < 0 || elapsed > 1 {
            pressureSince = nil; spareSince = nil; smoothedCost = 0
        }
        lastSample = now
        let cost = max(cpuSeconds, gpuSeconds)
        let blend = smoothedCost == 0 ? 1 : 1 - exp(-max(0, elapsed) / 0.5)
        smoothedCost += (cost - smoothedCost) * blend
        if quality.rawValue > ceiling.rawValue {
            quality = ceiling; lastChange = now; pressureSince = nil; spareSince = nil
        }
        if smoothedCost > 0.013 {
            spareSince = nil
            if pressureSince == nil { pressureSince = now }
            if now - pressureSince! >= 2 && now - lastChange >= 3,
               let lower = FXQuality(rawValue: quality.rawValue - 1) {
                quality = lower; lastChange = now; pressureSince = nil
            }
        } else if smoothedCost < 0.007 {
            pressureSince = nil
            if spareSince == nil { spareSince = now }
            if now - spareSince! >= 12 && now - lastChange >= 12,
               let higher = FXQuality(rawValue: quality.rawValue + 1), higher.rawValue <= ceiling.rawValue {
                quality = higher; lastChange = now; spareSince = nil
            }
        } else { pressureSince = nil; spareSince = nil }
    }
}
