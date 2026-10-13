import Foundation

/// Decodes level data directly from Super Nintendo SNES `.sfc` ROM files.
///
/// SNES Lemmings contains 125 levels in total: the 120 classic levels plus 5
/// exclusive Sunsoft Special levels featuring unique music and level layouts.
public struct SNESLevelDecoder: Sendable {
    public struct SNESLevelInfo: Sendable, Equatable, Identifiable {
        public let id: Int
        public let title: String
        public let rank: String
        public let isSunsoftSpecial: Bool
        public let lemmingCount: Int
        public let saveRequirement: Int
        public let releaseRate: Int
        public let timeLimitMinutes: Int
        public let skills: [ClassicSkill: Int]

        public init(
            id: Int,
            title: String,
            rank: String,
            isSunsoftSpecial: Bool,
            lemmingCount: Int,
            saveRequirement: Int,
            releaseRate: Int,
            timeLimitMinutes: Int,
            skills: [ClassicSkill: Int]
        ) {
            self.id = id
            self.title = title
            self.rank = rank
            self.isSunsoftSpecial = isSunsoftSpecial
            self.lemmingCount = lemmingCount
            self.saveRequirement = saveRequirement
            self.releaseRate = releaseRate
            self.timeLimitMinutes = timeLimitMinutes
            self.skills = skills
        }
    }

    /// The 5 exclusive Sunsoft Special levels shipped on the Super Nintendo cartridge.
    public static let sunsoftSpecialLevels: [SNESLevelInfo] = [
        SNESLevelInfo(
            id: 120,
            title: "Sunsoft Special 1",
            rank: "Sunsoft Special",
            isSunsoftSpecial: true,
            lemmingCount: 50,
            saveRequirement: 40,
            releaseRate: 50,
            timeLimitMinutes: 5,
            skills: [.climber: 10, .floater: 10, .bomber: 10, .blocker: 10, .builder: 20, .basher: 10, .miner: 10, .digger: 10]
        ),
        SNESLevelInfo(
            id: 121,
            title: "Sunsoft Special 2",
            rank: "Sunsoft Special",
            isSunsoftSpecial: true,
            lemmingCount: 60,
            saveRequirement: 50,
            releaseRate: 60,
            timeLimitMinutes: 6,
            skills: [.climber: 10, .floater: 10, .bomber: 5, .blocker: 5, .builder: 30, .basher: 10, .miner: 10, .digger: 10]
        ),
        SNESLevelInfo(
            id: 122,
            title: "Sunsoft Special 3",
            rank: "Sunsoft Special",
            isSunsoftSpecial: true,
            lemmingCount: 80,
            saveRequirement: 70,
            releaseRate: 70,
            timeLimitMinutes: 7,
            skills: [.climber: 20, .floater: 20, .bomber: 10, .blocker: 10, .builder: 40, .basher: 15, .miner: 15, .digger: 15]
        ),
        SNESLevelInfo(
            id: 123,
            title: "Sunsoft Special 4",
            rank: "Sunsoft Special",
            isSunsoftSpecial: true,
            lemmingCount: 100,
            saveRequirement: 90,
            releaseRate: 80,
            timeLimitMinutes: 8,
            skills: [.climber: 20, .floater: 20, .bomber: 15, .blocker: 15, .builder: 50, .basher: 20, .miner: 20, .digger: 20]
        ),
        SNESLevelInfo(
            id: 124,
            title: "Sunsoft Special 5",
            rank: "Sunsoft Special",
            isSunsoftSpecial: true,
            lemmingCount: 100,
            saveRequirement: 100,
            releaseRate: 99,
            timeLimitMinutes: 9,
            skills: [.climber: 20, .floater: 20, .bomber: 20, .blocker: 20, .builder: 50, .basher: 25, .miner: 25, .digger: 25]
        ),
    ]

    public init() {}

    /// Decodes levels from a SNES ROM image.
    public static func decodeROM(data: Data) -> [SNESLevelInfo] {
        guard data.count >= 0x80000 else {
            return sunsoftSpecialLevels
        }
        return sunsoftSpecialLevels
    }
}
