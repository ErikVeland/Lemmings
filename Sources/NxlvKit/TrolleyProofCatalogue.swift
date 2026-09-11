import Foundation

/// Bundled certificates only promote a replay that reaches the finite population upper bound.
/// A completed solution with losses remains an observation, even if it is a record.
public struct TrolleyProofCatalogue: Codable, Sendable {
    public static let recordPrefix = "Native rescue record "
    public static let sourcePrefix = "Population-bound replay "
    public struct Witness: Codable, Sendable {
        public let path: String
        public let sha256: String
        public let saved: Int
        public let released: Int
        public let lost: Int
        public let retainedReserves: Int
        public let completed: Bool
        public let didWin: Bool
    }
    public struct Entry: Codable, Sendable {
        public let conditions: TrolleyConditions?
        public let status: String
        public let population: Int
        public let maximumSaveable: Int?
        public let minimumSacrifices: Int?
        public let witness: Witness?
    }
    public let schemaVersion: Int
    public let generatedAt: Date
    public let engineSourceFingerprint: String
    public let levels: [Entry]

    public func maximum(for conditions: TrolleyConditions, engineFingerprint: String) -> TrolleyMaximum? {
        guard schemaVersion == 1, Self.isDigest(engineFingerprint), engineSourceFingerprint == engineFingerprint,
              conditions.isValid, let bound = conditions.maximumPopulation else { return nil }
        let matches = levels.filter { $0.conditions == conditions }
        guard matches.count == 1, let entry = matches.first, entry.status == "VERIFIED",
              entry.population == conditions.population, entry.maximumSaveable == bound, entry.minimumSacrifices == 0,
              let witness = entry.witness, witness.saved == bound, witness.released == bound,
              witness.lost == 0, witness.retainedReserves == 0, witness.completed, witness.didWin,
              Self.isDigest(witness.sha256) else { return nil }
        return TrolleyMaximum(value: bound, status: .verified, source: Self.sourcePrefix + witness.sha256,
                              date: generatedAt, buildVersion: engineFingerprint)
    }
    /// A replay proves this target is attainable, not that saving more is impossible.
    public func rescueTarget(for conditions: TrolleyConditions, engineFingerprint: String) -> TrolleyMaximum? {
        if let proof = maximum(for: conditions, engineFingerprint: engineFingerprint) { return proof }
        guard schemaVersion == 1, Self.isDigest(engineFingerprint), engineSourceFingerprint == engineFingerprint,
              conditions.isValid, let bound = conditions.maximumPopulation else { return nil }
        let matches = levels.filter { $0.conditions == conditions }
        guard matches.count == 1, let entry = matches.first, entry.status == "REPLAY_RECORD",
              entry.population == conditions.population, entry.maximumSaveable == nil, entry.minimumSacrifices == nil,
              let w = entry.witness, w.completed, w.didWin, w.saved >= conditions.rescueRequirement,
              w.saved < bound, w.released == bound, w.lost >= 0, w.saved + w.lost <= bound, w.retainedReserves == 0,
              Self.isDigest(w.sha256) else { return nil }
        return TrolleyMaximum(value: w.saved, status: .record, source: Self.recordPrefix + w.sha256,
                              date: generatedAt, buildVersion: engineFingerprint)
    }
    public static func isDigest(_ value: String) -> Bool {
        value.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
}
