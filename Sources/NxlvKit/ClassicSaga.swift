import Foundation

/// Every Lemmings release that runs on this engine, played as one canon.
///
/// Each release is its own campaign with its own ratings, but they were made
/// as a series and are played as one. A saga chains them in release order so a
/// player can start at the beginning and continue to the end, or drop into any
/// chapter, rating or level directly.
///
/// The festive releases belong in the canon rather than beside it. They shipped
/// between the main games and use the same engine and format.

/// A release in the combined canon, in the order it appeared.
public enum ClassicTitle: String, CaseIterable, Codable, Sendable {
    case lemmings
    case xmasLemmings1991
    case ohNoMoreLemmings
    case xmasLemmings1992
    case lemmings2TheTribes
    case holidayLemmings1993
    case ohYesMoreLemmings
    case lemmings3TheChronicles
    case holidayLemmings1994

    public var displayName: String {
        switch self {
        case .lemmings: return "Lemmings"
        case .xmasLemmings1991: return "Xmas Lemmings 1991"
        case .ohNoMoreLemmings: return "Oh No! More Lemmings"
        case .xmasLemmings1992: return "Xmas Lemmings 1992"
        case .lemmings2TheTribes: return "Lemmings 2: The Tribes"
        case .holidayLemmings1993: return "Holiday Lemmings 1993"
        case .ohYesMoreLemmings: return "Oh Yes! More Lemmings!"
        case .lemmings3TheChronicles: return "Lemmings 3: The Chronicles"
        case .holidayLemmings1994: return "Holiday Lemmings 1994"
        }
    }

    /// Position in the series. Lower comes first.
    public var canonOrder: Int {
        ClassicTitle.allCases.firstIndex(of: self) ?? 0
    }

    /// Levels the release is known to hold, used to tell them apart.
    public var expectedLevelCount: Int? {
        switch self {
        case .lemmings: return 120
        case .ohNoMoreLemmings: return 100
        case .xmasLemmings1991, .xmasLemmings1992: return 4
        case .holidayLemmings1993, .holidayLemmings1994: return 32
        // Twenty Amiga versus levels, ten from Oh No!, and thirty
        // Mega Drive levels Sunsoft wrote for the Japanese release.
        case .ohYesMoreLemmings: return 60
        case .lemmings2TheTribes: return 120
        case .lemmings3TheChronicles: return 90
        }
    }

    /// One rung of the classic ladder: a title, and one of its ranks where the
    /// title has them. The festive releases are short and unranked, so they
    /// appear whole.
    public struct ClassicQuestStage: Equatable, Sendable {
        public let title: ClassicTitle
        public let rank: String?
        public let levels: Int
        public init(title: ClassicTitle, rank: String?, levels: Int) {
            self.title = title
            self.rank = rank
            self.levels = levels
        }
        public var label: String { rank.map { "\($0) — \(title.displayName)" } ?? title.displayName }
    }

    /// The classic releases in one climb, before the sequels.
    ///
    /// Release order alone puts all 100 Oh No! levels after all 120 original
    /// ones, so a player finishes Mayhem and is dropped back into Tame. Pure
    /// difficulty order loses the releases entirely. This interleaves the two
    /// ranked campaigns tier by tier, and places each festive set near the
    /// release it shipped beside, because those sets are short and gentle.
    ///
    /// Havoc ends the climb. It is the hardest rank either campaign offers.
    public static let classicQuest: [ClassicQuestStage] = [
        .init(title: .lemmings, rank: "Fun", levels: 30),
        .init(title: .ohNoMoreLemmings, rank: "Tame", levels: 20),
        .init(title: .xmasLemmings1991, rank: nil, levels: 4),
        .init(title: .xmasLemmings1992, rank: nil, levels: 4),
        .init(title: .lemmings, rank: "Tricky", levels: 30),
        .init(title: .ohNoMoreLemmings, rank: "Crazy", levels: 20),
        .init(title: .holidayLemmings1993, rank: nil, levels: 32),
        .init(title: .lemmings, rank: "Taxing", levels: 30),
        .init(title: .ohNoMoreLemmings, rank: "Wild", levels: 20),
        .init(title: .holidayLemmings1994, rank: nil, levels: 32),
        .init(title: .lemmings, rank: "Mayhem", levels: 30),
        .init(title: .ohNoMoreLemmings, rank: "Wicked", levels: 20),
        .init(title: .ohNoMoreLemmings, rank: "Havoc", levels: 20),
    ]

    /// Every level the classic climb covers. Oh Yes! is a conversion of levels
    /// that already appear above, so it is not counted again here.
    public static var classicQuestLevelCount: Int {
        classicQuest.reduce(0) { $0 + $1.levels }
    }

    /// Identifies a release from what was found on disk.
    ///
    /// The level count separates most of them. The festive releases share
    /// counts with each other, so the folder name decides between them. A
    /// wrong guess here only affects ordering and naming, never the levels.
    public static func identify(
        levelPrefix: String, levelCount: Int, folderName: String
    ) -> ClassicTitle? {
        let name = folderName.lowercased()
        let festive = name.contains("xmas") || name.contains("holiday")
            || name.contains("christmas")

        if name.contains("tribes") || name.contains("lemmings2")
            || name.contains("lemmings 2") {
            return .lemmings2TheTribes
        }
        if name.contains("chronicles") || name.contains("all new world")
            || name.contains("lemmings3") || name.contains("lemmings 3") {
            return .lemmings3TheChronicles
        }

        if festive {
            if name.contains("1991") { return .xmasLemmings1991 }
            if name.contains("1992") { return .xmasLemmings1992 }
            if name.contains("1993") { return .holidayLemmings1993 }
            if name.contains("1994") { return .holidayLemmings1994 }
            // Undated festive data. Two four-level demos shipped, and the
            // archives label both of them 1991, one marked as an alternate.
            // They hold different levels, so the variant marker is the only
            // thing that separates them.
            //
            // The mapping below is confirmed, not assumed. The Macintosh
            // release carries the 1992 demo as an extra, and its four levels
            // match the alternate set exactly, which leaves the plain set as
            // 1991.
            if levelCount <= 8 {
                let isAlternate = name.contains("a1") || name.contains("alt")
                return isAlternate ? .xmasLemmings1992 : .xmasLemmings1991
            }
            return .holidayLemmings1993
        }

        if levelPrefix.uppercased() == "DLVEL" { return .ohNoMoreLemmings }
        if levelCount == 120 { return .lemmings }
        if levelCount == 100 { return .ohNoMoreLemmings }
        return nil
    }
}

/// One release inside a saga.
public struct ClassicSagaChapter: Sendable {
    public let title: ClassicTitle
    /// Stable key for storing progress against this chapter.
    public let storageKey: String
    public let flow: ClassicGameFlow

    public init(title: ClassicTitle, storageKey: String, flow: ClassicGameFlow) {
        self.title = title
        self.storageKey = storageKey
        self.flow = flow
    }
}

public struct ClassicSaga: Sendable {
    public private(set) var chapters: [ClassicSagaChapter]
    public private(set) var currentChapterIndex: Int

    /// Chapters in release order, skipping any release not present.
    public init(chapters: [ClassicSagaChapter]) {
        self.chapters = chapters.sorted { $0.title.canonOrder < $1.title.canonOrder }
        currentChapterIndex = 0
    }

    public var currentChapter: ClassicSagaChapter? {
        chapters.indices.contains(currentChapterIndex) ? chapters[currentChapterIndex] : nil
    }

    /// The flow for the chapter being played.
    public var currentFlow: ClassicGameFlow? { currentChapter?.flow }

    /// Replaces the current chapter's flow after it changes.
    public mutating func updateCurrentFlow(_ flow: ClassicGameFlow) {
        guard chapters.indices.contains(currentChapterIndex) else { return }
        let chapter = chapters[currentChapterIndex]
        chapters[currentChapterIndex] = ClassicSagaChapter(
            title: chapter.title, storageKey: chapter.storageKey, flow: flow)
    }

    /// Starts a chapter directly, which is how a player drops into the middle.
    public mutating func selectChapter(_ index: Int) {
        guard chapters.indices.contains(index) else { return }
        currentChapterIndex = index
    }

    /// Moves to the next release once one is finished.
    ///
    /// Returns false at the end of the series, which is the end of the saga.
    public mutating func advanceChapter() -> Bool {
        let next = currentChapterIndex + 1
        guard chapters.indices.contains(next) else { return false }
        currentChapterIndex = next
        return true
    }

    public var isFinalChapter: Bool { currentChapterIndex >= chapters.count - 1 }

    /// How far through the whole series the player is.
    public var completion: (passed: Int, total: Int) {
        var passed = 0
        var total = 0
        for chapter in chapters {
            for rank in chapter.flow.ranks {
                total += rank.levelIndices.count
                passed += chapter.flow.passedCount(inRank: rank.name)
            }
        }
        return (passed, total)
    }

    /// A short line describing where the player is in the series.
    public func summary() -> String {
        let progress = completion
        let names = chapters.map(\.title.displayName).joined(separator: " → ")
        return "\(progress.passed)/\(progress.total) across \(chapters.count) titles: \(names)"
    }
}

// MARK: - Launching

/// How a player chose to start.
///
/// The difference matters at the end of a title. On a quest, finishing one
/// release carries straight into the next. On a single title, finishing it
/// returns to the launch screen instead.
public enum ClassicLaunchMode: Equatable, Sendable {
    case fullQuest
    case singleTitle(chapter: Int)
}

/// What happens when a title runs out of levels.
public enum ClassicSagaOutcome: Equatable, Sendable {
    case nextChapter(ClassicTitle)
    case questComplete
    case returnToLaunch
}

/// One row on the launch screen.
public struct ClassicLaunchEntry: Sendable {
    public let mode: ClassicLaunchMode
    public let title: String
    public let passed: Int
    public let total: Int

    public var isComplete: Bool { total > 0 && passed >= total }
    public var isStarted: Bool { passed > 0 }

    /// Progress as whole percent, for showing next to the name.
    public var percent: Int {
        total > 0 ? Int((Double(passed) / Double(total) * 100).rounded()) : 0
    }
}

extension ClassicSaga {
    /// The rows a launch screen shows: the whole series, then each release.
    ///
    /// Only releases whose data is present appear, so the screen never offers
    /// something that cannot be started.
    public func launchEntries() -> [ClassicLaunchEntry] {
        let overall = completion
        var entries = [ClassicLaunchEntry(
            mode: .fullQuest,
            title: "Full Quest",
            passed: overall.passed,
            total: overall.total)]

        for (index, chapter) in chapters.enumerated() {
            var passed = 0
            var total = 0
            for rank in chapter.flow.ranks {
                total += rank.levelIndices.count
                passed += chapter.flow.passedCount(inRank: rank.name)
            }
            entries.append(ClassicLaunchEntry(
                mode: .singleTitle(chapter: index),
                title: chapter.title.displayName,
                passed: passed,
                total: total))
        }
        return entries
    }

    /// Starts play in the chosen mode.
    ///
    /// A quest resumes at the first release that is not finished, so returning
    /// to it continues rather than starting over.
    public mutating func start(_ mode: ClassicLaunchMode) {
        switch mode {
        case .fullQuest:
            let unfinished = chapters.firstIndex { chapter in
                chapter.flow.ranks.contains { rank in
                    chapter.flow.passedCount(inRank: rank.name) < rank.levelIndices.count
                }
            }
            selectChapter(unfinished ?? 0)
        case let .singleTitle(index):
            selectChapter(index)
        }
    }

    /// Decides what follows when the current release is finished.
    public mutating func finishChapter(mode: ClassicLaunchMode) -> ClassicSagaOutcome {
        switch mode {
        case .singleTitle:
            return .returnToLaunch
        case .fullQuest:
            guard advanceChapter(), let chapter = currentChapter else {
                return .questComplete
            }
            return .nextChapter(chapter.title)
        }
    }
}
