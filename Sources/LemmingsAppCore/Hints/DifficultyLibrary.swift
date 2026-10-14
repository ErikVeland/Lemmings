import Foundation
import CryptoKit
import NxlvKit

/// App adapter for the existing catalogue and loaders. Analysis files are disposable.
public enum DifficultyLibrary {
    public enum Source: Sendable {
        case classic(ClassicLevel, root: URL, rank: String?, number: Int)
        /// A fan level. The closure reads the level from its pack, for example with the Mac `FanLevelLibrary`.
        case fan(level: @Sendable () throws -> ClassicLevel)
        case lemmings2(URL, tribe: Int, level: Int)
        case lemmings3(URL, tribe: Lemmings3ClassicCampaign.Tribe, level: Int)
    }
    public struct Input: Sendable {
        public let entry: LevelPlaylistEntry
        public let source: Source
        public let isOfficial: Bool
        public let campaignOrder: Int
        public init(entry: LevelPlaylistEntry, source: Source, isOfficial: Bool, campaignOrder: Int) {
            self.entry = entry; self.source = source; self.isOfficial = isOfficial; self.campaignOrder = campaignOrder
        }
    }
    public struct Output: Sendable {
        public let candidates: [ProgressionCandidate]
        public let statistics: DifficultyCorpusStatistics
    }
    public static var directory: URL { directory(storage: .current()) }
    public static func directory(storage: AppStorage) -> URL {
        storage.applicationSupport.appendingPathComponent("Difficulty", isDirectory: true)
    }
    public static func metadata(_ level: ClassicLevel, rank: String?) -> DifficultyMetadataEvidence {
        .init(availableSkills: Dictionary(uniqueKeysWithValues: level.skills.map { ($0.key.rawValue, $0.value) }),
              population: level.lemmingCount, rescueRequirement: level.saveRequirement,
              timeLimitFrames: level.timeLimitMinutes * 60 * 17,
              interactingSystems: Set(level.objects.map(\.id)).count, rank: rank)
    }
    public static func analyse(_ inputs: [Input], sourceFailures: [String] = [], storage: AppStorage = .current(),
                               progress: @Sendable (Int, Int) async -> Void) async throws -> Output {
        let directory = Self.directory(storage: storage)
        let cache = DifficultyProfileCache(file: directory.appendingPathComponent("profiles.json"))
        var candidates: [ProgressionCandidate] = []
        var failures = sourceFailures.map { "Pack unavailable: " + $0 }
        var replays: [String: ClassicDOSReplay] = [:]
        if let data = try? Data(contentsOf: storage.resources.appendingPathComponent("Hints/solutions.json")),
           let bundled = try? JSONDecoder().decode([String: ClassicDOSReplay].self, from: data) { replays = bundled }
        let routes = (try? FileManager.default.contentsOfDirectory(at: ClassicRouteRecorder.folder(storage: storage),
            includingPropertiesForKeys: nil)) ?? []
        for url in routes.sorted(by: { $0.path < $1.path }) where url.pathExtension == "json" {
            if let data = try? Data(contentsOf: url), let replay = try? JSONDecoder().decode(ClassicDOSReplay.self, from: data),
               replays[replay.initialStateHash] == nil { replays[replay.initialStateHash] = replay }
        }
        var grounds: [String: ClassicGroundSet] = [:]
        var assets: [String: ClassicMainDATAssets] = [:]
        var l2Campaigns: [String: Lemmings2Campaign] = [:]
        var l3Campaigns: [String: Lemmings3ClassicCampaign] = [:]
        for (index, input) in inputs.enumerated() {
            try Task.checkCancellation()
            do {
                var key = DifficultyCacheKey(identity: input.entry.identity, levelRevision: input.entry.sourceRevision)
                var measured: DifficultyProfile?
                if case let .classic(level, root, rank, number) = input.source,
                   replays.values.contains(where: { $0.title == level.title && $0.rank == rank && $0.number == number }) {
                    do {
                        let groundKey = root.path + "#\(level.groundStyle)"
                        let ground: ClassicGroundSet
                        if let cached = grounds[groundKey] { ground = cached }
                        else { ground = try ClassicGroundSet.load(style: level.groundStyle, from: root); grounds[groundKey] = ground }
                        let main: ClassicMainDATAssets
                        if let cached = assets[root.path] { main = cached }
                        else { main = try ClassicMainDATAssets.load(from: root); assets[root.path] = main }
                        let special = level.specialStyle > 0
                            ? try ClassicSpecialGraphic.load(index: level.specialStyle - 1, from: root) : nil
                        let rendered = try ClassicLevelRenderer.render(level, groundSet: ground, specialGraphic: special)
                        let initial = try ClassicDOSSimulation(level: level, renderedLevel: rendered, mainDATAssets: main)
                        let hash = ClassicDOSReplayRecorder.stateHash(of: initial)
                        if let replay = replays[hash] {
                            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                            let replayRevision = SHA256.hash(data: try encoder.encode(replay)).map { String(format: "%02x", $0) }.joined()
                            key = DifficultyCacheKey(identity: input.entry.identity, levelRevision: input.entry.sourceRevision,
                                replayRevision: replayRevision, assetsRevision: hash + RunRecovery.bundledEngine)
                            if let cached = await cache.profile(for: key) { measured = cached }
                            else {
                                measured = try ClassicDifficultyAnalysis.analyse(initial: initial, replay: replay, key: key)
                                if let measured { try await cache.store(measured, flush: false) }
                            }
                        }
                    } catch is CancellationError { throw CancellationError() }
                    catch { failures.append(L10n.text("\(input.entry.levelNameSnapshot): replay analysis failed: \(error)")) }
                }
                let profile: DifficultyProfile
                if let measured { profile = measured }
                else if let cached = await cache.profile(for: key) { profile = cached }
                else {
                    let metadata: DifficultyMetadataEvidence
                    switch input.source {
                    case let .classic(level, _, rank, _): metadata = self.metadata(level, rank: rank)
                    case let .fan(load):
                        metadata = self.metadata(try load(), rank: nil)
                    case let .lemmings2(root, tribe, index):
                        let campaign: Lemmings2Campaign
                        if let cached = l2Campaigns[root.path] { campaign = cached }
                        else { campaign = try Lemmings2Campaign(root: root); l2Campaigns[root.path] = campaign }
                        let level = campaign.levels[tribe * 10 + index]
                        metadata = .init(availableSkills: Dictionary(level.skills.filter { $0.count > 0 }.map {
                            (Lemmings2Runtime.Skill(rawValue: $0.identifier)?.name.lowercased() ?? "l2-skill-\($0.identifier)", $0.count)
                        }, uniquingKeysWith: +), population: 60, rescueRequirement: max(1, 60 - level.allowedLossesForGold),
                        timeLimitFrames: Int(Double(level.timeLimitSeconds) * Lemmings2Runtime.ticksPerSecond),
                        interactingSystems: Set(level.objects.map(\.identifier)).count)
                    case let .lemmings3(root, tribe, index):
                        let campaign: Lemmings3ClassicCampaign
                        let campaignKey = root.path + "#\(tribe.rawValue)"
                        if let cached = l3Campaigns[campaignKey] { campaign = cached }
                        else { campaign = try Lemmings3ClassicCampaign(root: root, tribe: tribe); l3Campaigns[campaignKey] = campaign }
                        let level = campaign.levels[index]
                        metadata = .init(population: 20, rescueRequirement: 1,
                            timeLimitFrames: Int(Double(level.timeLimitSeconds) * Lemmings3Runtime.ticksPerSecond),
                            interactingSystems: level.enemyCount > 0 ? 1 : 0)
                    }
                    profile = DifficultyScorer.analyse(key: key, metadata: metadata)
                    try await cache.store(profile, flush: false)
                }
                candidates.append(.init(entry: input.entry, profile: profile, isOfficial: input.isOfficial,
                                        campaignOrder: input.campaignOrder))
            } catch is CancellationError { throw CancellationError() }
            catch { failures.append("\(input.entry.levelNameSnapshot): \(error)") }
            await progress(index + 1, inputs.count)
        }
        try await cache.save()
        let statistics: DifficultyCorpusStatistics
        let statisticsFile = directory.appendingPathComponent("concepts.json")
        if let data = try? Data(contentsOf: statisticsFile),
           let cached = try? JSONDecoder().decode(DifficultyCorpusStatistics.self, from: data),
           cached.isCurrent(for: candidates.map(\.profile)) { statistics = cached }
        else { statistics = DifficultyCorpusStatistics(profiles: candidates.map(\.profile)) }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encoder.encode(statistics).write(to: directory.appendingPathComponent("concepts.json"), options: .atomic)
        try encoder.encode(failures).write(to: directory.appendingPathComponent("analysis-failures.json"), options: .atomic)
        return Output(candidates: candidates, statistics: statistics)
    }
    public static func cachedProfiles(storage: AppStorage = .current()) -> [DifficultyProfile] {
        guard let data = try? Data(contentsOf: directory(storage: storage).appendingPathComponent("profiles.json")),
              let profiles = try? JSONDecoder().decode([DifficultyProfile].self, from: data) else { return [] }
        return profiles.filter { $0.analyserVersion == DifficultyModel.version && $0.key.simulationVersion == DifficultyModel.simulationVersion }
            .sorted {
                if $0.confidence != $1.confidence { return $0.confidence.value < $1.confidence.value }
                if $0.overallScore != $1.overallScore { return $0.overallScore > $1.overallScore }
                return $0.key.replayRevision < $1.key.replayRevision
            }
    }
    public static func saveDiagnostics(_ result: ProgressionResult, storage: AppStorage = .current()) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(result.diagnostics).write(to: directory(storage: storage).appendingPathComponent(result.policy.rawValue + ".json"), options: .atomic)
    }
}
