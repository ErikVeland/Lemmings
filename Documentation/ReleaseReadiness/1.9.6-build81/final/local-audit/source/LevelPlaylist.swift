import Foundation

/// Validation failures for saved playlists and active level sequences.
public enum LevelPlaylistError: Error, Equatable, LocalizedError, Sendable {
    case invalidEntry
    case invalidName
    case duplicateEntry
    case tooManyEntries
    case invalidIndex
    case invalidPool
    case emptyPool
    case invalidSequence

    public var errorDescription: String? {
        switch self {
        case .invalidEntry:
            "The saved level reference is invalid."
        case .invalidName:
            "The playlist name is invalid."
        case .duplicateEntry:
            "The playlist already contains this level."
        case .tooManyEntries:
            "The playlist contains too many levels."
        case .invalidIndex:
            "The playlist position is invalid."
        case .invalidPool:
            "The level pool is invalid."
        case .emptyPool:
            "The level pool has no eligible levels."
        case .invalidSequence:
            "The saved level sequence is invalid."
        }
    }
}

/// A stable level reference with enough text to identify a missing item.
public struct LevelPlaylistEntry: Codable, Equatable, Hashable, Sendable, Identifiable {
    public static let maximumTextBytes = 4_096

    public let id: UUID
    public let identity: LevelCatalogueIdentity
    public let catalogueRevision: String
    public let sourceRevision: String
    public let packNameSnapshot: String
    public let levelNameSnapshot: String
    public let levelNumberSnapshot: Int

    public init(
        id: UUID = UUID(),
        identity: LevelCatalogueIdentity,
        catalogueRevision: String,
        sourceRevision: String,
        packNameSnapshot: String,
        levelNameSnapshot: String,
        levelNumberSnapshot: Int
    ) throws {
        let packName = packNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        let levelName = levelNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.valid(identity.packID), Self.valid(identity.levelID),
              Self.valid(catalogueRevision), Self.valid(sourceRevision),
              Self.valid(packName), Self.valid(levelName),
              (1...100_000).contains(levelNumberSnapshot) else {
            throw LevelPlaylistError.invalidEntry
        }
        self.id = id
        self.identity = identity
        self.catalogueRevision = catalogueRevision
        self.sourceRevision = sourceRevision
        self.packNameSnapshot = packName
        self.levelNameSnapshot = levelName
        self.levelNumberSnapshot = levelNumberSnapshot
    }

    private enum CodingKeys: String, CodingKey {
        case id, identity, catalogueRevision, sourceRevision
        case packNameSnapshot, levelNameSnapshot, levelNumberSnapshot
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: values.decode(UUID.self, forKey: .id),
            identity: values.decode(LevelCatalogueIdentity.self, forKey: .identity),
            catalogueRevision: values.decode(String.self, forKey: .catalogueRevision),
            sourceRevision: values.decode(String.self, forKey: .sourceRevision),
            packNameSnapshot: values.decode(String.self, forKey: .packNameSnapshot),
            levelNameSnapshot: values.decode(String.self, forKey: .levelNameSnapshot),
            levelNumberSnapshot: values.decode(Int.self, forKey: .levelNumberSnapshot))
    }

    private static func valid(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= maximumTextBytes
    }
}

/// A player-defined, ordered set of levels.
public struct LevelPlaylist: Codable, Equatable, Sendable, Identifiable {
    public static let maximumEntries = 10_000
    public static let maximumNameBytes = 256

    public let id: UUID
    public private(set) var name: String
    public private(set) var entries: [LevelPlaylistEntry]
    public let createdAt: Date
    public private(set) var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        entries: [LevelPlaylistEntry] = [],
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) throws {
        let normalisedName = try Self.validatedName(name)
        let modificationDate = updatedAt ?? createdAt
        guard entries.count <= Self.maximumEntries else {
            throw LevelPlaylistError.tooManyEntries
        }
        guard Self.hasUniqueEntries(entries), Self.valid(createdAt),
              Self.valid(modificationDate), modificationDate >= createdAt else {
            throw LevelPlaylistError.invalidEntry
        }
        self.id = id
        self.name = normalisedName
        self.entries = entries
        self.createdAt = createdAt
        self.updatedAt = modificationDate
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, entries, createdAt, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: values.decode(UUID.self, forKey: .id),
            name: values.decode(String.self, forKey: .name),
            entries: values.decode([LevelPlaylistEntry].self, forKey: .entries),
            createdAt: values.decode(Date.self, forKey: .createdAt),
            updatedAt: values.decode(Date.self, forKey: .updatedAt))
    }

    /// Adds a unique level at the requested final position.
    public mutating func add(
        _ entry: LevelPlaylistEntry,
        at index: Int? = nil,
        updatedAt: Date = Date()
    ) throws {
        guard entries.count < Self.maximumEntries else {
            throw LevelPlaylistError.tooManyEntries
        }
        guard !entries.contains(where: {
            $0.id == entry.id || $0.identity == entry.identity
        }) else {
            throw LevelPlaylistError.duplicateEntry
        }
        let destination = index ?? entries.endIndex
        guard (0...entries.count).contains(destination) else {
            throw LevelPlaylistError.invalidIndex
        }
        try validateUpdateDate(updatedAt)
        entries.insert(entry, at: destination)
        self.updatedAt = updatedAt
    }

    /// Removes an entry without changing the other entries' order.
    @discardableResult
    public mutating func remove(
        id: UUID,
        updatedAt: Date = Date()
    ) throws -> LevelPlaylistEntry? {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
        try validateUpdateDate(updatedAt)
        self.updatedAt = updatedAt
        return entries.remove(at: index)
    }

    /// Moves one entry to a final zero-based position.
    @discardableResult
    public mutating func move(
        id: UUID,
        to destination: Int,
        updatedAt: Date = Date()
    ) throws -> Bool {
        guard let source = entries.firstIndex(where: { $0.id == id }) else { return false }
        guard entries.indices.contains(destination) else {
            throw LevelPlaylistError.invalidIndex
        }
        guard source != destination else { return false }
        try validateUpdateDate(updatedAt)
        let entry = entries.remove(at: source)
        entries.insert(entry, at: destination)
        self.updatedAt = updatedAt
        return true
    }

    /// Changes the player-facing name without changing its level order.
    @discardableResult
    public mutating func rename(
        _ name: String,
        updatedAt: Date = Date()
    ) throws -> Bool {
        let normalisedName = try Self.validatedName(name)
        guard normalisedName != self.name else { return false }
        try validateUpdateDate(updatedAt)
        self.name = normalisedName
        self.updatedAt = updatedAt
        return true
    }

    /// Creates an editable playlist from at most ten distinct random levels.
    public static func randomTen(
        id: UUID = UUID(),
        name: String,
        candidates: [LevelPlaylistEntry],
        seed: UInt64,
        createdAt: Date = Date()
    ) throws -> Self {
        let ordered = try LevelShuffleAlgorithm.splitMix64FisherYatesV1
            .ordered(candidates, seed: seed)
        return try Self(
            id: id,
            name: name,
            entries: Array(ordered.prefix(10)),
            createdAt: createdAt)
    }

    private static func validatedName(_ value: String) throws -> String {
        let normalised = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalised.isEmpty, normalised.utf8.count <= maximumNameBytes else {
            throw LevelPlaylistError.invalidName
        }
        return normalised
    }

    private static func valid(_ date: Date) -> Bool {
        date.timeIntervalSinceReferenceDate.isFinite
    }

    private static func hasUniqueEntries(_ entries: [LevelPlaylistEntry]) -> Bool {
        Set(entries.map(\.id)).count == entries.count
            && Set(entries.map(\.identity)).count == entries.count
    }

    private func validateUpdateDate(_ date: Date) throws {
        guard Self.valid(date), date >= createdAt, date >= updatedAt else {
            throw LevelPlaylistError.invalidEntry
        }
    }
}

/// Identifies and describes the candidate set used for one generated sequence.
public struct LevelPool: Codable, Equatable, Hashable, Sendable, Identifiable {
    public static let maximumTextBytes = 4_096

    public let id: String
    public let summary: String

    public init(id: String, summary: String) throws {
        let normalisedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalisedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalisedID.isEmpty, !normalisedSummary.isEmpty,
              normalisedID.utf8.count <= Self.maximumTextBytes,
              normalisedSummary.utf8.count <= Self.maximumTextBytes else {
            throw LevelPlaylistError.invalidPool
        }
        self.id = normalisedID
        self.summary = normalisedSummary
    }

    private enum CodingKeys: String, CodingKey { case id, summary }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: values.decode(String.self, forKey: .id),
            summary: values.decode(String.self, forKey: .summary))
    }
}

/// The fixed shuffle implementation used by saved seeds.
public enum LevelShuffleAlgorithm: String, Codable, CaseIterable, Sendable {
    case splitMix64FisherYatesV1

    /// Returns one canonical, deterministic permutation.
    public func ordered(
        _ candidates: [LevelPlaylistEntry],
        seed: UInt64
    ) throws -> [LevelPlaylistEntry] {
        guard !candidates.isEmpty else { throw LevelPlaylistError.emptyPool }
        guard candidates.count <= LevelPlaylist.maximumEntries else {
            throw LevelPlaylistError.tooManyEntries
        }
        guard Set(candidates.map(\.identity)).count == candidates.count else {
            throw LevelPlaylistError.duplicateEntry
        }
        var ordered = candidates.sorted(by: Self.precedes)
        var generator = SplitMix64(seed: seed)
        guard ordered.count > 1 else { return ordered }
        for upperIndex in stride(from: ordered.count - 1, through: 1, by: -1) {
            let lowerIndex = generator.next(upperBound: upperIndex + 1)
            if lowerIndex != upperIndex {
                ordered.swapAt(lowerIndex, upperIndex)
            }
        }
        return ordered
    }

    private static func precedes(
        _ lhs: LevelPlaylistEntry,
        _ rhs: LevelPlaylistEntry
    ) -> Bool {
        let left = lhs.identity
        let right = rhs.identity
        if left.engine != right.engine {
            return utf8Precedes(left.engine.rawValue, right.engine.rawValue)
        }
        if left.packID != right.packID {
            return utf8Precedes(left.packID, right.packID)
        }
        return utf8Precedes(left.levelID, right.levelID)
    }

    private static func utf8Precedes(_ lhs: String, _ rhs: String) -> Bool {
        lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
    }
}

/// Why an immutable level sequence was created.
public enum LevelSequenceSource: Codable, Equatable, Sendable {
    case playlist(UUID)
    case randomTen
    case shuffleAll
}

/// A fixed run order. Later playlist edits do not change this snapshot.
public struct LevelSequenceRun: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let source: LevelSequenceSource
    public let pool: LevelPool
    public let entries: [LevelPlaylistEntry]
    public private(set) var currentIndex: Int
    public let seed: UInt64?
    public let algorithm: LevelShuffleAlgorithm?
    public let createdAt: Date

    public var currentEntry: LevelPlaylistEntry { entries[currentIndex] }
    public var isAtEnd: Bool { currentIndex == entries.count - 1 }

    public init(
        id: UUID = UUID(),
        source: LevelSequenceSource,
        pool: LevelPool,
        entries: [LevelPlaylistEntry],
        currentIndex: Int = 0,
        seed: UInt64? = nil,
        algorithm: LevelShuffleAlgorithm? = nil,
        createdAt: Date = Date()
    ) throws {
        guard !entries.isEmpty else { throw LevelPlaylistError.emptyPool }
        guard entries.count <= LevelPlaylist.maximumEntries else {
            throw LevelPlaylistError.tooManyEntries
        }
        guard entries.indices.contains(currentIndex),
              Set(entries.map(\.id)).count == entries.count,
              Set(entries.map(\.identity)).count == entries.count,
              createdAt.timeIntervalSinceReferenceDate.isFinite,
              (seed == nil) == (algorithm == nil) else {
            throw LevelPlaylistError.invalidSequence
        }
        switch source {
        case .randomTen:
            guard entries.count <= 10, seed != nil, algorithm != nil else {
                throw LevelPlaylistError.invalidSequence
            }
        case .shuffleAll:
            guard seed != nil, algorithm != nil else {
                throw LevelPlaylistError.invalidSequence
            }
        case .playlist:
            break
        }
        self.id = id
        self.source = source
        self.pool = pool
        self.entries = entries
        self.currentIndex = currentIndex
        self.seed = seed
        self.algorithm = algorithm
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, source, pool, entries, currentIndex, seed, algorithm, createdAt
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: values.decode(UUID.self, forKey: .id),
            source: values.decode(LevelSequenceSource.self, forKey: .source),
            pool: values.decode(LevelPool.self, forKey: .pool),
            entries: values.decode([LevelPlaylistEntry].self, forKey: .entries),
            currentIndex: values.decode(Int.self, forKey: .currentIndex),
            seed: values.decodeIfPresent(UInt64.self, forKey: .seed),
            algorithm: values.decodeIfPresent(LevelShuffleAlgorithm.self, forKey: .algorithm),
            createdAt: values.decode(Date.self, forKey: .createdAt))
    }

    /// Takes a snapshot of a playlist, with optional deterministic shuffling.
    public static func playlist(
        _ playlist: LevelPlaylist,
        pool: LevelPool,
        seed: UInt64? = nil,
        id: UUID = UUID(),
        createdAt: Date = Date()
    ) throws -> Self {
        let algorithm = seed.map { _ in LevelShuffleAlgorithm.splitMix64FisherYatesV1 }
        let entries = try seed.map {
            try LevelShuffleAlgorithm.splitMix64FisherYatesV1
                .ordered(playlist.entries, seed: $0)
        } ?? playlist.entries
        return try Self(
            id: id,
            source: .playlist(playlist.id),
            pool: pool,
            entries: entries,
            seed: seed,
            algorithm: algorithm,
            createdAt: createdAt)
    }

    /// Creates a deterministic sequence with at most ten distinct entries.
    public static func randomTen(
        from candidates: [LevelPlaylistEntry],
        pool: LevelPool,
        seed: UInt64,
        id: UUID = UUID(),
        createdAt: Date = Date()
    ) throws -> Self {
        let algorithm = LevelShuffleAlgorithm.splitMix64FisherYatesV1
        let entries = try algorithm.ordered(candidates, seed: seed)
        return try Self(
            id: id,
            source: .randomTen,
            pool: pool,
            entries: Array(entries.prefix(10)),
            seed: seed,
            algorithm: algorithm,
            createdAt: createdAt)
    }

    /// Creates a deterministic sequence containing the full candidate pool.
    public static func fullShuffle(
        from candidates: [LevelPlaylistEntry],
        pool: LevelPool,
        seed: UInt64,
        id: UUID = UUID(),
        createdAt: Date = Date()
    ) throws -> Self {
        let algorithm = LevelShuffleAlgorithm.splitMix64FisherYatesV1
        return try Self(
            id: id,
            source: .shuffleAll,
            pool: pool,
            entries: algorithm.ordered(candidates, seed: seed),
            seed: seed,
            algorithm: algorithm,
            createdAt: createdAt)
    }

    /// Moves to the next entry. The final entry remains current at exhaustion.
    @discardableResult
    public mutating func advance() -> Bool {
        guard currentIndex + 1 < entries.count else { return false }
        currentIndex += 1
        return true
    }
}

private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    mutating func next(upperBound: Int) -> Int {
        precondition(upperBound > 0)
        let bound = UInt64(upperBound)
        let threshold = (0 &- bound) % bound
        while true {
            let value = next()
            if value >= threshold { return Int(value % bound) }
        }
    }
}
