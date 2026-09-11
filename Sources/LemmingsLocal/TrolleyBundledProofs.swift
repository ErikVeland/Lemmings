import Foundation
import CryptoKit
import NxlvKit

struct TrolleyBundledProofs {
    let catalogue: TrolleyProofCatalogue
    let engineFingerprint: String

    static func load(in bundle: Bundle = .main) -> Self? {
        guard let root = bundle.resourceURL?.appendingPathComponent("Trolley") else { return nil }
        return load(from: root)
    }
    static func load(from root: URL) -> Self? {
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
    func maximum(for conditions: TrolleyConditions) -> TrolleyMaximum? {
        catalogue.rescueTarget(for: conditions, engineFingerprint: engineFingerprint)
    }
    var maxima: [String: TrolleyMaximum] {
        var result: [String: TrolleyMaximum] = [:]
        for entry in catalogue.levels {
            guard let conditions = entry.conditions, let proof = maximum(for: conditions) else { continue }
            for assisted in [false, true] { result[conditions.comparisonID(assisted: assisted)] = proof }
        }
        return result
    }
}
