import Foundation

/// Stable achievement identifiers stored in the player's preferences.
public enum ClassicAchievementID: String, CaseIterable, Codable, Sendable {
    case firstRescue
    case lemmingsComplete
    case xmas1991Complete
    case ohNoComplete
    case xmas1992Complete
    case lemmings2Complete
    case holiday1993Complete
    case ohYesMoreLemmingsComplete
    case lemmings3Complete
    case holiday1994Complete
    case festiveComplete
    case trilogyComplete
    case fullCanonComplete
}

public struct ClassicAchievement: Equatable, Sendable {
    public let id: ClassicAchievementID
    public let title: String
    public let detail: String

    public init(id: ClassicAchievementID, title: String, detail: String) {
        self.id = id
        self.title = title
        self.detail = detail
    }
}

public extension ClassicAchievement {
    static let catalog: [ClassicAchievement] = [
        ClassicAchievement(
            id: .firstRescue, title: L10n.text("The First Step"),
            detail: L10n.text("Pass your first level.")),
        ClassicAchievement(
            id: .lemmingsComplete, title: L10n.text("The Original"),
            detail: L10n.text("Pass every Lemmings level in order.")),
        ClassicAchievement(
            id: .xmas1991Complete, title: L10n.text("A 1991 Christmas"),
            detail: L10n.text("Pass every Xmas Lemmings 1991 level in order.")),
        ClassicAchievement(
            id: .ohNoComplete, title: L10n.text("Oh No! No More"),
            detail: L10n.text("Pass every Oh No! More Lemmings level in order.")),
        ClassicAchievement(
            id: .xmas1992Complete, title: L10n.text("A 1992 Christmas"),
            detail: L10n.text("Pass every Xmas Lemmings 1992 level in order.")),
        ClassicAchievement(
            id: .lemmings2Complete, title: L10n.text("Twelve Tribes"),
            detail: L10n.text("Pass every Lemmings 2 level in order.")),
        ClassicAchievement(
            id: .holiday1993Complete, title: L10n.text("Holiday 1993"),
            detail: L10n.text("Pass every Holiday Lemmings 1993 level in order.")),
        ClassicAchievement(
            id: .ohYesMoreLemmingsComplete, title: L10n.text("Collector"),
            detail: L10n.text("Pass every level the other machines kept to themselves.")),
        ClassicAchievement(
            id: .lemmings3Complete, title: L10n.text("A New World"),
            detail: L10n.text("Pass every Lemmings 3 level in order.")),
        ClassicAchievement(
            id: .holiday1994Complete, title: L10n.text("Holiday 1994"),
            detail: L10n.text("Pass every Holiday Lemmings 1994 level in order.")),
        ClassicAchievement(
            id: .festiveComplete, title: L10n.text("Festive Season"),
            detail: L10n.text("Pass all four festive releases.")),
        ClassicAchievement(
            id: .trilogyComplete, title: L10n.text("The Trilogy"),
            detail: L10n.text("Complete Lemmings, Lemmings 2, and Lemmings 3.")),
        ClassicAchievement(
            id: .fullCanonComplete, title: L10n.text("Master of Lemmings"),
            detail: L10n.text("Complete the entire series from start to finish.")),
    ]
}

/// Persistent ordered-run state and unlocked achievements.
public struct ClassicAchievementProgress: Codable, Equatable, Sendable {
    public private(set) var unlocked: Set<ClassicAchievementID>
    /// The next campaign index that must be passed for each release.
    public private(set) var nextOrderedLevel: [String: Int]
    /// The next release and level required for the full-canon run. Optional
    /// fields keep saves made before this rule was added readable.
    public private(set) var canonTitleIndex: Int?
    public private(set) var canonLevelIndex: Int?

    public init(
        unlocked: Set<ClassicAchievementID> = [],
        nextOrderedLevel: [String: Int] = [:],
        canonTitleIndex: Int? = 0,
        canonLevelIndex: Int? = 0
    ) {
        self.unlocked = unlocked
        self.nextOrderedLevel = nextOrderedLevel
        self.canonTitleIndex = canonTitleIndex
        self.canonLevelIndex = canonLevelIndex
    }

    public func isUnlocked(_ id: ClassicAchievementID) -> Bool {
        unlocked.contains(id)
    }

    public func orderedLevelsPassed(for title: ClassicTitle) -> Int {
        nextOrderedLevel[title.rawValue] ?? 0
    }

    /// Records one successful level. Only the next expected level advances an
    /// ordered run. Practice jumps therefore cannot unlock completion awards.
    public mutating func recordWin(
        title: ClassicTitle, levelIndex: Int, levelCount: Int
    ) -> [ClassicAchievement] {
        var earned: [ClassicAchievement] = []
        unlock(.firstRescue, into: &earned)

        // The top award has one stricter sequence across every release. A
        // level jump or a release jump does not advance this cursor.
        let canonTitle = canonTitleIndex ?? 0
        let canonLevel = canonLevelIndex ?? 0
        if ClassicTitle.allCases.indices.contains(canonTitle),
            ClassicTitle.allCases[canonTitle] == title,
            levelIndex == canonLevel,
            canonLevel < levelCount {
            if canonLevel + 1 == levelCount {
                canonTitleIndex = canonTitle + 1
                canonLevelIndex = 0
            } else {
                canonLevelIndex = canonLevel + 1
            }
        }

        let key = title.rawValue
        let expected = nextOrderedLevel[key] ?? 0
        if levelIndex == expected, expected < levelCount {
            nextOrderedLevel[key] = expected + 1
        }

        if nextOrderedLevel[key] == levelCount, levelCount > 0 {
            unlock(Self.completionAchievement(for: title), into: &earned)
        }

        let festive: Set<ClassicAchievementID> = [
            .xmas1991Complete, .xmas1992Complete,
            .holiday1993Complete, .holiday1994Complete,
        ]
        if unlocked.isSuperset(of: festive) {
            unlock(.festiveComplete, into: &earned)
        }

        let trilogy: Set<ClassicAchievementID> = [
            .lemmingsComplete, .lemmings2Complete, .lemmings3Complete,
        ]
        if unlocked.isSuperset(of: trilogy) {
            unlock(.trilogyComplete, into: &earned)
        }

        if canonTitleIndex == ClassicTitle.allCases.count {
            unlock(.fullCanonComplete, into: &earned)
        }
        return earned
    }

    private mutating func unlock(
        _ id: ClassicAchievementID, into earned: inout [ClassicAchievement]
    ) {
        guard unlocked.insert(id).inserted,
            let achievement = ClassicAchievement.catalog.first(where: { $0.id == id })
        else { return }
        earned.append(achievement)
    }

    private static func completionAchievement(
        for title: ClassicTitle
    ) -> ClassicAchievementID {
        switch title {
        case .lemmings: return .lemmingsComplete
        case .xmasLemmings1991: return .xmas1991Complete
        case .ohNoMoreLemmings: return .ohNoComplete
        case .xmasLemmings1992: return .xmas1992Complete
        case .lemmings2TheTribes: return .lemmings2Complete
        case .holidayLemmings1993: return .holiday1993Complete
        case .ohYesMoreLemmings: return .ohYesMoreLemmingsComplete
        case .lemmings3TheChronicles: return .lemmings3Complete
        case .holidayLemmings1994: return .holiday1994Complete
        }
    }
}
