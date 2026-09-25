import Foundation

/// The engine that owns a level's rules and saved state.
public enum LevelSourceEngine: String, Codable, CaseIterable, Sendable {
    case classic
    case lemmings2
    case lemmings3

    public var displayName: String {
        switch self {
        case .classic: "Classic"
        case .lemmings2: "Lemmings 2"
        case .lemmings3: "Lemmings 3"
        }
    }
}

/// The release boundary shown beside content in the level browser.
public enum LevelContentStatus: String, Codable, CaseIterable, Sendable {
    case complete
    case playable
    case preview
    case beta
    case unverified

    public var displayName: String { rawValue.capitalized }
}

/// Why a catalogue entry can or cannot start.
public enum LevelAvailability: String, Codable, CaseIterable, Sendable {
    case available
    case locked
    case unavailable

    public var canStart: Bool { self == .available }

    public var displayName: String {
        switch self {
        case .available: "Available"
        case .locked: "Locked"
        case .unavailable: "Unavailable"
        }
    }
}

/// A stable level address. File formats and array positions are not identities.
public struct LevelCatalogueIdentity: Hashable, Codable, Sendable {
    public let engine: LevelSourceEngine
    public let packID: String
    public let levelID: String

    public init(engine: LevelSourceEngine, packID: String, levelID: String) {
        self.engine = engine
        self.packID = packID
        self.levelID = levelID
    }
}

/// One level that the app can resolve before it starts an engine.
public struct LevelCatalogueEntry: Hashable, Codable, Sendable {
    public let identity: LevelCatalogueIdentity
    public let packName: String
    public let levelName: String
    public let number: Int
    public let status: LevelContentStatus
    public let availability: LevelAvailability
    public var isAvailable: Bool { availability.canStart }

    public init(
        identity: LevelCatalogueIdentity,
        packName: String,
        levelName: String,
        number: Int,
        status: LevelContentStatus,
        availability: LevelAvailability = .available
    ) {
        self.identity = identity
        self.packName = packName
        self.levelName = levelName
        self.number = max(1, number)
        self.status = status
        self.availability = availability
    }

    public init(
        identity: LevelCatalogueIdentity,
        packName: String,
        levelName: String,
        number: Int,
        status: LevelContentStatus,
        isAvailable: Bool
    ) {
        self.init(
            identity: identity,
            packName: packName,
            levelName: levelName,
            number: number,
            status: status,
            availability: isAvailable ? .available : .unavailable)
    }
}

/// A browser group for one release or fan pack.
public struct LevelCataloguePack: Hashable, Codable, Sendable {
    public let engine: LevelSourceEngine
    public let id: String
    public let name: String
    public let status: LevelContentStatus
    public let levels: [LevelCatalogueEntry]

    public init(
        engine: LevelSourceEngine,
        id: String,
        name: String,
        status: LevelContentStatus,
        levels: [LevelCatalogueEntry]
    ) {
        self.engine = engine
        self.id = id
        self.name = name
        self.status = status
        self.levels = levels.filter {
            $0.identity.engine == engine && $0.identity.packID == id
        }
    }

    public var availableLevelCount: Int { levels.count(where: \.isAvailable) }
}

/// The typed content boundary used by the level browser.
public struct LevelCatalogue: Codable, Sendable {
    public let revision: String
    public let packs: [LevelCataloguePack]

    public init(revision: String, packs: [LevelCataloguePack]) {
        self.revision = revision
        self.packs = packs
    }

    public func resolve(_ identity: LevelCatalogueIdentity) -> LevelCatalogueEntry? {
        packs.lazy
            .filter { $0.engine == identity.engine && $0.id == identity.packID }
            .flatMap(\.levels)
            .first { $0.identity == identity }
    }
}
