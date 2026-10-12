import Foundation
import CryptoKit
import NxlvKit

public struct TrolleyBundledProofs: Sendable {
    public let catalogue: TrolleyProofCatalogue
    public let engineFingerprint: String

    public static func load(storage: AppStorage = .current()) -> Self? {
        load(from: storage.resources.appendingPathComponent("Trolley"))
    }
    public static func load(from root: URL) -> Self? {
        guard let bytes = try? Data(contentsOf: root.appendingPathComponent("verified-maxima.json")),
              let fingerprint = try? String(contentsOf: root.appendingPathComponent("engine-fingerprint.txt"), encoding: .utf8) else { return nil }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        guard let catalogue = try? decoder.decode(TrolleyProofCatalogue.self, from: bytes),
              catalogue.engineSourceFingerprint == fingerprint.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        for entry in catalogue.levels {
            guard let witness = entry.witness, witness.path.hasPrefix("witnesses/"),
                  !witness.path.split(separator: "/").contains(".."),
                  let replay = try? Data(contentsOf: root.appendingPathComponent(witness.path)),
                  SHA256.hash(data: replay).map({ String(format: "%02x", $0) }).joined() == witness.sha256 else { return nil }
        }
        return Self(catalogue: catalogue, engineFingerprint: fingerprint.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    public func maximum(for conditions: TrolleyConditions) -> TrolleyMaximum? {
        catalogue.rescueTarget(for: conditions, engineFingerprint: engineFingerprint)
    }
    public var maxima: [String: TrolleyMaximum] {
        var result: [String: TrolleyMaximum] = [:]
        for entry in catalogue.levels {
            guard let conditions = entry.conditions, let proof = maximum(for: conditions) else { continue }
            for assisted in [false, true] { result[conditions.comparisonID(assisted: assisted)] = proof }
        }
        return result
    }
}
