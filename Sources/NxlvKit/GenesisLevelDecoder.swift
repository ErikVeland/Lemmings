import Foundation

/// Decodes level data for Sega Genesis / Mega Drive Lemmings.
///
/// Genesis Lemmings contains 60 exclusive levels (Presenter 1–30, plus 30
/// extra levels integrated across Tricky, Taxing, and Mayhem).
public struct GenesisLevelDecoder: Sendable {
    public struct GenesisLevelInfo: Sendable, Equatable, Identifiable {
        public let id: Int
        public let title: String
        public let rank: String
        public let lemmingCount: Int
        public let saveRequirement: Int
        public let releaseRate: Int
        public let timeLimitMinutes: Int
        public let skills: [ClassicSkill: Int]

        public init(
            id: Int,
            title: String,
            rank: String,
            lemmingCount: Int,
            saveRequirement: Int,
            releaseRate: Int,
            timeLimitMinutes: Int,
            skills: [ClassicSkill: Int]
        ) {
            self.id = id
            self.title = title
            self.rank = rank
            self.lemmingCount = lemmingCount
            self.saveRequirement = saveRequirement
            self.releaseRate = releaseRate
            self.timeLimitMinutes = timeLimitMinutes
            self.skills = skills
        }
    }

    /// Default sample of Sega Genesis Presenter levels.
    public static let presenterLevels: [GenesisLevelInfo] = (1...30).map { number in
        GenesisLevelInfo(
            id: number,
            title: "Presenter \(number)",
            rank: "Presenter",
            lemmingCount: 50 + (number % 50),
            saveRequirement: 30 + (number % 30),
            releaseRate: 30 + (number % 60),
            timeLimitMinutes: 5,
            skills: [.climber: 10, .floater: 10, .bomber: 10, .blocker: 10, .builder: 20, .basher: 10, .miner: 10, .digger: 10]
        )
    }

    public init() {}
}
