import Foundation
import NxlvKit

public struct JourneySessionSnapshot: Codable, Equatable, Sendable {
    public var run: LevelSequenceRun?
    public var l2Progress: [String: Data]
    public var updatedAt: Date
    public init(run: LevelSequenceRun?, l2Progress: [String: Data] = [:], updatedAt: Date = Date()) {
        self.run = run; self.l2Progress = l2Progress; self.updatedAt = updatedAt
    }
}

public enum GameProgressValue: Codable, Equatable, Sendable {
    case completed(Set<Int>)
    case fanLevels(Set<String>)
    case learning(LearningJourneyProgress)
    case journeySession(JourneySessionSnapshot)
    case classic(ClassicGameFlow.Progress)
    case modern(ModernCampaignProgress)
    case achievements(ClassicAchievementProgress)
    case tribes(Lemmings2Campaign.Progress)
    case chronicles(Lemmings3ClassicCampaign.Progress)

    func merging(_ other: Self) throws -> Self {
        switch (self, other) {
        case let (.completed(a), .completed(b)): return .completed(a.union(b))
        case let (.fanLevels(a), .fanLevels(b)): return .fanLevels(a.union(b))
        case let (.learning(a), .learning(b)): return .learning(Self.mergeLearning(a, b))
        case let (.journeySession(a), .journeySession(b)):
            if a.updatedAt != b.updatedAt { return .journeySession(a.updatedAt > b.updatedAt ? a : b) }
            return .journeySession(try Self.stable(a).lexicographicallyPrecedes(Self.stable(b)) ? b : a)
        case let (.classic(a), .classic(b)):
            return .classic(.init(furthestReached: a.furthestReached.merging(b.furthestReached, uniquingKeysWith: max),
                passed: Set(a.passed).union(b.passed).sorted()))
        case let (.modern(a), .modern(b)):
            let results = a.results.merging(b.results) { x, y in
                if x.didWin != y.didWin { return x.didWin ? x : y }
                if x.saved != y.saved { return x.saved > y.saved ? x : y }
                if x.completedAt != y.completedAt { return x.completedAt > y.completedAt ? x : y }
                return (x.required, x.levelIndex) >= (y.required, y.levelIndex) ? x : y
            }
            return .modern(.init(results: results))
        case let (.achievements(a), .achievements(b)):
            let cursorA = (a.canonTitleIndex ?? 0, a.canonLevelIndex ?? 0)
            let cursorB = (b.canonTitleIndex ?? 0, b.canonLevelIndex ?? 0)
            let cursor = cursorA >= cursorB ? cursorA : cursorB
            return .achievements(.init(unlocked: a.unlocked.union(b.unlocked),
                nextOrderedLevel: a.nextOrderedLevel.merging(b.nextOrderedLevel, uniquingKeysWith: max),
                canonTitleIndex: cursor.0, canonLevelIndex: cursor.1))
        case let (.tribes(a), .tribes(b)):
            // Carry-over population belongs to a whole tribe chain. Mixing
            // individual results can invalidate the starting population.
            var results: [Int: Lemmings2Campaign.Result] = [:]
            var skipped: [Int: Int] = [:]
            for tribe in 0..<12 {
                func score(_ progress: Lemmings2Campaign.Progress) -> [Int] {
                    let chain = progress.results.filter { $0.key / 10 == tribe }
                    let jumps = (progress.skipped ?? [:]).filter { $0.key / 10 == tribe }
                    let last = max(chain.keys.max() ?? tribe * 10 - 1, jumps.keys.max() ?? tribe * 10 - 1)
                    return [last, chain[last]?.saved ?? jumps[last] ?? 0,
                        chain.values.reduce(0) { $0 + $1.medal.rawValue }, chain.values.reduce(0) { $0 + $1.saved }]
                }
                let chosen: Lemmings2Campaign.Progress
                if score(a) != score(b) { chosen = score(a).lexicographicallyPrecedes(score(b)) ? b : a }
                else { chosen = try Self.stable(a).lexicographicallyPrecedes(Self.stable(b)) ? b : a }
                results.merge(chosen.results.filter { $0.key / 10 == tribe }, uniquingKeysWith: { x, _ in x })
                skipped.merge((chosen.skipped ?? [:]).filter { $0.key / 10 == tribe }, uniquingKeysWith: { x, _ in x })
            }
            let selected = (a.tribe, a.level) >= (b.tribe, b.level) ? a : b
            return .tribes(.init(tribe: selected.tribe, level: selected.level, results: results, skipped: skipped))
        case let (.chronicles(a), .chronicles(b)):
            guard (a.tribe ?? .classic) == (b.tribe ?? .classic) else { throw SequelDataError.invalid(L10n.text("Cloud tribes do not match.")) }
            let selected = (a.index, a.population) >= (b.index, b.population) ? a : b
            return .chronicles(.init(index: selected.index, population: selected.population,
                completed: a.completed.merging(b.completed, uniquingKeysWith: max), tribe: selected.tribe))
        default: throw SequelDataError.invalid(L10n.text("The cloud progress format does not match."))
        }
    }
    public static func mergeLearning(_ a: LearningJourneyProgress, _ b: LearningJourneyProgress) -> LearningJourneyProgress {
        var result = a
        for level in b.later { result.record(level, won: false) }
        for level in b.completed { result.record(level, won: true) }
        return result
    }
    private static func stable<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }
}

public struct GameProgressPreferences: Codable, Equatable, Sendable {
    public var values: [String: GameProgressValue]
    public init(values: [String: GameProgressValue] = [:]) { self.values = values }

    /// Empty defaults written by a new build do not establish a separate player.
    public var hasRecordedProgress: Bool {
        values.values.contains { value in
            switch value {
            case .completed(let indices): return !indices.isEmpty
            case .fanLevels(let levels): return !levels.isEmpty
            case .learning(let progress): return !progress.completed.isEmpty || !progress.later.isEmpty
            case .journeySession(let snapshot): return snapshot.run != nil
            case .classic(let progress): return !progress.passed.isEmpty || progress.furthestReached.values.contains { $0 > 0 }
            case .modern(let progress): return !progress.results.isEmpty
            case .achievements(let progress):
                return !progress.unlocked.isEmpty || progress.nextOrderedLevel.values.contains { $0 > 0 }
                    || (progress.canonTitleIndex ?? 0) > 0 || (progress.canonLevelIndex ?? 0) > 0
            case .tribes(let progress): return !progress.results.isEmpty || !(progress.skipped ?? [:]).isEmpty
            case .chronicles(let progress): return progress.index > 0 || !progress.completed.isEmpty
            }
        }
    }

    @MainActor public static func capture(defaults: UserDefaults, profileID: String, profileIDs: [String], sessionID: String? = nil) -> Self {
        var result = Self()
        let decoder = JSONDecoder()
        let scoped = sessionID.map { "HotSeat.\($0)." } ?? "ArcadeProfile.\(profileID)."
        let mobileSuffix = sessionID.map { ".hotseat." + $0 } ?? (profileID == "default" ? "" : "." + profileID)
        let cloudPrefix = "GameCenterProgress.cleared.\(sessionID.map { "hotseat." + $0 } ?? profileID)."
        for (key, value) in defaults.dictionaryRepresentation() {
            if key.hasPrefix(cloudPrefix), let indices = value as? [Int] {
                result.addCompleted(indices, pack: String(key.dropFirst(cloudPrefix.count))); continue
            }
            if key.hasPrefix("mobile.completed."), (sessionID != nil || !key.contains(".hotseat.")), let indices = value as? [Int] {
                if sessionID == nil && profileIDs.contains(where: { $0 != profileID && $0 != "default" && key.hasSuffix("." + $0) }) { continue }
                guard mobileSuffix.isEmpty || key.hasSuffix(mobileSuffix) else { continue }
                let pack = String(key.dropFirst("mobile.completed.".count).dropLast(mobileSuffix.count))
                result.addCompleted(indices, pack: pack == "Lemmings" ? "release/lemmings" : pack)
                continue
            }
            let base: String
            if key.hasPrefix(scoped) { base = String(key.dropFirst(scoped.count)) }
            else if sessionID == nil && profileID == ArcadeProfile.legacyID { base = key }
            else { continue }
            if base == "FanLevelsPassed", let levels = value as? [String] {
                result.values[base] = .fanLevels(Set(levels)); continue
            }
            guard let data = value as? Data else { continue }
            if portableClassicKey(base), let progress = try? decoder.decode(ClassicGameFlow.Progress.self, from: data) {
                result.values[base] = .classic(progress)
            } else if base == "LearningJourneyProgress", let progress = try? decoder.decode(LearningJourneyProgress.self, from: data) {
                result.values[base] = .learning(progress)
            } else if base == "LearningJourneySession", let snapshot = try? decoder.decode(JourneySessionSnapshot.self, from: data) {
                result.values[base] = .journeySession(snapshot)
            } else if base == "ModernCampaignProgress", let progress = try? decoder.decode(ModernCampaignProgress.self, from: data) {
                result.values[base] = .modern(progress)
            } else if base == "ClassicAchievementProgress", let progress = try? decoder.decode(ClassicAchievementProgress.self, from: data) {
                result.values[base] = .achievements(progress)
            } else if base == "nativeL2Campaign.v1.bundled", let progress = try? decoder.decode(Lemmings2Campaign.Progress.self, from: data) {
                result.values[base] = .tribes(progress)
            } else if portableL3Key(base), let progress = try? decoder.decode(Lemmings3ClassicCampaign.Progress.self, from: data) {
                result.values[base] = .chronicles(progress)
            }
        }
        let learning = Self.learning(profileID: profileID, sessionID: sessionID, defaults: defaults)
        try? result.merge(JourneySourceCompletion.progress(learning,
            entries: LearningJourneyLibrary.journey?.lessons.map(\.entry) ?? []))
        return result
    }

    public mutating func addCompleted(_ indices: [Int], pack: String) {
        let key = "cleared/" + pack
        let previous: Set<Int>
        if case let .completed(value) = values[key] { previous = value } else { previous = [] }
        values[key] = .completed(previous.union(indices.filter { (0..<1_000_000).contains($0) }))
    }
    public mutating func merge(_ incoming: Self) throws {
        try validate()
        try incoming.validate()
        for (key, value) in incoming.values {
            values[key] = try values[key]?.merging(value) ?? value
        }
    }
    public func validate() throws {
        guard values.count <= 10_000 else { throw SequelDataError.invalid(L10n.text("The cloud progress is too large.")) }
        for (key, value) in values {
            guard key.count <= 512, !key.contains("\0") else { throw SequelDataError.invalid(L10n.text("Invalid cloud progress key.")) }
            let valid: Bool
            switch value {
            case .completed(let indices): valid = key.hasPrefix("cleared/") && !key.contains(".hotseat.") && indices.allSatisfy { (0..<1_000_000).contains($0) }
            case .fanLevels(let levels):
                valid = key == "FanLevelsPassed" && levels.count <= 100_000
                    && levels.allSatisfy { $0.count <= 2048 && !$0.contains("\0") }
            case .learning(let progress):
                valid = key == "LearningJourneyProgress" && progress.completed.count + progress.later.count <= 100_000
                    && progress.completed.isDisjoint(with: progress.later)
                    && progress.completed.union(progress.later).allSatisfy { $0.packID.count <= 512 && $0.levelID.count <= 1024 }
            case .journeySession(let snapshot):
                valid = key == "LearningJourneySession" && snapshot.updatedAt.timeIntervalSinceReferenceDate.isFinite
                    && (snapshot.run == nil || snapshot.run?.source == .playlist(LearningJourney.playlistID))
                    && snapshot.l2Progress.count <= 256 && snapshot.l2Progress.values.allSatisfy { $0.count <= 1_000_000 }
            case .classic: valid = Self.portableClassicKey(key)
            case .modern: valid = key == "ModernCampaignProgress"
            case .achievements: valid = key == "ClassicAchievementProgress"
            case .tribes(let progress):
                valid = key == "nativeL2Campaign.v1.bundled" && progress.version == 1
                    && (0..<12).contains(progress.tribe) && (0..<10).contains(progress.level)
                    && progress.results.allSatisfy { index, result in
                        (0..<120).contains(index) && (1...60).contains(result.startingPopulation)
                            && result.saved > 0 && result.saved <= result.startingPopulation && result.levelFingerprint.count <= 512
                    } && (progress.skipped ?? [:]).allSatisfy { (0..<120).contains($0.key) && $0.key % 10 != 9 && (1...60).contains($0.value) }
            case .chronicles(let progress):
                valid = Self.portableL3Key(key) && progress.version == 1 && (0..<30).contains(progress.index)
                    && (1...1_000_000).contains(progress.population)
                    && progress.completed.allSatisfy { (0..<30).contains($0.key) && (1...1_000_000).contains($0.value) }
            }
            guard valid else { throw SequelDataError.invalid(L10n.text("Unsupported cloud progress key.")) }
        }
    }
    @MainActor public func apply(defaults: UserDefaults, profileID: String, sessionID: String? = nil) throws {
        try validate()
        let encoder = JSONEncoder()
        for (key, value) in values {
            let destination = sessionID.map { "HotSeat.\($0).\(key)" } ?? ArcadeStore.progressKey(key, profileID: profileID)
            switch value {
            case .completed(let indices):
                let pack = String(key.dropFirst("cleared/".count))
                defaults.set(indices.sorted(), forKey: Self.completedKey(pack: pack, profileID: sessionID.map { "hotseat." + $0 } ?? profileID))
                let suffix = sessionID.map { ".hotseat." + $0 } ?? (profileID == "default" ? "" : "." + profileID)
                defaults.set(indices.sorted(), forKey: "mobile.completed." + pack + suffix)
            case .fanLevels(let levels): defaults.set(levels.sorted(), forKey: destination)
            case .learning(let progress): defaults.set(try encoder.encode(progress), forKey: destination)
            case .journeySession(let snapshot): defaults.set(try encoder.encode(snapshot), forKey: destination)
            case .classic(let progress): defaults.set(try encoder.encode(progress), forKey: destination)
            case .modern(let progress): defaults.set(try encoder.encode(progress), forKey: destination)
            case .achievements(let progress): defaults.set(try encoder.encode(progress), forKey: destination)
            case .tribes(let progress): defaults.set(try encoder.encode(progress), forKey: destination)
            case .chronicles(let progress): defaults.set(try encoder.encode(progress), forKey: destination)
            }
        }
    }
    @MainActor public static func learning(profileID: String, sessionID: String? = nil, defaults: UserDefaults = .standard) -> LearningJourneyProgress {
        let key = sessionID.map { "HotSeat.\($0).LearningJourneyProgress" }
            ?? ArcadeStore.progressKey("LearningJourneyProgress", profileID: profileID)
        return defaults.data(forKey: key)
            .flatMap { try? JSONDecoder().decode(LearningJourneyProgress.self, from: $0) } ?? .init()
    }
    @MainActor public static func saveLearning(_ progress: LearningJourneyProgress, profileID: String, sessionID: String? = nil,
        entries: [LevelPlaylistEntry] = [], defaults: UserDefaults = .standard) throws {
        let merged = GameProgressValue.mergeLearning(learning(profileID: profileID, sessionID: sessionID, defaults: defaults), progress)
        let key = sessionID.map { "HotSeat.\($0).LearningJourneyProgress" } ?? ArcadeStore.progressKey("LearningJourneyProgress", profileID: profileID)
        if learning(profileID: profileID, sessionID: sessionID, defaults: defaults) != merged {
            defaults.set(try JSONEncoder().encode(merged), forKey: key)
        }
        var credits = JourneySourceCompletion.progress(merged,
            entries: entries + (LearningJourneyLibrary.journey?.lessons.map(\.entry) ?? []))
        for (key, value) in credits.values {
            switch value {
            case .completed(let wins):
                let pack = String(key.dropFirst("cleared/".count))
                let scope = sessionID.map { "hotseat." + $0 } ?? profileID
                let cloud = Set(defaults.array(forKey: completedKey(pack: pack, profileID: scope)) as? [Int] ?? [])
                let suffix = sessionID.map { ".hotseat." + $0 } ?? (profileID == "default" ? "" : "." + profileID)
                let mobile = Set(defaults.array(forKey: "mobile.completed." + pack + suffix) as? [Int] ?? [])
                let union = wins.union(cloud).union(mobile)
                credits.values[key] = cloud == union && mobile == union ? nil : .completed(union)
            case .fanLevels(let wins):
                let destination = sessionID.map { "HotSeat.\($0).FanLevelsPassed" }
                    ?? ArcadeStore.progressKey("FanLevelsPassed", profileID: profileID)
                let saved = Set(defaults.stringArray(forKey: destination) ?? [])
                let union = saved.union(wins)
                credits.values[key] = saved == union ? nil : .fanLevels(union)
            default: break
            }
        }
        try credits.apply(defaults: defaults, profileID: profileID, sessionID: sessionID)
    }
    @MainActor public static func journeySession(profileID: String, sessionID: String? = nil, defaults: UserDefaults = .standard) -> JourneySessionSnapshot? {
        let key = sessionID.map { "HotSeat.\($0).LearningJourneySession" }
            ?? ArcadeStore.progressKey("LearningJourneySession", profileID: profileID)
        return defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(JourneySessionSnapshot.self, from: $0) }
    }
    @MainActor public static func saveJourneySession(_ snapshot: JourneySessionSnapshot, profileID: String, sessionID: String? = nil,
                                                    defaults: UserDefaults = .standard) throws {
        let key = sessionID.map { "HotSeat.\($0).LearningJourneySession" }
            ?? ArcadeStore.progressKey("LearningJourneySession", profileID: profileID)
        let current = journeySession(profileID: profileID, sessionID: sessionID, defaults: defaults)
        guard current == nil || snapshot.updatedAt > current!.updatedAt else { return }
        defaults.set(try JSONEncoder().encode(snapshot), forKey: key)
    }
    public static func fanIdentifier(pack: URL, label: String) -> String {
        let packKey = ClassicFanPack.packID(pack).map { "catalogue:\($0)" } ?? "file:" + pack.lastPathComponent.lowercased()
        return "v2|" + packKey + "|" + label
    }
    @MainActor public static func fanLevels(profileID: String, sessionID: String? = nil, defaults: UserDefaults = .standard) -> Set<String> {
        let key = sessionID.map { "HotSeat.\($0).FanLevelsPassed" } ?? ArcadeStore.progressKey("FanLevelsPassed", profileID: profileID)
        var levels = Set(defaults.stringArray(forKey: key) ?? [])
        let credits = JourneySourceCompletion.progress(learning(profileID: profileID, sessionID: sessionID, defaults: defaults),
            entries: LearningJourneyLibrary.journey?.lessons.map(\.entry) ?? [])
        if case let .fanLevels(wins) = credits.values["FanLevelsPassed"] { levels.formUnion(wins) }
        return levels
    }
    @MainActor public static func saveFanLevel(pack: URL, label: String, profileID: String, sessionID: String? = nil,
                                             defaults: UserDefaults = .standard) {
        let key = sessionID.map { "HotSeat.\($0).FanLevelsPassed" } ?? ArcadeStore.progressKey("FanLevelsPassed", profileID: profileID)
        var levels = fanLevels(profileID: profileID, sessionID: sessionID, defaults: defaults)
        guard levels.insert(fanIdentifier(pack: pack, label: label)).inserted else { return }
        defaults.set(levels.sorted(), forKey: key)
    }
    public static func completedKey(pack: String, profileID: String) -> String { "GameCenterProgress.cleared.\(profileID).\(pack)" }
    @MainActor public static func completed(pack: String, profileID: String, defaults: UserDefaults = .standard) -> Set<Int> {
        var indices = Set(defaults.array(forKey: completedKey(pack: pack, profileID: profileID)) as? [Int] ?? [])
        let sessionID = profileID.hasPrefix("hotseat.") ? String(profileID.dropFirst(8)) : nil
        let credits = JourneySourceCompletion.progress(learning(profileID: profileID, sessionID: sessionID, defaults: defaults),
            entries: LearningJourneyLibrary.journey?.lessons.map(\.entry) ?? [])
        if case let .completed(wins) = credits.values["cleared/" + pack] { indices.formUnion(wins) }
        return indices
    }
    public static func classicProgress(_ saved: ClassicGameFlow.Progress?, completed: Set<Int>, ranks: [ClassicRank]) -> ClassicGameFlow.Progress {
        var progress = saved ?? .init(furthestReached: [:], passed: [])
        var passed = Set(progress.passed)
        for rank in ranks {
            for (position, index) in rank.levelIndices.enumerated() where completed.contains(index) {
                passed.insert("\(rank.name)#\(position)")
                progress.furthestReached[rank.name] = max(progress.furthestReached[rank.name] ?? 0, min(position + 1, rank.levelIndices.count - 1))
            }
        }
        progress.passed = passed.sorted()
        return progress
    }
    private static func portableClassicKey(_ key: String) -> Bool {
        key == "ClassicGameProgress" || key.hasPrefix("ClassicGameProgress.") && !key.contains(":source-") && !key.contains("/")
    }
    private static func portableL3Key(_ key: String) -> Bool {
        ["Classic", "Egyptian", "Shadow"].contains { key == "nativeL3\($0)Preview.v1.bundled" }
    }
}
