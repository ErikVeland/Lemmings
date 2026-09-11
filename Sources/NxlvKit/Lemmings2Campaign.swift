import Foundation

/// Twelve independent tribes. Replays can improve a tribe's saved population.
/// Native progress stays separate from verified canon achievements.
public struct Lemmings2Campaign: Sendable {
    public static let tribeNames = ["Classic", "Beach", "Cavelems", "Circus", "Egyptian", "Highland",
                                   "Medieval", "Outdoor", "Polar", "Shadow", "Space", "Sports"]
    public static let styleNames = ["CLASSIC", "BEACH", "CAVEMAN", "CIRCUS", "EGYPTIAN", "HIGHLAND",
                                   "MEDIEVAL", "OUTDOOR", "POLAR", "SHADOW", "SPACE", "SPORTS"]
    public enum Medal: Int, Codable, Comparable, Sendable {
        case none, bronze, silver, gold
        public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
        public var name: String { ["None", "Bronze", "Silver", "Gold"][rawValue] }
    }
    public struct Result: Codable, Equatable, Sendable {
        public let startingPopulation: Int
        public let saved: Int
        public let medal: Medal
        public let levelFingerprint: String
        public init(startingPopulation: Int, saved: Int, medal: Medal, levelFingerprint: String) {
            self.startingPopulation = startingPopulation; self.saved = saved
            self.medal = medal; self.levelFingerprint = levelFingerprint
        }
    }
    public struct Progress: Codable, Equatable, Sendable {
        public let version: Int
        public let tribe: Int
        public let level: Int
        public let results: [Int: Result]
        public init(version: Int = 1, tribe: Int, level: Int, results: [Int: Result]) {
            self.version = version; self.tribe = tribe; self.level = level; self.results = results
        }
    }
    public let levels: [Lemmings2Level]
    // Storage IDs follow the data files. New players begin with Beach.
    public private(set) var tribe = 1
    public private(set) var level = 0
    public private(set) var results: [Int: Result] = [:]
    public var current: Lemmings2Level { levels[tribe * 10 + level] }
    public var population: Int { level == 0 ? 60 : results[tribe * 10 + level - 1]?.saved ?? 0 }
    public var progress: Progress { .init(tribe: tribe, level: level, results: results) }
    public var isComplete: Bool { (0..<12).allSatisfy { tribeMedal($0) != .none } }
    public var hasGoldenTalisman: Bool { (0..<12).allSatisfy { tribeMedal($0) == .gold } }

    /// The ark ending requires a golden talisman and at least thirty survivors
    /// from each tribe. Completing the levels alone still permits replays.
    public var canLaunchArk: Bool {
        hasGoldenTalisman && (0..<12).allSatisfy { (results[$0*10+9]?.saved ?? 0) >= 30 }
    }

    public init(root: URL) throws {
        levels = try (0..<120).map { number in
            let data = try Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/LEVEL%03d.DAT", number)))
            let level = try Lemmings2Level(data: data)
            guard level.style == number / 10 else { throw SequelDataError.invalid("Unexpected L2 tribe ordering.") }
            return level
        }
    }
    public func unlockedLevel(in tribe: Int) -> Int {
        guard (0..<12).contains(tribe) else { return 0 }
        return (0..<9).first { results[tribe * 10 + $0] == nil } ?? 9
    }
    public func tribeMedal(_ tribe: Int) -> Medal {
        guard (0..<12).contains(tribe) else { return .none }
        return (0..<10).map { results[tribe * 10 + $0]?.medal ?? .none }.min() ?? .none
    }
    public mutating func select(tribe: Int, level: Int? = nil) throws {
        guard (0..<12).contains(tribe) else { throw SequelDataError.invalid("Unknown L2 tribe.") }
        let selected = level ?? unlockedLevel(in: tribe)
        guard (0...unlockedLevel(in: tribe)).contains(selected) else {
            throw SequelDataError.invalid("Rescue lemmings from the preceding level first.")
        }
        self.tribe = tribe; self.level = selected
    }
    /// MEDALS.GAL subtracts the level's allowed losses, then compares the
    /// excess with zero and half the starting population. The tribe keeps
    /// its lowest medal (L2.RKO 0ead).
    public static func medal(saved: Int, total: Int, allowedLosses: Int) -> Medal {
        guard saved > 0, saved <= total else { return .none }
        let excess = total - saved - allowedLosses
        if excess <= 0 { return .gold }
        return excess > total / 2 ? .bronze : .silver
    }
    @discardableResult public mutating func record(_ game: Lemmings2Runtime) -> Bool {
        guard game.didWin, game.configuration.total == population,
              game.configuration.levelFingerprint == current.fingerprint else { return false }
        let key = tribe * 10 + level
        if game.saved > (results[key]?.saved ?? 0) {
            results[key] = Result(startingPopulation: population, saved: game.saved,
                medal: Self.medal(saved: game.saved, total: population, allowedLosses: current.allowedLossesForGold),
                levelFingerprint: current.fingerprint)
        }
        return true
    }
    @discardableResult public mutating func advance(after game: Lemmings2Runtime) -> Bool {
        guard record(game), level < 9 else { return false }
        level += 1; return true
    }
    public mutating func restore(_ progress: Progress) throws {
        guard progress.version == 1, (0..<12).contains(progress.tribe), (0..<10).contains(progress.level) else {
            throw SequelDataError.invalid("Invalid L2 campaign save version or selection.")
        }
        for (key, result) in progress.results {
            guard levels.indices.contains(key), (1...60).contains(result.startingPopulation),
                  (1...result.startingPopulation).contains(result.saved), result.levelFingerprint == levels[key].fingerprint,
                  result.medal == Self.medal(saved: result.saved, total: result.startingPopulation,
                                             allowedLosses: levels[key].allowedLossesForGold),
                  result.startingPopulation <= (key % 10 == 0 ? 60 : progress.results[key - 1]?.saved ?? 0) else {
                throw SequelDataError.invalid("Invalid or mismatched L2 campaign result.")
            }
        }
        var proposed = self
        proposed.results = progress.results
        try proposed.select(tribe: progress.tribe, level: progress.level)
        self = proposed
    }
}
