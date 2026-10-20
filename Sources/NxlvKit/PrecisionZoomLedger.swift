import Foundation

public enum PrecisionZoomKind: String, Codable, Sendable {
    case zoom
    case superzoom
}

public struct PrecisionZoomEarnings: Equatable, Sendable {
    public let superzoomUses: Int

    public init(superzoomUses: Int) {
        self.superzoomUses = max(0, superzoomUses)
    }

    public init(threeStarLevels: Int) {
        superzoomUses = max(0, threeStarLevels) / 3
    }
}

/**
 * Keeps Superzoom costs separate from uses in the current attempt. Ordinary Zoom is free.
 * The caller persists this value after each change so recovery keeps spent uses.
 */
public struct PrecisionZoomLedger: Codable, Equatable, Sendable {
    public private(set) var burnedSuperzoom = 0
    public private(set) var attemptID: UUID?
    public private(set) var usedSuperzoom = 0
    public private(set) var active: PrecisionZoomKind?

    public init() {}

    public mutating func start(attemptID: UUID) {
        guard self.attemptID != attemptID else { return }
        self.attemptID = attemptID
        usedSuperzoom = 0
        active = nil
    }

    public func remainingSuperzoom(earnings: PrecisionZoomEarnings) -> Int {
        max(0, earnings.superzoomUses - burnedSuperzoom - usedSuperzoom)
    }

    @discardableResult public mutating func toggle(_ kind: PrecisionZoomKind, earnings: PrecisionZoomEarnings) -> Bool {
        guard attemptID != nil else { return false }
        if active == kind { active = nil; return true }
        if kind == .superzoom {
            guard remainingSuperzoom(earnings: earnings) > 0 else { return false }
            usedSuperzoom += 1
        }
        active = kind
        return true
    }

    public static func effectiveSpeed(normal: Double, active: PrecisionZoomKind?) -> Double {
        active == .superzoom ? 0.5 : normal
    }

    public mutating func finish(didWin: Bool) {
        guard attemptID != nil else { return }
        if !didWin {
            burnedSuperzoom += usedSuperzoom
        }
        attemptID = nil
        usedSuperzoom = 0
        active = nil
    }
}
