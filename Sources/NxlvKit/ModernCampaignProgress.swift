import Foundation

/// Native campaign progression. It stores outcomes only; level geometry and
/// artwork remain supplied by the imported Content catalog.
public struct ModernLevelResult: Codable, Equatable, Sendable {
    public let levelIndex: Int
    public let saved: Int
    public let required: Int
    public let didWin: Bool
    public let completedAt: Date

    public init(levelIndex: Int, saved: Int, required: Int, completedAt: Date = Date()) {
        self.levelIndex = levelIndex
        self.saved = saved
        self.required = required
        didWin = saved >= required
        self.completedAt = completedAt
    }
}

public struct ModernCampaignProgress: Codable, Equatable, Sendable {
    public private(set) var results: [Int: ModernLevelResult]

    public init(results: [Int: ModernLevelResult] = [:]) { self.results = results }

    public func isUnlocked(_ index: Int) -> Bool {
        index == 0 || results[index - 1]?.didWin == true
    }

    public func result(for index: Int) -> ModernLevelResult? { results[index] }

    public mutating func record(levelIndex: Int, saved: Int, required: Int, completedAt: Date = Date()) {
        let result = ModernLevelResult(levelIndex: levelIndex, saved: saved, required: required, completedAt: completedAt)
        if let previous = results[levelIndex], previous.didWin && !result.didWin { return }
        results[levelIndex] = result
    }

    public func encoded() throws -> Data { try JSONEncoder().encode(self) }

    public init(encoded data: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: data)
    }
}
