import Foundation

public enum NxlvSkill: String, CaseIterable, Sendable, Hashable {
    case walker
    case jumper
    case shimmier
    case slider
    case climber
    case swimmer
    case floater
    case glider
    case disarmer
    case bomber
    case stoner
    case blocker
    case platformer
    case builder
    case stacker
    case laserer
    case basher
    case fencer
    case miner
    case digger
    case cloner

    public init?(keyword: String) {
        self.init(rawValue: keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    public var keyword: String { rawValue.uppercased() }
}

public enum NxlvSkillQuantity: Sendable, Equatable {
    case finite(Int)
    case infinite

    /// NeoLemmix represents an infinite supply internally as 100. This value
    /// is provided only for callers that still use the original integer map.
    public var legacyCount: Int {
        switch self {
        case let .finite(count): count
        case .infinite: 100
        }
    }
}

public enum NxlvDirection: String, Sendable, Equatable {
    case left
    case right

    public init?(keyword: String) {
        self.init(rawValue: keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}

public enum NxlvLemmingTrait: String, CaseIterable, Sendable, Hashable {
    case shimmier
    case slider
    case climber
    case swimmer
    case floater
    case glider
    case disarmer
    case blocker
    case zombie
    case neutral

    public var keyword: String { rawValue.uppercased() }
}

public enum NxlvTimeLimit: Sendable, Equatable {
    case seconds(Int)
    case infinite
}

public enum NxlvScreenStart: Sendable, Equatable {
    case automatic
    case position(x: Int, y: Int)
}

public enum NxlvTalismanColor: String, Sendable, Equatable {
    case bronze
    case silver
    case gold

    public init?(keyword: String) {
        self.init(rawValue: keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}

public enum NxlvDependencyKind: String, Sendable, Hashable {
    case theme
    case style
    case background
    case music
}

public struct NxlvDependency: Sendable, Hashable {
    public let kind: NxlvDependencyKind
    public let identifier: String
    public let sourceLine: Int?

    public init(kind: NxlvDependencyKind, identifier: String, sourceLine: Int? = nil) {
        self.kind = kind
        self.identifier = identifier
        self.sourceLine = sourceLine
    }
}

public struct NxlvDependencyScan: Sendable {
    public let dependencies: [NxlvDependency]

    public init(dependencies: [NxlvDependency]) {
        var seen: Set<String> = []
        self.dependencies = dependencies.filter { dependency in
            let identity = "\(dependency.kind.rawValue):\(dependency.identifier.lowercased())"
            return seen.insert(identity).inserted
        }
    }

    public func identifiers(for kind: NxlvDependencyKind) -> [String] {
        dependencies.filter { $0.kind == kind }.map(\.identifier)
    }

    public var themes: [String] { identifiers(for: .theme) }
    public var styles: [String] { identifiers(for: .style) }
    public var backgrounds: [String] { identifiers(for: .background) }
    public var music: [String] { identifiers(for: .music) }

    /// Returns dependencies that are not present in a caller-provided index.
    /// Identifiers are compared case-insensitively.
    public func missing(
        from available: [NxlvDependencyKind: Set<String>]
    ) -> [NxlvDependency] {
        let normalized = available.mapValues { identifiers in
            Set(identifiers.map { $0.lowercased() })
        }
        return dependencies.filter { dependency in
            !(normalized[dependency.kind] ?? []).contains(dependency.identifier.lowercased())
        }
    }

    public func missingDiagnostics(
        from available: [NxlvDependencyKind: Set<String>]
    ) -> [NxlvDiagnostic] {
        missing(from: available).map { dependency in
            NxlvDiagnostic(
                severity: .warning,
                code: .missingDependency,
                message: "Missing \(dependency.kind.rawValue) dependency '\(dependency.identifier)'.",
                line: dependency.sourceLine
            )
        }
    }
}
