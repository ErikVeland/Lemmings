import Foundation

public enum TrolleyMaximumStatus: String, Codable, Sendable { case unknown = "UNKNOWN", observed = "OBSERVED", record = "REPLAY_RECORD", verified = "VERIFIED" }
public struct TrolleyMaximum: Codable, Equatable, Sendable {
    public let value: Int?
    public let status: TrolleyMaximumStatus
    public let source: String?
    public let date: Date?
    public let buildVersion: String?
    public init(value: Int? = nil, status: TrolleyMaximumStatus = .unknown, source: String? = nil,
                date: Date? = nil, buildVersion: String? = nil) {
        self.value = value; self.status = status; self.source = source; self.date = date; self.buildVersion = buildVersion
    }
    public var isRescueTarget: Bool { status == .verified || status == .record }
    public var label: String {
        switch status { case .unknown: "Maximum unknown"; case .record: "Best-known rescue"; case .observed: "Local best"; case .verified: "Verified maximum" }
    }
    public func isValid(population: Int) -> Bool {
        if status == .unknown { return value == nil }
        return value.map { (0...population).contains($0) } == true && source?.isEmpty == false
            && (!isRescueTarget || (date != nil && buildVersion?.isEmpty == false))
    }
}

public struct TrolleyMaximumRecord: Codable, Equatable, Sendable {
    public private(set) var highestObserved: Int?
    public private(set) var observedAttemptID: UUID?
    public private(set) var observedDate: Date?
    public private(set) var observedBuild: String?
    public private(set) var verified: TrolleyMaximum?
    public private(set) var supersededEvidence: [TrolleyMaximum] = []
    public init() {}
    public mutating func retainBundledEvidence(_ current: TrolleyMaximum?) {
        guard let verified, (verified.source?.hasPrefix(TrolleyProofCatalogue.sourcePrefix) == true || verified.source?.hasPrefix(TrolleyProofCatalogue.recordPrefix) == true),
              verified != current else { return }
        supersededEvidence.append(verified)
        self.verified = nil
    }
    public var current: TrolleyMaximum {
        if let verified {
            if verified.status == .record, let highestObserved, highestObserved > (verified.value ?? 0) {
                return TrolleyMaximum(value: highestObserved, status: .record, source: "Observed improvement " + (observedAttemptID?.uuidString ?? ""),
                                      date: observedDate, buildVersion: observedBuild)
            }
            return verified
        }
        if let highestObserved {
            return TrolleyMaximum(value: highestObserved, status: .observed, source: observedAttemptID?.uuidString,
                                  date: observedDate, buildVersion: observedBuild)
        }
        return TrolleyMaximum()
    }
    public mutating func observe(_ run: ArcadeRun) {
        if let verified, verified.status == .verified, run.saved > (verified.value ?? 0) {
            supersededEvidence.append(verified); self.verified = nil
        }
        if highestObserved == nil || run.saved > highestObserved! {
            highestObserved = run.saved; observedAttemptID = run.id; observedDate = run.date
            observedBuild = run.telemetry?.buildVersion
        }
        // Even a population-wide observed rescue remains OBSERVED until evidence is explicitly accepted.
    }
    public mutating func acceptVerified(_ evidence: TrolleyMaximum, population: Int) throws {
        guard evidence.isRescueTarget, evidence.isValid(population: population),
              evidence.value! >= (highestObserved ?? 0) else {
            throw SequelDataError.invalid("Maximum evidence is missing, incompatible, or below an observed rescue.")
        }
        if let verified, verified != evidence { supersededEvidence.append(verified) }
        verified = evidence
    }
}
