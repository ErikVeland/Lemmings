import Foundation

public struct ArcadeProfile: Codable, Equatable, Sendable, Identifiable {
    public static let legacyID = "player-one"
    public let id: String
    public var initials: String
    public var portrait: Int
    public static let portraitNames = ["Walker", "Climber", "Floater", "Builder", "Basher", "Miner", "Digger", "Blocker"]

    public init(id: String = UUID().uuidString, initials: String, portrait: Int = 0) {
        self.id = id
        let clean = String(initials.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.prefix(3))
        self.initials = clean.isEmpty ? "LEM" : clean
        self.portrait = max(0, min(Self.portraitNames.count - 1, portrait))
    }
}

/// The same population and rules must be used when comparing solutions.
public struct ArcadeLevel: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let game: String
    public let rules: String
    public let total: Int
    public let required: Int
    public let conditions: TrolleyConditions?
    public var boardID: String { conditions.map { "trolley-v1:" + $0.fingerprint } ?? "\(id)|\(rules)|\(total)|\(required)" }

    public init(id: String, title: String, game: String, rules: String, total: Int, required: Int, conditions: TrolleyConditions? = nil) {
        self.id = id; self.title = title; self.game = game; self.rules = rules
        self.total = max(1, total); self.required = max(0, min(total, required)); self.conditions = conditions
    }
}

public enum ArcadeBoard: String, Codable, CaseIterable, Sendable {
    case rescue, efficiency, allSaved, fastestClear, fastestAllSaved
    public var title: String {
        switch self {
        case .rescue: L10n.text("MOST SAVED")
        case .efficiency: L10n.text("FEWEST SKILLS")
        case .allSaved: L10n.text("100% CLUB")
        case .fastestClear: L10n.text("FASTEST CLEAR")
        case .fastestAllSaved: L10n.text("FASTEST 100%")
        }
    }
}

public enum ArcadeLevelAchievement: String, Codable, CaseIterable, Sendable {
    case firstClear, allHome, noSkills, oneSkill, betterRescue, fewerSkills
    public var title: String {
        switch self {
        case .firstClear: L10n.text("TARGET MET")
        case .allHome: L10n.text("EVERYONE HOME")
        case .noSkills: L10n.text("HANDS OFF")
        case .oneSkill: L10n.text("ONE TRICK")
        case .betterRescue: L10n.text("ONE MORE HOME")
        case .fewerSkills: L10n.text("LESS IS MORE")
        }
    }
    public var detail: String {
        switch self {
        case .firstClear: "Clear a level."
        case .allHome: L10n.text("Rescue every lemming in a level.")
        case .noSkills: L10n.text("Clear a level without assigning a skill.")
        case .oneSkill: L10n.text("Clear a level using one skill type.")
        case .betterRescue: L10n.text("Improve your best rescue count.")
        case .fewerSkills: L10n.text("Match or beat your best rescue with fewer skills.")
        }
    }
}

public struct ArcadeRun: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let profileID: String
    public let level: ArcadeLevel
    public let saved: Int
    public let didWin: Bool
    public let skills: [String: Int]
    public let seconds: Double
    public let assisted: Bool
    public let date: Date
    public let telemetry: TrolleyTelemetry?
    public var skillCount: Int { skills.values.reduce(0, +) }
    public var population: Int {
        let extra = telemetry?.additionalStatistics["cloned"] ?? 0
        guard extra.isFinite, (0...1_000_000).contains(extra), level.total <= 1_000_000 else { return level.total }
        return level.total + Int(extra)
    }
    public var ratio: Double { Double(saved) / Double(population) }
    public var qualifies: Bool { didWin && saved >= level.required }
    public var savedAll: Bool { saved == population }
    public var mostUsedSkill: String {
        guard let first = skills.sorted(by: { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }).first else { return "NONE" }
        return "\(first.key.uppercased()) X\(first.value)"
    }
    public var percentage: String { String(format: "%.1f%%", ratio * 100) }

    public init(id: UUID = UUID(), profileID: String, level: ArcadeLevel, saved: Int,
                didWin: Bool, skills: [String: Int], seconds: Double, assisted: Bool = false, date: Date = Date(), telemetry: TrolleyTelemetry? = nil) {
        self.id = id; self.profileID = profileID; self.level = level
        self.saved = telemetry == nil ? max(0, min(level.total, saved)) : saved; self.didWin = didWin
        self.skills = skills.filter { !$0.key.isEmpty && $0.value > 0 }
        self.seconds = seconds.isFinite ? max(0, seconds) : 0
        self.assisted = assisted; self.date = date; self.telemetry = telemetry
    }
}

public struct ArcadeLevelStats: Codable, Equatable, Sendable {
    public var attempts = 0
    public var clears = 0
    public var zeroSaved = 0
    public var allSaved = 0
    public var achievements: Set<ArcadeLevelAchievement> = []
    public init() {}
}

public struct ArcadeReport: Sendable {
    public let run: ArcadeRun
    public let previousBest: ArcadeRun?
    public let bestKnown: ArcadeRun
    public let stats: ArcadeLevelStats
    public let earned: [ArcadeLevelAchievement]
    public let newRescueBest: Bool
    public let newSkillBest: Bool
    public let trolley: TrolleyReport?
    /// This run brought the player's earned level skips up by one.
    public var earnedLevelSkip = false
    public var earnedExtraSkill = false
    public var maximumIsProven: Bool { !run.usedBonusSkill && (trolley.map { $0.attempt.maximum.status == .verified } ?? bestKnown.savedAll) }
    public var challenge: String {
        if let previousBest, run.saved < previousBest.saved {
            return "YOUR BEST IS \(previousBest.saved). BRING \(previousBest.saved - run.saved) MORE HOME."
        }
        if run.saved < bestKnown.saved {
            return "THE RECORD IS \(bestKnown.saved). CAN YOU MATCH IT?"
        }
        if !run.savedAll {
            return "ONE MORE HOME? AIM FOR \(run.saved + 1) OF \(run.level.total)."
        }
        if run.skillCount > 0 {
            return "ALL HOME! CAN YOU DO IT WITH \(run.skillCount - 1) SKILLS?"
        }
        return "PERFECT RESCUE. CAN YOU BEAT YOUR TIME?"
    }
}

public struct ArcadeRecords: Codable, Equatable, Sendable {
    public private(set) var version = 2
    public private(set) var trolley = TrolleyHistory()
    public private(set) var profiles: [ArcadeProfile]
    public private(set) var activeProfileID: String
    /// Keep each player's best solution for every board, plus their latest run.
    public private(set) var runs: [ArcadeRun] = []
    public private(set) var statistics: [String: ArcadeLevelStats] = [:]
    /// The level keys each player spent a skip on. See `LevelSkips.swift`.
    public internal(set) var skippedLevels: [String: [String]] = [:]
    /// One immutable charge per attempt, shared by all games and cloud saves.
    public internal(set) var extraSkillUses: [String: [ExtraSkillUse]] = [:]

    public init() {
        let first = ArcadeProfile(id: ArcadeProfile.legacyID, initials: "LEM")
        profiles = [first]; activeProfileID = first.id
    }
    private enum CodingKeys: String, CodingKey { case version, profiles, activeProfileID, runs, statistics, trolley, skippedLevels, extraSkillUses }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let oldVersion = try c.decode(Int.self, forKey: .version)
        guard (1...2).contains(oldVersion) else { throw SequelDataError.invalid(L10n.text("Unsupported arcade records version.")) }
        profiles = try c.decode([ArcadeProfile].self, forKey: .profiles)
        activeProfileID = try c.decode(String.self, forKey: .activeProfileID)
        runs = try c.decode([ArcadeRun].self, forKey: .runs)
        statistics = try c.decode([String: ArcadeLevelStats].self, forKey: .statistics)
        trolley = oldVersion == 1 ? (try c.decodeIfPresent(TrolleyHistory.self, forKey: .trolley) ?? TrolleyHistory())
            : try c.decode(TrolleyHistory.self, forKey: .trolley)
        skippedLevels = try c.decodeIfPresent([String: [String]].self, forKey: .skippedLevels) ?? [:]
        extraSkillUses = try c.decodeIfPresent([String: [ExtraSkillUse]].self, forKey: .extraSkillUses) ?? [:]
        version = 2
    }
    public mutating func beginTrolleyAttempt(_ start: TrolleyStart) {
        guard profile(start.profileID) != nil else { return }
        trolley.begin(start)
    }
    mutating func upgradeTrolleyStartForBonusSkill(id: UUID, profileID: String,
        original: TrolleyConditions, bonus: TrolleyConditions, originalStart: TrolleyStart) -> Bool {
        guard bonus.isBonusUpgrade(of: original), !trolley.attempts.contains(where: { $0.id == id }) else { return false }
        if let start = trolley.starts.first(where: { $0.id == id }) {
            guard start.date == originalStart.date, start.parentAttemptID == originalStart.parentAttemptID,
                  start.kind == originalStart.kind else { return false }
        }
        if let start = trolley.starts.first(where: { $0.id == id }), start.profileID == profileID, start.conditions == bonus { return true }
        if !trolley.starts.contains(where: { $0.id == id }) {
            trolley.begin(originalStart)
        }
        return trolley.upgradeStartForBonusSkill(id: id, profileID: profileID, original: original, bonus: bonus)
    }
    public mutating func acceptTrolleyMaximum(_ evidence: TrolleyMaximum, conditions: TrolleyConditions, assisted: Bool) throws {
        try trolley.acceptMaximum(evidence, conditions: conditions, assisted: assisted)
    }
    public mutating func attachTrolleyReplay(_ replay: TrolleyReplayReference) { trolley.attachReplay(replay) }
    public mutating func retainBundledTrolleyMaxima(_ current: [String: TrolleyMaximum]) {
        trolley.retainBundledMaxima(current)
    }
    public var activeProfile: ArcadeProfile {
        profiles.first { $0.id == activeProfileID } ?? profiles[0]
    }
    public func profile(_ id: String) -> ArcadeProfile? { profiles.first { $0.id == id } }
    /// Imports existing device identities without deriving ownership from display names.
    public mutating func importProfiles(_ imported: [ArcadeProfile], activeID: String) throws {
        guard !imported.isEmpty, imported.count <= 8,
              Set(imported.map(\.id)).count == imported.count,
              imported.allSatisfy({ !$0.id.isEmpty }), imported.contains(where: { $0.id == activeID }) else {
            throw SequelDataError.invalid(L10n.text("The player identities are invalid."))
        }
        let pristine = profiles.count == 1 && profiles[0].id == ArcadeProfile.legacyID
            && runs.isEmpty && statistics.isEmpty && trolley.attempts.isEmpty
        if pristine { profiles = imported }
        else {
            let missing = imported.filter { profile($0.id) == nil }
            guard profiles.count + missing.count <= 8 else { throw SequelDataError.invalid(L10n.text("The player limit was reached.")) }
            profiles.append(contentsOf: missing)
            for value in imported { updateProfile(value.id, initials: value.initials, portrait: value.portrait) }
        }
        activeProfileID = activeID
    }
    public mutating func addProfile(initials: String, portrait: Int, select: Bool = true) -> ArcadeProfile? {
        guard profiles.count < 8 else { return nil }
        let profile = ArcadeProfile(initials: initials, portrait: portrait)
        profiles.append(profile)
        if select { activeProfileID = profile.id }
        return profile
    }
    /// Removes a player and everything recorded for them. The last player cannot be removed.
    /// Returns the removed replay references, or nil when nothing was removed.
    public mutating func removeProfile(_ id: String) -> [TrolleyReplayReference]? {
        guard profiles.count > 1, profile(id) != nil else { return nil }
        profiles.removeAll { $0.id == id }
        if activeProfileID == id { activeProfileID = profiles[0].id }
        runs.removeAll { $0.profileID == id }
        skippedLevels[id] = nil
        extraSkillUses[id] = nil
        statistics = statistics.filter { !$0.key.hasSuffix("|\(id)|true") && !$0.key.hasSuffix("|\(id)|false") }
        return trolley.removeProfile(id)
    }
    public mutating func updateProfile(_ id: String, initials: String, portrait: Int) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index] = ArcadeProfile(id: id, initials: initials, portrait: portrait)
    }
    public mutating func selectProfile(_ id: String) {
        if profiles.contains(where: { $0.id == id }) { activeProfileID = id }
    }
    public static func statsKey(level: ArcadeLevel, profileID: String, assisted: Bool) -> String {
        "\(level.boardID)|\(profileID)|\(assisted)"
    }
    public func stats(level: ArcadeLevel, profileID: String, assisted: Bool) -> ArcadeLevelStats {
        statistics[Self.statsKey(level: level, profileID: profileID, assisted: assisted)] ?? ArcadeLevelStats()
    }
    /// The first profile created on this Mac. Worldwide scores belong to it, so a
    /// guest cannot overwrite the owner's ranking from the same copy of the game.
    public var mainProfileID: String { profiles.first?.id ?? activeProfileID }
    public func careerAchievements(profileID: String) -> Set<ArcadeLevelAchievement> {
        statistics.reduce(into: []) { awards, entry in
            if entry.key.hasSuffix("|\(profileID)|false") || entry.key.hasSuffix("|\(profileID)|true") {
                awards.formUnion(entry.value.achievements)
            }
        }
    }
    public func leaderboard(level: ArcadeLevel, board: ArcadeBoard, assisted: Bool) -> [ArcadeRun] {
        let eligible = runs.filter { $0.level.boardID == level.boardID && $0.assisted == assisted
            && {
                switch board {
                case .rescue: return true
                case .efficiency: return $0.qualifies
                case .allSaved: return $0.savedAll
                case .fastestClear, .fastestAllSaved:
                    return $0.qualifies && $0.seconds.isFinite && $0.seconds > 0
                        && (board != .fastestAllSaved || $0.savedAll)
                }
            }($0) }
        let grouped = Dictionary(grouping: eligible, by: \.profileID)
        return grouped.values.compactMap { $0.sorted { Self.precedes($0, $1, board: board) }.first }
            .sorted { Self.precedes($0, $1, board: board) }
    }
    public static func precedes(_ a: ArcadeRun, _ b: ArcadeRun, board: ArcadeBoard) -> Bool {
        if [.fastestClear, .fastestAllSaved].contains(board), a.seconds != b.seconds { return a.seconds < b.seconds }
        if board == .rescue, a.saved != b.saved { return a.saved > b.saved }
        if a.skillCount != b.skillCount { return a.skillCount < b.skillCount }
        if a.saved != b.saved { return a.saved > b.saved }
        if a.seconds != b.seconds { return a.seconds < b.seconds }
        if a.date != b.date { return a.date < b.date }
        return a.id.uuidString < b.id.uuidString
    }
    @discardableResult public mutating func record(_ run: ArcadeRun) -> ArcadeReport? {
        guard profile(run.profileID) != nil, !runs.contains(where: { $0.id == run.id }),
              !trolley.attempts.contains(where: { $0.id == run.id }),
              bonusSkillUseMatches(run),
              run.telemetry == nil || TrolleyHistory.isLegitimate(run) else { return nil }
        let skipsBefore = levelSkips(profileID: run.profileID).earned
        let extraSkillsBefore = extraSkills(profileID: run.profileID).earned
        let trolleyReport = trolley.record(run)
        guard run.telemetry == nil || trolleyReport != nil else { return nil }
        // Passing a skipped level returns its skip.
        if run.qualifies { skippedLevels[run.profileID]?.removeAll { $0 == TrolleyCareerScore.levelKey(run.level) } }
        if skippedLevels[run.profileID]?.isEmpty == true { skippedLevels[run.profileID] = nil }
        let previous = leaderboard(level: run.level, board: .rescue, assisted: run.assisted)
            .first { $0.profileID == run.profileID }
        let key = Self.statsKey(level: run.level, profileID: run.profileID, assisted: run.assisted)
        var stats = statistics[key] ?? ArcadeLevelStats()
        let oldAwards = stats.achievements
        stats.attempts += 1
        if run.qualifies { stats.clears += 1 }
        if run.saved == 0 { stats.zeroSaved += 1 }
        if run.savedAll { stats.allSaved += 1 }
        if !run.usedBonusSkill {
            if run.qualifies { stats.achievements.insert(.firstClear) }
            if run.savedAll { stats.achievements.insert(.allHome) }
            if run.qualifies && run.skillCount == 0 { stats.achievements.insert(.noSkills) }
            if run.qualifies && run.skills.count == 1 { stats.achievements.insert(.oneSkill) }
        }
        let improved = previous.map { run.saved > $0.saved } ?? (run.saved > 0)
        let efficient = previous.map { run.qualifies && run.saved >= $0.saved && run.skillCount < $0.skillCount } ?? false
        if !run.usedBonusSkill {
            if improved && previous != nil { stats.achievements.insert(.betterRescue) }
            if efficient { stats.achievements.insert(.fewerSkills) }
        }
        statistics[key] = stats
        runs.append(run)
        let best = leaderboard(level: run.level, board: .rescue, assisted: run.assisted).first ?? run
        // Retain only meaningful records for this player and these rules.
        var keep: Set<UUID> = [run.id]
        for board in ArcadeBoard.allCases {
            if let record = leaderboard(level: run.level, board: board, assisted: run.assisted)
                .first(where: { $0.profileID == run.profileID }) { keep.insert(record.id) }
        }
        runs.removeAll { $0.level.boardID == run.level.boardID && $0.profileID == run.profileID
            && $0.assisted == run.assisted && !keep.contains($0.id) }
        var report = ArcadeReport(run: run, previousBest: previous, bestKnown: best, stats: stats,
            earned: ArcadeLevelAchievement.allCases.filter { stats.achievements.contains($0) && !oldAwards.contains($0) },
            newRescueBest: improved, newSkillBest: efficient, trolley: trolleyReport)
        report.earnedLevelSkip = levelSkips(profileID: run.profileID).earned > skipsBefore
        report.earnedExtraSkill = extraSkills(profileID: run.profileID).earned > extraSkillsBefore
        return report
    }

    public func validated() throws -> Self {
        guard version == 2, !profiles.isEmpty, profiles.count <= 8,
              Set(profiles.map(\.id)).count == profiles.count,
              profiles.contains(where: { $0.id == activeProfileID }),
              profiles.allSatisfy({ !$0.id.isEmpty && !$0.initials.isEmpty && $0.initials.count <= 3
                  && ArcadeProfile.portraitNames.indices.contains($0.portrait) }),
              runs.allSatisfy({ profile($0.profileID) != nil && $0.level.total > 0 && (0...$0.population).contains($0.saved)
                  && $0.seconds.isFinite && $0.seconds >= 0 && $0.skills.values.allSatisfy { $0 > 0 } }),
              skippedLevels.allSatisfy({ profile($0.key) != nil && Set($0.value).count == $0.value.count }),
              extraSkillUsesAreValid()
        else { throw SequelDataError.invalid("Invalid arcade records.") }
        _ = try trolley.validated(profileIDs: Set(profiles.map(\.id)))
        return self
    }

    public static let cloudProfileID = "game-center-player"

    /// Export one player's records without device identities or replay file paths.
    public func cloudRecords(profileID: String) throws -> Self {
        guard profile(profileID) != nil else { throw SequelDataError.invalid(L10n.text("The player no longer exists.")) }
        var copy = self
        copy.profiles = [ArcadeProfile(id: Self.cloudProfileID, initials: "LEM")]
        copy.activeProfileID = Self.cloudProfileID
        copy.runs = runs.filter { $0.profileID == profileID }.map { $0.cloudOwned(by: Self.cloudProfileID) }
            .sorted { $0.id.uuidString < $1.id.uuidString }
        copy.statistics = [:]
        for (key, stats) in statistics {
            for assisted in [false, true] {
                let suffix = "|\(profileID)|\(assisted)"
                if key.hasSuffix(suffix) {
                    copy.statistics[String(key.dropLast(suffix.count)) + "|\(Self.cloudProfileID)|\(assisted)"] = stats
                }
            }
        }
        copy.skippedLevels = skippedLevels[profileID].map { [Self.cloudProfileID: $0.sorted()] } ?? [:]
        copy.extraSkillUses = extraSkillUses[profileID].map {
            [Self.cloudProfileID: $0.sorted { $0.attemptID.uuidString < $1.attemptID.uuidString }]
        } ?? [:]
        copy.trolley = trolley.cloudHistory(profileID: profileID, destinationID: Self.cloudProfileID)
        return try copy.validated()
    }

    /// Merge immutable result IDs. Local player selection and guest records stay local.
    public mutating func mergeCloudRecords(_ incoming: Self, profileID: String) throws {
        var proposed = self
        try proposed.mergeCloudRecordsInPlace(incoming, profileID: profileID)
        self = proposed
    }
    private mutating func mergeCloudRecordsInPlace(_ incoming: Self, profileID: String) throws {
        _ = try incoming.validated()
        guard incoming.profiles.map(\.id) == [Self.cloudProfileID], profile(profileID) != nil else {
            throw SequelDataError.invalid(L10n.text("The cloud player is invalid."))
        }
        let localEvents = Self.cloudEventCounts(trolley.attempts)
        let remoteEvents = Self.cloudEventCounts(incoming.trolley.attempts)
        try trolley.mergeCloudHistory(incoming.trolley, sourceID: Self.cloudProfileID, destinationID: profileID)
        var knownUses = Dictionary((extraSkillUses[profileID] ?? []).map { ($0.attemptID, $0) }, uniquingKeysWith: { first, _ in first })
        for use in incoming.extraSkillUses[Self.cloudProfileID] ?? [] {
            if let previous = knownUses[use.attemptID], previous != use {
                throw SequelDataError.invalid(L10n.text("Saved extra-skill uses conflict."))
            }
            knownUses[use.attemptID] = use
        }
        extraSkillUses[profileID] = knownUses.isEmpty ? nil : knownUses.values.sorted { $0.attemptID.uuidString < $1.attemptID.uuidString }
        let mergedEvents = Self.cloudEventCounts(trolley.attempts)
        var knownRuns = Dictionary(runs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for run in incoming.runs {
            let mapped = run.cloudOwned(by: profileID)
            if let previous = knownRuns[mapped.id] {
                guard previous == mapped else { throw SequelDataError.invalid(L10n.text("Saved result identities conflict.")) }
            } else { runs.append(mapped); knownRuns[mapped.id] = mapped }
        }
        for (key, remote) in incoming.statistics {
            for assisted in [false, true] {
                let suffix = "|\(Self.cloudProfileID)|\(assisted)"
                guard key.hasSuffix(suffix) else { continue }
                let localKey = String(key.dropLast(suffix.count)) + "|\(profileID)|\(assisted)"
                let local = statistics[localKey] ?? ArcadeLevelStats()
                let before = localEvents[localKey] ?? ArcadeLevelStats()
                let remoteCount = remoteEvents[key] ?? ArcadeLevelStats()
                let combinedCount = mergedEvents[localKey] ?? ArcadeLevelStats()
                var combined = local
                combined.attempts = max(0, max(local.attempts - before.attempts, remote.attempts - remoteCount.attempts)) + combinedCount.attempts
                combined.clears = max(0, max(local.clears - before.clears, remote.clears - remoteCount.clears)) + combinedCount.clears
                combined.zeroSaved = max(0, max(local.zeroSaved - before.zeroSaved, remote.zeroSaved - remoteCount.zeroSaved)) + combinedCount.zeroSaved
                combined.allSaved = max(0, max(local.allSaved - before.allSaved, remote.allSaved - remoteCount.allSaved)) + combinedCount.allSaved
                combined.achievements.formUnion(remote.achievements)
                statistics[localKey] = combined
            }
        }
        let cleared = Set(runs.filter { $0.profileID == profileID && $0.qualifies }.map { TrolleyCareerScore.levelKey($0.level) })
        let skipped = Set(skippedLevels[profileID] ?? []).union(incoming.skippedLevels[Self.cloudProfileID] ?? []).subtracting(cleared)
        skippedLevels[profileID] = skipped.isEmpty ? nil : skipped.sorted()
        _ = try validated()
    }
    private static func cloudEventCounts(_ attempts: [TrolleyAttempt]) -> [String: ArcadeLevelStats] {
        var counts: [String: ArcadeLevelStats] = [:]
        for attempt in attempts {
            let run = attempt.run
            let key = statsKey(level: run.level, profileID: run.profileID, assisted: run.assisted)
            var count = counts[key] ?? ArcadeLevelStats()
            count.attempts += 1
            if run.qualifies { count.clears += 1 }
            if run.saved == 0 { count.zeroSaved += 1 }
            if run.savedAll { count.allSaved += 1 }
            counts[key] = count
        }
        return counts
    }
}

extension ArcadeRun {
    func cloudOwned(by profileID: String) -> Self {
        .init(id: id, profileID: profileID, level: level, saved: saved, didWin: didWin,
            skills: skills, seconds: seconds, assisted: assisted, date: date, telemetry: telemetry)
    }
}
