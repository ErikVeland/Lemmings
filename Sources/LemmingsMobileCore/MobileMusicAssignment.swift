import Foundation
import NxlvKit

/// A saved journey uses its position in the full score, including revisits.
public struct MobileMusicContext: Sendable {
    public var scorePosition: Int?
    public var titles: [String]
    public var isFan: Bool
    public var isLearningJourney: Bool
    public init(scorePosition: Int? = nil, titles: [String] = [], isFan: Bool = false, isLearningJourney: Bool = false) {
        self.scorePosition = scorePosition; self.titles = titles
        self.isFan = isFan; self.isLearningJourney = isLearningJourney
    }
}

/// Which tune a level plays, decided from the level's own identity.
public enum MobileMusicAssignment {
    public struct Tune: Equatable, Sendable {
        /// The bundled module folder, such as `lemmings_music_mod`.
        public let folder: String
        public let track: String
        /// The first part of a composition identity: `classic`, `ohno` or `holiday`.
        public let game: String
    }

    public static func tune(identifier: String, index: Int, title: String) -> Tune {
        // Official identifiers start with the release name. Fan packs borrow the original rotation.
        let release = identifier.split(separator: "-").first.map(String.init) ?? ""
        let holiday = release.hasPrefix("xmas") || release.hasPrefix("holiday")
        let ohNo = release == ClassicTitle.ohNoMoreLemmings.rawValue
        let folder = holiday ? "holiday_lemmings_music_mod" : ohNo ? "oh_no_more_lemmings_music_mod" : "lemmings_music_mod"
        return Tune(folder: folder, track: LevelMusicSelection.track(index: index, title: title, holiday: holiday, ohNo: ohNo),
                    game: holiday ? "holiday" : ohNo ? "ohno" : "classic")
    }

    public static func cycle(tune: Tune, index: Int, titles: [String], isFan: Bool) -> Int {
        if isFan { return max(0, index) / LevelMusicSelection.classic.count }
        return LevelMusicSelection.cycle(index: index, titles: titles, holiday: tune.game == "holiday", ohNo: tune.game == "ohno")
    }
}
