import Foundation

public enum PrecisionZoomKind: String, Codable, Sendable {
    case zoom
    case superzoom
}

public struct PrecisionZoomEarnings: Equatable, Sendable {
    public let zoomUses: Int
    public let superzoomUses: Int

    public init(careerStars: Int, threeStarLevels: Int) {
        zoomUses = max(0, careerStars) / 3
        superzoomUses = max(0, threeStarLevels) / 3
    }
}

/**
 * Keeps failed-run costs separate from uses in the current attempt.
 * The caller persists this value after each change so recovery keeps spent uses.
 */
public struct PrecisionZoomLedger: Codable, Equatable, Sendable {
    public private(set) var burnedZoom = 0
    public private(set) var burnedSuperzoom = 0
    public private(set) var attemptID: UUID?
    public private(set) var usedZoom = 0
    public private(set) var usedSuperzoom = 0
    public private(set) var active: PrecisionZoomKind?

    public init() {}

    public mutating func start(attemptID: UUID) {
        guard self.attemptID != attemptID else { return }
        self.attemptID = attemptID
        usedZoom = 0
        usedSuperzoom = 0
        active = nil
    }

    public func remaining(_ kind: PrecisionZoomKind, earnings: PrecisionZoomEarnings) -> Int {
        switch kind {
        case .zoom: max(0, earnings.zoomUses - burnedZoom - usedZoom)
        case .superzoom: max(0, earnings.superzoomUses - burnedSuperzoom - usedSuperzoom)
        }
    }

    @discardableResult public mutating func toggle(_ kind: PrecisionZoomKind, earnings: PrecisionZoomEarnings) -> Bool {
        guard attemptID != nil else { return false }
        if active == kind { active = nil; return true }
        guard remaining(kind, earnings: earnings) > 0 else { return false }
        switch kind {
        case .zoom: usedZoom += 1
        case .superzoom: usedSuperzoom += 1
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
            burnedZoom += usedZoom
            burnedSuperzoom += usedSuperzoom
        }
        attemptID = nil
        usedZoom = 0
        usedSuperzoom = 0
        active = nil
    }
}
