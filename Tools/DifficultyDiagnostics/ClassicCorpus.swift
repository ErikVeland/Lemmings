import Foundation
import CryptoKit
import NxlvKit

// The audit uses the app's archive reader and playlist store without recording progress.
@MainActor final class ArcadeStore {
    static let shared = ArcadeStore()
    func progressKey(_ key: String) -> String { key }
    nonisolated static func fingerprint(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

struct AuditedClassicLevel: Codable {
    let entry: LevelPlaylistEntry
    let profile: DifficultyProfile
    let official: Bool
    let order: Int
    let playable: Bool
    let initialHash: String?
    let issue: String?
    var candidate: ProgressionCandidate {
        .init(entry: entry, profile: profile, isOfficial: official, campaignOrder: order)
    }
}

struct ImportedFanReplay: Decodable {
    let title: String
    let packID: String
    let events: [ClassicDOSReplayEvent]
}

@main struct ClassicCorpusAudit {
    @MainActor static func main() throws {
        let args = CommandLine.arguments
        guard args.count == 4 || args.count == 5 else {
            print("Usage: ClassicCorpus RESOURCES SOLUTIONS OUTPUT [INSTALL_PROFILE_ID]")
            return
        }
        let resources = URL(fileURLWithPath: args[1]).standardizedFileURL
        let ports = resources.appendingPathComponent("Ports")
        let output = URL(fileURLWithPath: args[3]).standardizedFileURL
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let decoder = JSONDecoder()
        var replays = try decoder.decode([String: ClassicDOSReplay].self, from: Data(contentsOf: URL(fileURLWithPath: args[2])))
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Ultimate Lemmings")
        for file in ((try? FileManager.default.contentsOfDirectory(at: support.appendingPathComponent("ClassicRoutes"), includingPropertiesForKeys: nil)) ?? []).sorted(by: { $0.path < $1.path }) {
            if let data = try? Data(contentsOf: file), let replay = try? decoder.decode(ClassicDOSReplay.self, from: data),
               replay.expected?.didWin == true, replays[replay.initialStateHash] == nil { replays[replay.initialStateHash] = replay }
        }
        let revision = ProcessInfo.processInfo.environment["DIFFICULTY_SIMULATION_REVISION"] ?? DifficultyModel.simulationVersion
        let fanClock: ClassicDOSClock = ProcessInfo.processInfo.environment["CLASSIC_FAN_CLOCK"] == "dos"
            ? .dos : .golems
        let fanOnly = ProcessInfo.processInfo.environment["CLASSIC_AUDIT_FAN_ONLY"] == "1"
        let cacheURL = output.appendingPathComponent("audit.json")
        let cached = (try? decoder.decode([AuditedClassicLevel].self, from: Data(contentsOf: cacheURL))) ?? []
        let cache = Dictionary(cached.map { ($0.entry.identity, $0) }, uniquingKeysWith: { _, last in last })
        let rebuild = ProcessInfo.processInfo.environment["CLASSIC_AUDIT_REBUILD"] == "1"
        var rows: [AuditedClassicLevel] = rebuild ? cached : []
        var problems: [String] = []
        var assets: [String: ClassicMainDATAssets] = [:]
        var grounds: [String: ClassicGroundSet] = [:]
        func mainAssets(_ root: URL) throws -> ClassicMainDATAssets {
            if let value = assets[root.path] { return value }
            let value = try ClassicMainDATAssets.load(from: root); assets[root.path] = value; return value
        }
        func metadata(_ level: ClassicLevel, rank: String?) -> DifficultyMetadataEvidence {
            .init(availableSkills: Dictionary(uniqueKeysWithValues: level.skills.map { ($0.key.rawValue, $0.value) }),
                  population: level.lemmingCount, rescueRequirement: level.saveRequirement,
                  timeLimitFrames: level.timeLimitMinutes * 60 * 17,
                  interactingSystems: Set(level.objects.map(\.id)).count, rank: rank)
        }
        func audit(entry: LevelPlaylistEntry, level: ClassicLevel, rank: String?, official: Bool, order: Int,
                   initial: () throws -> ClassicDOSSimulation) -> AuditedClassicLevel {
            var key = DifficultyCacheKey(identity: entry.identity, levelRevision: entry.sourceRevision,
                assetsRevision: "classic-corpus-probes-10", simulationVersion: revision)
            var profile = DifficultyScorer.analyse(key: key, metadata: metadata(level, rank: rank))
            var hash: String?
            var playable = false
            var issue: String?
            do {
                let simulation = try initial()
                playable = true
                let stateHash = ClassicDOSReplayRecorder.stateHash(of: simulation); hash = stateHash
                if let replay = replays[stateHash], replay.expected?.didWin == true {
                    let replayHash = ArcadeStore.fingerprint(try encoder.encode(replay))
                    key = DifficultyCacheKey(identity: entry.identity, levelRevision: entry.sourceRevision,
                        replayRevision: replayHash, assetsRevision: stateHash + ":probes-10", simulationVersion: revision)
                    if let saved = cache[entry.identity], saved.profile.key == key { profile = saved.profile }
                    else { profile = try ClassicDifficultyAnalysis.analyse(initial: simulation, replay: replay, key: key, maximumProbeRuns: 10) }
                }
            } catch { issue = String(describing: error) }
            return .init(entry: entry, profile: profile, official: official, order: order,
                         playable: playable, initialHash: hash, issue: issue)
        }
        func entry(_ identity: LevelCatalogueIdentity, revision: String, pack: String, title: String, number: Int) throws -> LevelPlaylistEntry {
            let digest = Array(SHA256.hash(data: Data((identity.packID + "\u{0}" + identity.levelID).utf8)))
            let uuid = UUID(uuid: (digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6], digest[7],
                                   digest[8], digest[9], digest[10], digest[11], digest[12], digest[13], digest[14], digest[15]))
            return try .init(id: uuid, identity: identity, catalogueRevision: "1.2-runtime-v2", sourceRevision: revision,
                             packNameSnapshot: pack, levelNameSnapshot: title.isEmpty ? "Level \(number)" : title, levelNumberSnapshot: number)
        }
        var campaigns: [(ClassicDataSet, URL)] = []
        var seen: Set<String> = []
        for root in try FileManager.default.contentsOfDirectory(at: ports, includingPropertiesForKeys: nil).sorted(by: { $0.path < $1.path }) {
            guard let set = try? ClassicDataSet.detect(directory: root), set.kind != .scanned,
                  set.title != nil, seen.insert(set.identifierKey).inserted else { continue }
            campaigns.append((set, root))
        }
        if let set = try PortExclusivePack.dataSet(amigaRoot: ports.appendingPathComponent("amiga_extracted"), portsRoot: ports) {
            campaigns.append((set, ports))
        }
        campaigns.sort { ($0.0.title?.canonOrder ?? 999) < ($1.0.title?.canonOrder ?? 999) }
        for (set, root) in campaigns where !rebuild && !fanOnly {
            guard let fingerprint = FanLevelLibrary.classicSourceRevision(
                for: set.title, root: root) else { throw LevelPlaylistError.invalidEntry }
            for (index, item) in set.campaign.levels.enumerated() {
                let identity = LevelCatalogueIdentity(engine: .classic, packID: set.identifierKey,
                    levelID: "\(index):\(item.rank):\(item.number):\(item.archiveFile):\(item.archiveSection)")
                let saved = try entry(identity, revision: fingerprint, pack: set.name, title: item.level.title, number: index + 1)
                let row = audit(entry: saved, level: item.level, rank: item.rank, official: true, order: rows.count) {
                    let art = set.title == .ohYesMoreLemmings ? PortExclusivePack.artworkDirectory(for: item, portsRoot: ports) : root
                    let fallback = set.title == .ohYesMoreLemmings ? PortExclusivePack.fallbackArtworkDirectory(for: item, portsRoot: ports) : nil
                    let groundKey = art.path + "#\(item.level.groundStyle)"
                    let ground: ClassicGroundSet
                    if let found = grounds[groundKey] { ground = found }
                    else { ground = try ClassicGroundSet.load(style: item.level.groundStyle, from: art, fallbackDirectory: fallback); grounds[groundKey] = ground }
                    let special = item.level.specialStyle > 0
                        ? try ClassicSpecialGraphic.load(index: item.level.specialStyle - 1, from: art, fallbackDirectory: fallback) : nil
                    let rendered = try ClassicLevelRenderer.render(item.level, groundSet: ground, specialGraphic: special)
                    return try ClassicDOSSimulation(level: item.level, renderedLevel: rendered, mainDATAssets: mainAssets(fallback ?? art),
                                                    mechanics: ClassicDOSMechanics(title: set.title, rank: item.rank))
                }
                rows.append(row)
                if index % 10 == 0 { print("\(set.name): \(index + 1)/\(set.campaign.levels.count)"); fflush(stdout) }
            }
            try encoder.encode(rows).write(to: cacheURL, options: .atomic)
        }
        let packFolders = fanOnly ? [resources.appendingPathComponent("LevelPacks")]
            : [resources.appendingPathComponent("LevelPacks"), FanLevelLibrary.downloadFolder]
                + (FanLevelLibrary.folder.map { [$0] } ?? [])
        let packs = FanLevelLibrary.packs(in: packFolders)
        for (packIndex, pack) in packs.enumerated() where !rebuild {
            do {
                let entries = try FanLevelLibrary.validatedEntries(in: pack)
                guard let fingerprint = FanLevelLibrary.archiveFingerprint(pack) else { throw LevelPlaylistError.invalidEntry }
                for (index, item) in entries.enumerated() {
                    let identity = LevelCatalogueIdentity(engine: .classic, packID: "fan:" + FanLevelLibrary.catalogueID(pack), levelID: item.file + "#\(item.section ?? -1)")
                    do {
                        let loaded = try FanLevelLibrary.level(item, in: pack)
                        let saved = try entry(identity, revision: fingerprint, pack: FanLevelLibrary.displayName(of: pack), title: item.label, number: index + 1)
                        rows.append(audit(entry: saved, level: loaded.0, rank: nil, official: false, order: rows.count) {
                            let ground = try FanLevelLibrary.groundSet(for: loaded.0, styleName: loaded.1, portsRoot: ports, pack: pack, entry: item)
                            let special = try FanLevelLibrary.specialGraphic(for: loaded.0, entry: item, pack: pack, portsRoot: ports)
                            let rendered = try ClassicLevelRenderer.render(loaded.0, groundSet: ground, specialGraphic: special,
                                objectSemantics: .forFanLevel(loaded.0, groundSet: ground))
                            return try ClassicDOSSimulation(level: loaded.0, renderedLevel: rendered,
                                mainDATAssets: mainAssets(ports.appendingPathComponent("lemmings_dos_1991-07-30")),
                                clock: fanClock)
                        })
                    } catch { problems.append("\(pack.lastPathComponent) / \(item.label): \(error)") }
                }
            } catch { problems.append("\(pack.lastPathComponent): \(error)") }
            if packIndex % 10 == 0 {
                print("Fan packs \(packIndex + 1)/\(packs.count), audited \(rows.count) levels"); fflush(stdout)
                try encoder.encode(rows).write(to: cacheURL, options: .atomic)
            }
        }
        if fanOnly {
            try encoder.encode(rows).write(to: cacheURL, options: .atomic)
            try encoder.encode(problems).write(to: output.appendingPathComponent("failures.json"), options: .atomic)
            print("Fan-only audit: \(rows.count) levels, \(problems.count) failures")
            return
        }
        if rebuild {
            problems = (try? decoder.decode([String].self, from: Data(contentsOf: output.appendingPathComponent("failures.json")))) ?? []
            let importedURL = output.appendingPathComponent("imported-replay-candidates.json")
            let imported = (try? decoder.decode([ImportedFanReplay].self, from: Data(contentsOf: importedURL))) ?? []
            var importResults: [String] = []
            var verified: [ClassicDOSReplay] = []
            for candidate in imported {
                do {
                    guard let pack = packs.first(where: { "fan:" + FanLevelLibrary.catalogueID($0) == candidate.packID }) else { throw LevelPlaylistError.invalidEntry }
                    var match: (FanLevelLibrary.Entry, ClassicLevel, String?)?
                    for item in try FanLevelLibrary.validatedEntries(in: pack) {
                        let loaded = try FanLevelLibrary.level(item, in: pack)
                        if loaded.0.title.trimmingCharacters(in: .whitespacesAndNewlines) == candidate.title {
                            match = (item, loaded.0, loaded.1); break
                        }
                    }
                    guard let (item, level, style) = match,
                          let index = rows.firstIndex(where: { $0.entry.identity.packID == candidate.packID
                              && $0.entry.identity.levelID == item.file + "#\(item.section ?? -1)" }) else { throw LevelPlaylistError.invalidEntry }
                    let ground = try FanLevelLibrary.groundSet(for: level, styleName: style, portsRoot: ports, pack: pack, entry: item)
                    let special = try FanLevelLibrary.specialGraphic(for: level, entry: item, pack: pack, portsRoot: ports)
                    let rendered = try ClassicLevelRenderer.render(level, groundSet: ground, specialGraphic: special,
                        objectSemantics: .forFanLevel(level, groundSet: ground))
                    let initial = try ClassicDOSSimulation(level: level, renderedLevel: rendered,
                        mainDATAssets: mainAssets(ports.appendingPathComponent("lemmings_dos_1991-07-30")),
                        clock: fanClock)
                    let hash = ClassicDOSReplayRecorder.stateHash(of: initial)
                    let replay = ClassicDOSReplay(rank: candidate.packID, number: rows[index].entry.levelNumberSnapshot,
                        title: level.title, initialStateHash: hash, events: candidate.events)
                    let outcome = try ClassicDOSReplayPlayer.run(replay, simulation: initial)
                    guard outcome.didWin else { throw DifficultyAnalysisError.replayDidNotWin }
                    let witness = ClassicDOSReplay(rank: replay.rank, number: replay.number, title: replay.title,
                        initialStateHash: hash, events: replay.events, expected: outcome)
                    let old = rows[index]
                    let key = DifficultyCacheKey(identity: old.entry.identity, levelRevision: old.entry.sourceRevision,
                        replayRevision: ArcadeStore.fingerprint(try encoder.encode(witness)), assetsRevision: hash + ":probes-10", simulationVersion: revision)
                    // The analyser reruns the full outcome checks before any perturbation.
                    let profile = try ClassicDifficultyAnalysis.analyse(initial: initial, replay: witness, key: key, maximumProbeRuns: 10)
                    if old.profile.confidence == .low || profile.overallScore < old.profile.overallScore {
                        rows[index] = .init(entry: old.entry, profile: profile, official: false, order: old.order,
                                            playable: true, initialHash: hash, issue: nil)
                    }
                    verified.append(witness)
                    importResults.append("\(candidate.title): verified native win")
                } catch { importResults.append("\(candidate.title): rejected: \(error)") }
            }
            try encoder.encode(importResults).write(to: output.appendingPathComponent("imported-replay-validation.json"), options: .atomic)
            try encoder.encode(verified).write(to: output.appendingPathComponent("verified-fan-replays.json"), options: .atomic)
            print("Imported fan replay wins: \(verified.count)/\(imported.count)")
        }
        try encoder.encode(rows).write(to: cacheURL, options: .atomic)
        try encoder.encode(problems).write(to: output.appendingPathComponent("failures.json"), options: .atomic)
        let official = rows.filter(\.official)
        guard official.allSatisfy(\.playable) else { throw LevelPlaylistError.invalidEntry }
        var config = ProgressionConfiguration(); config.maximumLevels = LevelPlaylist.maximumEntries
        // Retain low-confidence candidates, but never insert a copy of an official
        // level as a fan bridge. The graph prefers comparable replay-backed evidence.
        var usedHashes = Set(official.compactMap(\.initialHash))
        let eligible = rows.filter { row in
            guard row.playable else { return false }
            if row.official { return true }
            guard let hash = row.initialHash else { return false }
            return usedHashes.insert(hash).inserted
        }
        let candidates = eligible.map(\.candidate)
        let statistics = DifficultyCorpusStatistics(profiles: rows.map(\.profile))
        let result = try ProgressionGenerator.generate(candidates: candidates, policy: .originalPlus, configuration: config, statistics: statistics)
        let officialIDs = official.map { $0.entry.identity }
        guard result.entries.filter({ officialIDs.contains($0.identity) }).map(\.identity) == officialIDs else { throw LevelPlaylistError.invalidSequence }
        let playlist = try LevelPlaylist(id: UUID(uuidString: "DF76E714-E817-4754-873A-E5F9432F767A")!, name: "Classic Complete + Fan Bridges",
            entries: result.entries, createdAt: Date(timeIntervalSince1970: 1790467200))
        try encoder.encode(playlist).write(to: output.appendingPathComponent("playlist.json"), options: .atomic)
        try encoder.encode(result.diagnostics).write(to: output.appendingPathComponent("selections.json"), options: .atomic)
        try encoder.encode(result.warnings).write(to: output.appendingPathComponent("warnings.json"), options: .atomic)
        try encoder.encode(statistics).write(to: output.appendingPathComponent("concepts.json"), options: .atomic)
        if args.count == 5 {
            let store = try LevelPlaylistStore(profileID: args[4])
            if store.playlist(id: playlist.id) == nil { try store.add(playlist) }
            else { try store.update(playlist) }
            let reloaded = try LevelPlaylistStore(profileID: args[4])
            guard reloaded.playlist(id: playlist.id) == playlist else { throw LevelPlaylistError.invalidSequence }
            print("Installed playlist: \(store.file.path)")
        }
        print("Audited \(rows.count) levels; \(official.count) official; \(rows.filter { !$0.official && $0.profile.confidence != .low }.count) replay-backed fan levels.")
        print("Playlist: \(playlist.entries.count) entries, all \(official.count) official levels retained.")
    }
}
