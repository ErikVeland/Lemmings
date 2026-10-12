import Foundation
import NxlvKit

/// The bundled learning journey. Both values are read once from the resources of the running app.
public enum LearningJourneyLibrary {
    struct Exclusion: Decodable { let identity: LevelCatalogueIdentity }
    public static let excludedIdentities: Set<LevelCatalogueIdentity> = excludedIdentities(storage: .current())
    public static let journey: LearningJourney? = journey(storage: .current())

    public static func excludedIdentities(storage: AppStorage) -> Set<LevelCatalogueIdentity> {
        let url = storage.resources.appendingPathComponent("Progression/exclusions.json")
        guard let data = try? Data(contentsOf: url),
              let rows = try? JSONDecoder().decode([Exclusion].self, from: data) else { return [] }
        return Set(rows.map(\.identity))
    }

    public static func journey(storage: AppStorage) -> LearningJourney? {
        let url = storage.resources.appendingPathComponent("Progression/learning.json")
        guard let data = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode(LearningJourney.self, from: data),
              value.placementPolicy == LearningJourney.communityPlacementPolicy else { return nil }
        return try? value.excluding(excludedIdentities(storage: storage)).validated()
    }
}
