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

/// A release this engine can run, in the order it appeared.
public enum ClassicTitle: String, CaseIterable, Codable, Sendable {
    case lemmings
    case xmasLemmings1991
    case ohNoMoreLemmings
    case xmasLemmings1992
    case holidayLemmings1993
    case holidayLemmings1994

    public var displayName: String {
        switch self {
        case .lemmings: return "Lemmings"
        case .xmasLemmings1991: return "Xmas Lemmings 1991"
        case .ohNoMoreLemmings: return "Oh No! More Lemmings"
        case .xmasLemmings1992: return "Xmas Lemmings 1992"
        case .holidayLemmings1993: return "Holiday Lemmings 1993"
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
        }
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

        if festive {
            if name.contains("1991") { return .xmasLemmings1991 }
            if name.contains("1992") { return .xmasLemmings1992 }
            if name.contains("1993") { return .holidayLemmings1993 }
            if name.contains("1994") { return .holidayLemmings1994 }
            // Undated festive data: the small ones are the early demos.
            return levelCount <= 8 ? .xmasLemmings1991 : .holidayLemmings1993
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
