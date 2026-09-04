import Foundation

/// The whole game, from the title screen to the end.
///
/// The app previously held one level at a time and let the player pick from a
/// list. That is a level viewer, not the game. The real shape is a title
/// screen, a choice of rank, then a run of levels where finishing one carries
/// you to the next and failing one returns you to it, until a rank is done and
/// finally the game is.
///
/// This lives apart from the interface so the progression can be tested
/// without opening a window.

public enum ClassicGameScreen: Equatable, Sendable {
    case title
    case rankSelect
    /// Shown before a level starts.
    case briefing(level: Int)
    case playing(level: Int)
    /// Shown when a level ends, whether or not it was passed.
    case results(level: Int, saved: Int, required: Int, total: Int)
    /// Shown after the last level of a rank is passed.
    case rankComplete(rank: String)
    /// Shown after the last rank is passed.
    case gameComplete
    case quitConfirm

    /// True while a level is actually running.
    ///
    /// Comparing against `.playing` directly does not work, because the case
    /// carries the level it is running.
    public var isPlaying: Bool {
        if case .playing = self { return true }
        return false
    }
}

/// One rank and the levels it holds.
public struct ClassicRank: Equatable, Sendable {
    public let name: String
    /// Indices into the campaign, in play order.
    public let levelIndices: [Int]

    public init(name: String, levelIndices: [Int]) {
        self.name = name
        self.levelIndices = levelIndices
    }
}

public struct ClassicGameFlow: Sendable {
    public private(set) var screen: ClassicGameScreen = .title
    public let ranks: [ClassicRank]
    /// Highest level reached in each rank, so a player can resume.
    public private(set) var furthestReached: [String: Int] = [:]
    /// Levels passed, by rank name and position within the rank.
    public private(set) var passed: Set<String> = []

    private var currentRankIndex = 0
    private var positionInRank = 0
    /// The screen to return to when a level is abandoned.
    private let returnScreen = ClassicGameScreen.rankSelect

    public init(ranks: [ClassicRank]) {
        self.ranks = ranks
    }

    /// Groups a campaign into its ranks, keeping the shipped order.
    public init(campaign: ClassicCampaign) {
        var order: [String] = []
        var grouped: [String: [Int]] = [:]
        for (index, level) in campaign.levels.enumerated() {
            if grouped[level.rank] == nil { order.append(level.rank) }
            grouped[level.rank, default: []].append(index)
        }
        ranks = order.map { ClassicRank(name: $0, levelIndices: grouped[$0] ?? []) }
    }

    // MARK: - Reading the current place

    public var currentRank: ClassicRank? {
        ranks.indices.contains(currentRankIndex) ? ranks[currentRankIndex] : nil
    }

    /// One-based position within the rank, as the game numbers its levels.
    public var currentNumber: Int { positionInRank + 1 }

    public var currentLevelIndex: Int? {
        guard let rank = currentRank, rank.levelIndices.indices.contains(positionInRank)
        else { return nil }
        return rank.levelIndices[positionInRank]
    }

    private func key(rank: String, position: Int) -> String { "\(rank)#\(position)" }

    public func hasPassed(rank: String, position: Int) -> Bool {
        passed.contains(key(rank: rank, position: position))
    }

    /// How many levels of a rank have been passed.
    public func passedCount(inRank rank: String) -> Int {
        passed.filter { $0.hasPrefix("\(rank)#") }.count
    }

    // MARK: - Moving between screens

    public mutating func startGame() {
        screen = .rankSelect
    }

    /// Resume the first unfinished level, including gaps left by direct selection.
    public mutating func resumeCampaign() {
        for (rankIndex, rank) in ranks.enumerated() {
            if let position = rank.levelIndices.indices.first(where: { !hasPassed(rank: rank.name, position: $0) }) {
                selectLevel(rank: rankIndex, position: position)
                return
            }
        }
        selectLevel(rank: 0, position: 0)
    }

    /// Begins a rank, resuming at the furthest level reached in it.
    public mutating func selectRank(_ index: Int) {
        guard ranks.indices.contains(index) else { return }
        currentRankIndex = index
        positionInRank = min(
            furthestReached[ranks[index].name] ?? 0,
            max(0, ranks[index].levelIndices.count - 1))
        openBriefing()
    }

    /// Jumps straight to one level, for practice or a level code.
    public mutating func selectLevel(rank index: Int, position: Int) {
        guard ranks.indices.contains(index),
            ranks[index].levelIndices.indices.contains(position) else { return }
        currentRankIndex = index
        positionInRank = position
        openBriefing()
    }

    private mutating func openBriefing() {
        guard let level = currentLevelIndex, let rank = currentRank else { return }
        let reached = furthestReached[rank.name] ?? 0
        furthestReached[rank.name] = max(reached, positionInRank)
        screen = .briefing(level: level)
    }

    public mutating func beginPlaying() {
        guard case let .briefing(level) = screen else { return }
        screen = .playing(level: level)
    }

    /// Records how a level ended and shows the result.
    public mutating func finishLevel(saved: Int, required: Int, total: Int) {
        guard case let .playing(level) = screen else { return }
        if saved >= required, let rank = currentRank {
            passed.insert(key(rank: rank.name, position: positionInRank))
        }
        screen = .results(level: level, saved: saved, required: required, total: total)
    }

    /// Moves on from a result. Passing advances, failing repeats the level.
    public mutating func acknowledgeResults() {
        guard case let .results(_, saved, required, _) = screen else { return }
        guard saved >= required else {
            openBriefing()
            return
        }
        guard let rank = currentRank else { return }

        let next = positionInRank + 1
        if next < rank.levelIndices.count {
            positionInRank = next
            openBriefing()
            return
        }

        // The rank is finished. The game is finished when it was the last one.
        screen = .rankComplete(rank: rank.name)
    }

    /// Moves on from a rank completion.
    public mutating func acknowledgeRankComplete() {
        guard case .rankComplete = screen else { return }
        let next = currentRankIndex + 1
        guard next < ranks.count else {
            screen = ranks.allSatisfy { passedCount(inRank: $0.name) == $0.levelIndices.count }
                ? .gameComplete : .rankSelect
            return
        }
        currentRankIndex = next
        positionInRank = 0
        openBriefing()
    }

    public mutating func acknowledgeGameComplete() {
        screen = .title
    }

    /// Leaves a level without finishing it.
    public mutating func abandonLevel() {
        switch screen {
        case .briefing, .playing, .results:
            screen = returnScreen
        default:
            break
        }
    }

    public mutating func requestQuit() {
        guard screen != .quitConfirm else { return }
        screen = .quitConfirm
    }

    public mutating func cancelQuit() {
        guard screen == .quitConfirm else { return }
        screen = .title
    }

    // MARK: - Saving

    /// The progress worth keeping between sessions.
    public struct Progress: Codable, Equatable, Sendable {
        public var furthestReached: [String: Int]
        public var passed: [String]

        public init(furthestReached: [String: Int], passed: [String]) {
            self.furthestReached = furthestReached
            self.passed = passed
        }
    }

    public var progress: Progress {
        Progress(furthestReached: furthestReached, passed: passed.sorted())
    }

    public mutating func restore(_ progress: Progress) {
        furthestReached = Dictionary(uniqueKeysWithValues: ranks.map { rank in
            (rank.name, min(max(0, progress.furthestReached[rank.name] ?? 0), max(0, rank.levelIndices.count - 1)))
        })
        let valid = Set(ranks.flatMap { rank in rank.levelIndices.indices.map { key(rank: rank.name, position: $0) } })
        passed = Set(progress.passed).intersection(valid)
    }
}
