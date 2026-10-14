import Foundation

/// Experimental Classic sequence. Results never enter verified canon progress.
public struct Lemmings2ClassicCampaign: Sendable {
    public struct Entry: Sendable {
        public let number: Int
        public let level: Lemmings2Level
    }
    public let entries: [Entry]
    public private(set) var index: Int
    public private(set) var population = 60
    public private(set) var completed: [Int: Int] = [:]
    public struct Progress: Codable, Equatable, Sendable {
        public let version: Int
        public let index: Int
        public let population: Int
        public let completed: [Int: Int]
        public init(version: Int = 3, index: Int, population: Int, completed: [Int: Int]) {
            self.version = version; self.index = index; self.population = population; self.completed = completed
        }
    }
    public var progress: Progress { .init(index: index, population: population, completed: completed) }
    public mutating func restore(_ progress: Progress) throws {
        guard progress.version == 3, entries.indices.contains(progress.index), (1...60).contains(progress.population),
              progress.completed.allSatisfy({ entries.indices.contains($0.key) && (1...60).contains($0.value) }) else {
            throw SequelDataError.invalid("Invalid Classic preview progress.")
        }
        index = progress.index; population = progress.population; completed = progress.completed
    }

    public init(root: URL, startingAt: Int = 0) throws {
        guard (0..<10).contains(startingAt) else {
            throw SequelDataError.invalid("Choose a Classic level from 1 to 10.")
        }
        entries = try (0..<10).map { number in
            let path = String(format: "LEVELS/LEVEL%03d.DAT", number)
            let level = try Lemmings2Level(data: Data(contentsOf: root.appendingPathComponent(path)))
            guard level.style == 0 else { throw SequelDataError.invalid("Unexpected tribe in the Classic sequence.") }
            return Entry(number: number, level: level)
        }
        index = startingAt
    }

    public mutating func select(_ index: Int) throws {
        guard entries.indices.contains(index) else { throw SequelDataError.invalid("Unknown Classic level.") }
        self.index = index; population = 60
    }

    /// A direct start uses 60. Sequential play carries only survivors forward.
    @discardableResult public mutating func record(_ game: Lemmings2Runtime) -> Bool {
        guard game.didWin, game.configuration.total == population,
              game.configuration.levelFingerprint == entries[index].level.fingerprint else { return false }
        completed[index] = max(completed[index] ?? 0, game.saved)
        return true
    }
    @discardableResult public mutating func advance(after game: Lemmings2Runtime) -> Bool {
        guard index + 1 < entries.count, record(game) else { return false }
        population = game.saved
        index += 1
        return true
    }
}
