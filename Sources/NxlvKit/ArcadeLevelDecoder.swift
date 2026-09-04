import Foundation

/// Decodes level data for Arcade Lemmings (Data East / Sega Arcade).
///
/// Arcade Lemmings features unique single-player arcade stages, level timers,
/// high score screens, and 2-Player Co-Op maps.
public struct ArcadeLevelDecoder: Sendable {
    public struct ArcadeLevelInfo: Sendable, Equatable, Identifiable {
        public let id: Int
        public let title: String
        public let rank: String
        public let isTwoPlayerCoOp: Bool
        public let lemmingCount: Int
        public let saveRequirement: Int
        public let releaseRate: Int
        public let timeLimitSeconds: Int
        public let skills: [ClassicSkill: Int]

        public init(
            id: Int,
            title: String,
            rank: String,
            isTwoPlayerCoOp: Bool = false,
            lemmingCount: Int,
            saveRequirement: Int,
            releaseRate: Int,
            timeLimitSeconds: Int,
            skills: [ClassicSkill: Int]
        ) {
            self.id = id
            self.title = title
            self.rank = rank
            self.isTwoPlayerCoOp = isTwoPlayerCoOp
            self.lemmingCount = lemmingCount
            self.saveRequirement = saveRequirement
            self.releaseRate = releaseRate
            self.timeLimitSeconds = timeLimitSeconds
            self.skills = skills
        }
    }

    /// Default sample of Arcade bonus levels.
    public static let arcadeLevels: [ArcadeLevelInfo] = [
        ArcadeLevelInfo(
            id: 1,
            title: "Arcade Stage 1",
            rank: "Arcade Bonus",
            lemmingCount: 30,
            saveRequirement: 20,
            releaseRate: 50,
            timeLimitSeconds: 180,
            skills: [.climber: 5, .floater: 5, .bomber: 5, .blocker: 5, .builder: 10, .basher: 5, .miner: 5, .digger: 5]
        ),
        ArcadeLevelInfo(
            id: 2,
            title: "Arcade Stage 2 - Co-Op Challenge",
            rank: "Arcade Co-Op",
            isTwoPlayerCoOp: true,
            lemmingCount: 50,
            saveRequirement: 40,
            releaseRate: 60,
            timeLimitSeconds: 240,
            skills: [.climber: 10, .floater: 10, .bomber: 10, .blocker: 10, .builder: 20, .basher: 10, .miner: 10, .digger: 10]
        ),
    ]

    public init() {}
}
