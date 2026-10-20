import Foundation
import LemmingsAppCore
import NxlvKit

/// Adapts an exact Classic opening to the existing mobile playlist flow.
public enum MobileShortPlayCatalogue {
    public static func entries(sequence: ShortPlaySequence, journey: LearningJourney?,
                               catalogue: MobileCatalogue) throws -> [MobileFavourites.Entry] {
        guard sequence.engine == .classic, let journey,
              let entries = sequence.entries(resolving: { identity in
                  journey.lessons.first { $0.entry.identity == identity }?.entry
              }) else { throw MobileSessionError.journeyEngineUnavailable }
        let library = MobileJourneyLibrary(entries: entries, name: sequence.title, catalogue: catalogue)
        return try entries.indices.map { index in
            let origin = try library.origin(of: index)
            guard let classic = origin.library as? ClassicMobileLibrary else { throw MobileSessionError.changedLevel }
            return MobileFavourites.Entry(pack: origin.pack, level: origin.library.levelKey(at: origin.index),
                title: entries[index].levelNameSnapshot,
                sourceFingerprint: try MobileContentFingerprint.digest(directory: classic.directory))
        }
    }
}
