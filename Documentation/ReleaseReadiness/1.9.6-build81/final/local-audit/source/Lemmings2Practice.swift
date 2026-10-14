import Foundation

/// The four original training maps with a player-selected eight-skill panel.
public struct Lemmings2Practice: Sendable {
    public static let tribes = [10,6,4,8]
    public let levels: [Lemmings2Level]
    public init(root: URL) throws {
        levels = try Self.tribes.map { tribe in
            try .init(data:Data(contentsOf:root.appendingPathComponent("LEVELS/LEVEL9\(String(format:"%02d",tribe)).DAT")))
        }
    }
    public static func runtime(level: Lemmings2Level, style: Lemmings2Style,
                               masks: Lemmings2TerrainMasks, skills: [Lemmings2Runtime.Skill]) throws -> Lemmings2Runtime {
        guard skills.count == 8, Set(skills).count == 8, !skills.contains(.unused), tribes.contains(level.style) else {
            throw SequelDataError.invalid("Select eight different skills for practice.")
        }
        return try .init(level:level,style:style,masks:masks,total:60,practiceSkills:skills)
    }
}
