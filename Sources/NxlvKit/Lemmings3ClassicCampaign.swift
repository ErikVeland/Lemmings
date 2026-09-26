import Foundation

/// Preview progress is separate from original saves and verified achievements.
public struct Lemmings3ClassicCampaign: Sendable {
    public enum Tribe: Int, CaseIterable, Codable, Sendable {
        case classic = 1, shadow = 2, egyptian = 3
        public var title: String { switch self { case .classic: "Classic"; case .shadow: "Shadow"; case .egyptian: "Egyptian" } }
        public var firstLevel: Int { (rawValue - 1) * 100 + 1 }
        public var spriteStyle: Int { switch self { case .classic: 4; case .shadow: 10; case .egyptian: 5 } }
    }
    public let tribe: Tribe
    public let levels: [Lemmings3Level]
    public private(set) var index = 0
    public private(set) var population = 20
    public private(set) var completed: [Int: Int] = [:]
    public struct Progress: Codable, Equatable, Sendable {
        public var version = 1
        public var index: Int
        public var population: Int
        public var completed: [Int: Int]
        public var tribe: Tribe?
        public init(index: Int, population: Int, completed: [Int: Int], tribe: Tribe? = nil) {
            self.index = index; self.population = population; self.completed = completed
            self.tribe = tribe
        }
    }
    public var progress: Progress { .init(index: index, population: population, completed: completed, tribe: tribe) }
    public init(root: URL, tribe: Tribe = .classic) throws {
        self.tribe = tribe
        levels = try (tribe.firstLevel..<(tribe.firstLevel + 30)).map { number in
            let level = try Lemmings3Level(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/LEVEL%03d.DAT", number))))
            guard level.style == tribe.rawValue, level.lemmingStyle == tribe.spriteStyle else { throw SequelDataError.invalid("Unexpected style in the Chronicles \(tribe.title) sequence.") }
            return level
        }
    }
    public mutating func restore(_ progress: Progress) throws {
        guard progress.version == 1, (progress.tribe ?? .classic) == tribe, levels.indices.contains(progress.index),
              (1...maximumPopulation(before: progress.index)).contains(progress.population),
              progress.completed.allSatisfy({ levels.indices.contains($0.key) && (1...maximumPopulation(before: $0.key + 1)).contains($0.value) }) else {
            throw SequelDataError.invalid("Invalid Chronicles preview progress.")
        }
        index = progress.index; population = progress.population; completed = progress.completed
    }
    private func maximumPopulation(before index: Int) -> Int {
        20 + levels.prefix(index).reduce(0) { $0 + $1.extraLemmings }
    }
    public mutating func select(_ index: Int) throws {
        guard levels.indices.contains(index) else { throw SequelDataError.invalid("Unknown Chronicles level.") }
        self.index = index; population = 20
    }
    @discardableResult public mutating func record(_ game: Lemmings3Runtime) -> Bool {
        guard game.isComplete, game.saved > 0, game.configuration.total == population,
              game.configuration.sourceLevelReference == levels[index].permanentObjectsReference else { return false }
        completed[index] = max(completed[index] ?? 0, game.survivors)
        return true
    }
    /// A skip passes over an unbeaten level that is not the tribe's last.
    public var canSkipLevel: Bool { levels.indices.contains(index + 1) && completed[index] == nil }

    /// Moves to the next level with the same population. The caller spends the skip.
    @discardableResult public mutating func skipLevel() -> Bool {
        guard canSkipLevel else { return false }
        index += 1
        return true
    }
    @discardableResult public mutating func advance(after game: Lemmings3Runtime) -> Bool {
        guard levels.indices.contains(index + 1), record(game) else { return false }
        population = game.survivors; index += 1; return true
    }
}
