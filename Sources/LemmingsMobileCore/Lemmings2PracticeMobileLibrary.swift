import Foundation
import NxlvKit

/// One isolated training map, including its exact eight-slot panel.
public final class Lemmings2PracticeMobileLibrary: MobileGameLibrary {
    public let source: Lemmings2MobileLibrary
    public let choice: Int
    public let skills: [Lemmings2Runtime.Skill]
    public let displayName = L10n.text("Practice")
    public let levels: [MobileLevelSummary]

    public init(source: Lemmings2MobileLibrary, choice: Int, skills: [Lemmings2Runtime.Skill]) throws {
        let content = try source.loadPractice(at: choice, skills: skills)
        self.source = source; self.choice = choice; self.skills = skills
        levels = [.init(index: 0, rank: displayName, number: choice + 1, title: content.summary.title)]
    }
    public static func restoring(_ identifier: String, source: Lemmings2MobileLibrary) throws -> Lemmings2PracticeMobileLibrary {
        let parts = identifier.split(separator: "/")
        guard parts.count == 4, parts[0] == "lemmings2", parts[1] == "practice", let choice = Int(parts[2]) else {
            throw MobileSessionError.changedLevel
        }
        let values = parts[3].split(separator: "-").compactMap { Int($0).flatMap(Lemmings2Runtime.Skill.init(rawValue:)) }
        return try .init(source: source, choice: choice, skills: values)
    }
    public func levelKey(at index: Int) -> String { "lemmings2/practice/\(choice)/" + skills.map { String($0.rawValue) }.joined(separator: "-") }
    public func checkpointLevelIdentifier(at index: Int) throws -> String? { levelKey(at: index) }
    public func loadLevel(at index: Int) throws -> MobileLevelContent {
        guard index == 0 else { throw MobileSessionError.changedLevel }
        let content = try source.loadPractice(at: choice, skills: skills)
        return .init(summary: levels[0], session: content.session)
    }
}
