import Foundation
import LemmingsAppCore
import NxlvKit

/// Resolves exact Classic routes through the mobile playlist flow.
public enum MobileShortPlayCatalogue {
    public static func entries(sequence: ShortPlaySequence, journey: LearningJourney?,
                               catalogue: MobileCatalogue) throws -> [MobileFavourites.Entry] {
        guard sequence.engine == .classic, let journey,
              let entries = sequence.entries(resolving: { identity in
                  journey.lessons.first { $0.entry.identity == identity }?.entry
              }) else { throw MobileSessionError.journeyEngineUnavailable }
        let library = MobileJourneyLibrary(entries: entries, name: sequence.title, catalogue: catalogue)
        let first = try library.origin(of: 0)
        guard let classic = first.library as? ClassicMobileLibrary,
              ClassicSourceRevision.directory(classic.directory, excluding: ["exe", "bat", "doc"])
                == ShortPlayCatalogue.classicDataRevision else { throw MobileSessionError.changedLevel }
        let fingerprint = try MobileContentFingerprint.digest(directory: classic.directory)
        return try entries.indices.map { index in
            let origin = try library.origin(of: index)
            guard origin.pack == first.pack else { throw MobileSessionError.changedLevel }
            return MobileFavourites.Entry(pack: origin.pack, level: origin.library.levelKey(at: origin.index),
                title: entries[index].levelNameSnapshot,
                sourceFingerprint: fingerprint)
        }
    }
}
