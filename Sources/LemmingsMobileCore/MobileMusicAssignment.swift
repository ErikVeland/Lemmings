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

    public static func sequel(identifier: String, index: Int) -> (tune: Tune, cycle: Int, showcaseIndex: Int?)? {
        guard index >= 0 else { return nil }
        if identifier.hasPrefix("lemmings2/"), !identifier.hasPrefix("lemmings2/practice/"),
           LevelMusicSelection.lemmings2.indices.contains(index / 10) {
            let level = index % 10
            let tune = Tune(folder: "lemmings_2_music_mod_tsyu",
                            track: LevelMusicSelection.lemmings2[index / 10], game: "lemmings2")
            return (tune, level, LevelMusicSelection.lemmings2ShowcaseIndex(tribe: index / 10, level: level))
        }
        if identifier.hasPrefix("lemmings3/"), let tribe = Lemmings3ClassicCampaign.Tribe(rawValue: index / 30 + 1) {
            let (prefix, count) = switch tribe {
            case .classic: ("classic", 3)
            case .shadow: ("shadow", 2)
            case .egyptian: ("egypt", 2)
            }
            let level = index % 30
            let tune = Tune(folder: "lemmings_3_music_mod_tsyu",
                            track: prefix + String(level % count + 1), game: "lemmings3")
            return (tune, level / count, LevelMusicSelection.lemmings3ShowcaseIndex(
                tribe: tribe, level: level, openingCount: count))
        }
        return nil
    }
}
