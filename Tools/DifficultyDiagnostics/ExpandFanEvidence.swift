import Foundation
import CryptoKit
import NxlvKit

@MainActor final class ArcadeStore {
    static let shared = ArcadeStore()
    func progressKey(_ key: String) -> String { key }
}
struct EvidenceRow: Codable {
    let entry: LevelPlaylistEntry
    var profile: DifficultyProfile
    let official: Bool
    let order: Int
    let playable: Bool
    let initialHash: String?
    let issue: String?
}
struct RetimedFanWitness: Codable {
    let candidateReplaySHA256: String
    let eventIndex: Int
    let originalTick: Int
    let nativeTick: Int
}
struct GolemsObjectComparison: Codable {
    let identity: LevelCatalogueIdentity
    let sourceRevision: String
    let replayRevision: String
    let nativeInitialHash: String
    let golemsInitialHash: String
    let nativeSaved: Int
    let nativeTicks: Int
    let golemsSaved: Int?
    let golemsTicks: Int?
    let golemsDidWin: Bool
    let error: String?
}
@main struct ExpandFanEvidence {
    @MainActor static func main() throws {
        let args = CommandLine.arguments
        guard args.count == 4 else { fatalError("Usage: ExpandFanEvidence RESOURCES AUDIT OUTPUT_DIRECTORY") }
        let root = URL(fileURLWithPath: args[1]), ports = root.appendingPathComponent("Ports")
        let output = URL(fileURLWithPath: args[3])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let decoder = JSONDecoder()
        var rows = try decoder.decode([EvidenceRow].self, from: Data(contentsOf: URL(fileURLWithPath: args[2])))
        var solutions = try decoder.decode([String: ClassicDOSReplay].self, from: Data(contentsOf: root.appendingPathComponent("Hints/solutions.json")))
        if let extras = try? decoder.decode([String: ClassicDOSReplay].self, from: Data(contentsOf: root.appendingPathComponent("Progression/solutions.json"))) { solutions.merge(extras) { a, _ in a } }
        if let path = ProcessInfo.processInfo.environment["FAN_CANDIDATE_SOLUTIONS"],
           let candidates = try? decoder.decode([String: ClassicDOSReplay].self, from: Data(contentsOf: URL(fileURLWithPath: path))) {
            solutions.merge(candidates) { a, _ in a }
        }
        let savedURL = output.appendingPathComponent("solutions.json")
        var found = (try? decoder.decode([String: ClassicDOSReplay].self, from: Data(contentsOf: savedURL))) ?? [:]
        var foundHashes = Set(found.values.map(\.initialStateHash))
        solutions.merge(found) { a, _ in a }
        var solverReplays: [String: [ClassicDOSReplay]] = [:]
        if let directory = ProcessInfo.processInfo.environment["FAN_SOLVER_REPLAYS"] {
            for url in (try? FileManager.default.contentsOfDirectory(
                at: URL(fileURLWithPath: directory), includingPropertiesForKeys: nil
            ))?.filter({ $0.pathExtension == "json" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) ?? [] {
                let name = url.deletingPathExtension().lastPathComponent
                guard name.count >= 64,
                      let replay = try? decoder.decode(ClassicDOSReplay.self, from: Data(contentsOf: url)) else { continue }
                solverReplays[String(name.prefix(64)), default: []].append(replay)
            }
        }
        var templates: [String: [[ClassicDOSReplayEvent]]] = [:]
        func geometry(_ sim: ClassicDOSSimulation) -> String { SHA256.hash(data: sim.terrain.solidMask + sim.terrain.steelMask).description }
        let verifyOnly = ProcessInfo.processInfo.environment["FAN_VERIFY_ONLY"] == "1"
        let rebaseExpected = ProcessInfo.processInfo.environment["FAN_REBASE_EXPECTED"] == "1"
        let compareGolemsObjects = ProcessInfo.processInfo.environment["FAN_COMPARE_GOLEMS_OBJECTS"] == "1"
        let golemsObjects = ProcessInfo.processInfo.environment["FAN_GOLEMS_OBJECTS"] == "1"
        let fanClock: ClassicDOSClock = ProcessInfo.processInfo.environment["CLASSIC_FAN_CLOCK"] == "dos" ? .dos : .golems
        let describeOnly = ProcessInfo.processInfo.environment["FAN_DESCRIBE_ONLY"] == "1"
        guard !rebaseExpected || (verifyOnly && !compareGolemsObjects && !describeOnly) else {
            throw LevelPlaylistError.invalidPool
        }
        guard !compareGolemsObjects || (verifyOnly && !describeOnly) else { throw LevelPlaylistError.invalidPool }
        var verifiedCount = 0
        var golemsComparisons: [GolemsObjectComparison] = []
        let semanticsOnly = ProcessInfo.processInfo.environment["FAN_SEMANTICS_ONLY"] == "1"
        var portDescriptors: [String: [String: Any]] = [:]
        func describe(_ identity: LevelCatalogueIdentity, _ level: ClassicLevel, _ sim: ClassicDOSSimulation) throws {
            guard ProcessInfo.processInfo.environment["FAN_PORT_AUDIT"] == "1" else { return }
            var fields = try JSONSerialization.jsonObject(with: encoder.encode(level)) as! [String: Any]
            fields["skills"] = Dictionary(uniqueKeysWithValues: level.skills.map { ($0.key.rawValue, $0.value) })
            fields["geometryHash"] = geometry(sim)
            fields["entranceCount"] = sim.configuration.entrances.count
            fields["exitTriggerCount"] = sim.configuration.triggers.filter { $0.effect == .exit }.count
            fields["totalLemmings"] = sim.configuration.totalLemmings
            fields["requiredToSave"] = sim.configuration.requiredToSave
            portDescriptors[identity.packID + "\0" + identity.levelID] = fields
        }
        var officialScenarios = Set<String>()
        var fanScenarios: [String: String] = [:]
        func scenario(_ level: ClassicLevel, _ sim: ClassicDOSSimulation) throws -> String {
            var fields = try JSONSerialization.jsonObject(with: encoder.encode(level)) as! [String: Any]
            fields.removeValue(forKey: "title"); fields.removeValue(forKey: "startX")
            fields["skills"] = Dictionary(uniqueKeysWithValues: level.skills.map { ($0.key.rawValue, $0.value) })
            // Rendered masks capture asset differences. Source names and the
            // engine's release variant are not a distinct teaching puzzle.
            let bytes = try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
            return SHA256.hash(data: bytes + sim.terrain.solidMask + sim.terrain.steelMask).description
        }
        var nearbyTemplates: [(sketch: [UInt64], events: [ClassicDOSReplayEvent])] = []
        func sketch(_ sim: ClassicDOSSimulation) -> [UInt64] {
            var result = Array(repeating: UInt64(0), count: 64)
            var index = 0
            for y in stride(from: 0, to: 160, by: 8) {
                for x in stride(from: 0, to: 1600, by: 8) {
                    if sim.terrain.isSolid(x: x, y: y) { result[index / 64] |= UInt64(1) << (index % 64) }
                    index += 1
                }
            }
            return result
        }
        var mainCache: [String: ClassicMainDATAssets] = [:]
        func assets(_ url: URL) throws -> ClassicMainDATAssets {
            if let value = mainCache[url.path] { return value }
            let value = try ClassicMainDATAssets.load(from: url); mainCache[url.path] = value; return value
        }
        var sets: [(ClassicDataSet, URL)] = []
        var seenSets = Set<String>()
        for url in try FileManager.default.contentsOfDirectory(at: ports, includingPropertiesForKeys: nil).sorted(by: { $0.path < $1.path }) {
            if let set = try? ClassicDataSet.detect(directory: url), set.kind != .scanned, set.title != nil, seenSets.insert(set.identifierKey).inserted { sets.append((set,url)) }
        }
        if let set = try PortExclusivePack.dataSet(amigaRoot: ports.appendingPathComponent("amiga_extracted"), portsRoot: ports) { sets.append((set,ports)) }
        for (set,url) in sets {
            for (index, item) in set.campaign.levels.enumerated() {
                let art = set.title == .ohYesMoreLemmings ? PortExclusivePack.artworkDirectory(for: item, portsRoot: ports) : url
                let fallback = set.title == .ohYesMoreLemmings ? PortExclusivePack.fallbackArtworkDirectory(for: item, portsRoot: ports) : nil
                let ground = try ClassicGroundSet.load(style: item.level.groundStyle, from: art, fallbackDirectory: fallback)
                let special = item.level.specialStyle > 0 ? try ClassicSpecialGraphic.load(index: item.level.specialStyle - 1, from: art, fallbackDirectory: fallback) : nil
                let rendered = try ClassicLevelRenderer.render(item.level, groundSet: ground, specialGraphic: special)
                let sim = try ClassicDOSSimulation(level: item.level, renderedLevel: rendered, mainDATAssets: assets(fallback ?? art), mechanics: ClassicDOSMechanics(title: set.title, rank: item.rank))
                try describe(.init(engine: .classic, packID: set.identifierKey,
                    levelID: "\(index):\(item.rank):\(item.number):\(item.archiveFile):\(item.archiveSection)"), item.level, sim)
                officialScenarios.insert(try scenario(item.level, sim))
                if let replay = solutions[ClassicDOSReplayRecorder.stateHash(of: sim)] { templates[geometry(sim), default: []].append(replay.events); nearbyTemplates.append((sketch(sim), replay.events)) }
            }
        }
        let rowIndex = Dictionary(uniqueKeysWithValues: rows.indices.map { (rows[$0].entry.identity, $0) })
        var attempts = 0, distinct = Set<String>(), failures: [String] = []
        var retimedWitnesses: [String: RetimedFanWitness] = [:]
        let measuredPacks = Set(rows.filter { !$0.official && $0.profile.confidence != .low }.map { $0.entry.identity.packID })
        let onlyPack = ProcessInfo.processInfo.environment["FAN_ONLY_PACK"]
        let onlyPacks = ProcessInfo.processInfo.environment["FAN_ONLY_PACKS_FILE"].flatMap {
            try? String(contentsOfFile: $0, encoding: .utf8)
        }.map { Set($0.split(whereSeparator: \.isNewline).map(String.init)) }
        let packs = FanLevelLibrary.packs(in: [root.appendingPathComponent("LevelPacks"), FanLevelLibrary.downloadFolder]).filter {
            let packID = "fan:" + FanLevelLibrary.catalogueID($0)
            return (onlyPack == nil || onlyPack == packID) && (onlyPacks?.contains(packID) ?? true)
                && (!(semanticsOnly || verifyOnly) || measuredPacks.contains(packID))
        }
        func save() throws {
            try encoder.encode(rows).write(to: output.appendingPathComponent("audit.json"), options: .atomic)
            try encoder.encode(found).write(to: savedURL, options: .atomic)
            try encoder.encode(officialScenarios.sorted()).write(to: output.appendingPathComponent("official-scenarios.json"), options: .atomic)
            try encoder.encode(fanScenarios).write(to: output.appendingPathComponent("fan-scenarios.json"), options: .atomic)
            if !portDescriptors.isEmpty {
                try JSONSerialization.data(withJSONObject: portDescriptors, options: [.sortedKeys]).write(to: output.appendingPathComponent("port-descriptors.json"), options: .atomic)
            }
            try encoder.encode(failures).write(to: output.appendingPathComponent("failures.json"), options: .atomic)
            if !retimedWitnesses.isEmpty {
                try encoder.encode(retimedWitnesses).write(to: output.appendingPathComponent("retimed-witnesses.json"), options: .atomic)
            }
            if compareGolemsObjects {
                try encoder.encode(golemsComparisons).write(to: output.appendingPathComponent("golems-object-comparisons.json"), options: .atomic)
            }
        }
        for (packNumber, pack) in packs.enumerated() {
            for item in try FanLevelLibrary.validatedEntries(in: pack) {
                let id = LevelCatalogueIdentity(engine: .classic, packID: "fan:" + FanLevelLibrary.catalogueID(pack), levelID: item.file + "#\(item.section ?? -1)")
                guard let index = rowIndex[id], describeOnly || ((semanticsOnly || verifyOnly) ? rows[index].profile.confidence != .low : rows[index].profile.confidence == .low) else { continue }
                do {
                    let (level, style) = try FanLevelLibrary.level(item, in: pack)
                    let ground = try FanLevelLibrary.groundSet(for: level, styleName: style, portsRoot: ports, pack: pack, entry: item)
                    let special = try FanLevelLibrary.specialGraphic(for: level, entry: item, pack: pack, portsRoot: ports)
                    let rendered = try ClassicLevelRenderer.render(level, groundSet: ground, specialGraphic: special,
                        objectSemantics: (compareGolemsObjects || golemsObjects) ? .golems : .forFanLevel(level, groundSet: ground))
                    let initial = try ClassicDOSSimulation(level: level, renderedLevel: rendered,
                        mainDATAssets: assets(ports.appendingPathComponent("lemmings_dos_1991-07-30")), clock: fanClock)
                    try describe(id, level, initial)
                    let hash = ClassicDOSReplayRecorder.stateHash(of: initial)
                    guard compareGolemsObjects || hash == rows[index].initialHash else { throw LevelPlaylistError.invalidEntry }
                    if describeOnly { continue }
                    if verifyOnly {
                        if compareGolemsObjects {
                            let row = rows[index]
                            guard FanLevelLibrary.archiveFingerprint(pack) == row.entry.sourceRevision,
                                  let nativeHash = row.initialHash,
                                  let stored = solutions[row.profile.key.replayRevision] ?? solutions[nativeHash],
                                  stored.initialStateHash == nativeHash,
                                  let expected = stored.expected, expected.didWin else { throw LevelPlaylistError.invalidEntry }
                            let replayRevision = SHA256.hash(data: try encoder.encode(stored)).description
                            guard row.profile.key.replayRevision == replayRevision ||
                                  row.profile.key.replayRevision == String(replayRevision.dropFirst("SHA256 digest: ".count)) else {
                                throw LevelPlaylistError.invalidEntry
                            }
                            let replay = ClassicDOSReplay(rank: id.packID, number: row.entry.levelNumberSnapshot,
                                title: level.title, initialStateHash: hash, events: stored.events)
                            var outcome: ClassicDOSReplayOutcome?
                            var replayError: String?
                            do { outcome = try ClassicDOSReplayPlayer.run(replay, simulation: initial, verify: false) }
                            catch { replayError = String(describing: error) }
                            golemsComparisons.append(GolemsObjectComparison(identity: id,
                                sourceRevision: row.entry.sourceRevision, replayRevision: row.profile.key.replayRevision,
                                nativeInitialHash: nativeHash, golemsInitialHash: hash,
                                nativeSaved: expected.saved, nativeTicks: expected.ticks,
                                golemsSaved: outcome?.saved, golemsTicks: outcome?.ticks,
                                golemsDidWin: outcome?.didWin ?? false, error: replayError))
                            continue
                        }
                        guard FanLevelLibrary.archiveFingerprint(pack) == rows[index].entry.sourceRevision,
                              let stored = solutions[rows[index].profile.key.replayRevision] ?? solutions[hash],
                              stored.initialStateHash == hash,
                              let expected = stored.expected, expected.didWin else { throw LevelPlaylistError.invalidEntry }
                        let replay = ClassicDOSReplay(rank: id.packID, number: rows[index].entry.levelNumberSnapshot,
                            title: level.title, initialStateHash: hash, events: stored.events, expected: expected)
                        let digest = SHA256.hash(data: try encoder.encode(replay)).description
                        let storedDigest = SHA256.hash(data: try encoder.encode(stored)).description
                        let replayRevision = rows[index].profile.key.replayRevision
                        guard [digest, storedDigest].contains(where: {
                            replayRevision == $0 || replayRevision == String($0.dropFirst("SHA256 digest: ".count))
                        }) else {
                            throw NSError(domain: "Evidence", code: 1, userInfo: [NSLocalizedDescriptionKey:
                                "Profile and bundled witness differ: \(level.title); target \(digest); stored \(storedDigest)"])
                        }
                        let result = try ClassicDOSReplayPlayer.run(replay, simulation: initial,
                            verify: !rebaseExpected)
                        guard result.didWin else { throw DifficultyAnalysisError.replayDidNotWin }
                        if rebaseExpected {
                            let updated = ClassicDOSReplay(rank: stored.rank, number: stored.number,
                                title: stored.title, initialStateHash: hash, events: stored.events,
                                expected: result)
                            let revision = SHA256.hash(data: try encoder.encode(updated)).description
                            let key = DifficultyCacheKey(identity: id,
                                levelRevision: rows[index].entry.sourceRevision,
                                replayRevision: revision, assetsRevision: hash + ":probes-10")
                            rows[index].profile = try ClassicDifficultyAnalysis.analyse(
                                initial: initial, replay: updated, key: key, maximumProbeRuns: 10)
                            found[revision] = updated
                            found[hash] = updated
                        }
                        verifiedCount += 1
                        continue
                    }
                    let scenarioHash = try scenario(level, initial)
                    fanScenarios[id.packID + "\0" + id.levelID] = scenarioHash
                    if semanticsOnly { continue }
                    var witness: ClassicDOSReplay?
                    for saved in (solverReplays[hash] ?? []) + (solutions[hash].map { [$0] } ?? []) where witness == nil {
                        let candidate = ClassicDOSReplay(rank: id.packID, number: rows[index].entry.levelNumberSnapshot,
                            title: level.title, initialStateHash: hash, events: saved.events)
                        if let outcome = try? ClassicDOSReplayPlayer.run(
                            candidate, simulation: initial, verify: false, stopWhenUnwinnable: true
                        ), outcome.didWin {
                            witness = ClassicDOSReplay(rank: candidate.rank, number: candidate.number, title: candidate.title,
                                initialStateHash: hash, events: candidate.events, expected: outcome)
                        }
                        if witness == nil, ProcessInfo.processInfo.environment["FAN_RETIME_SEARCH"] == "1",
                           saved.events.count <= 24 {
                            let radius = min(8, max(1, Int(ProcessInfo.processInfo.environment["FAN_RETIME_RADIUS"] ?? "2") ?? 2))
                            let minimum = min(radius, max(1,
                                Int(ProcessInfo.processInfo.environment["FAN_RETIME_MIN_RADIUS"] ?? "1") ?? 1))
                            let offsets = (minimum...radius).flatMap { [-$0, $0] }
                            for eventIndex in saved.events.indices where witness == nil {
                                for offset in offsets where witness == nil {
                                    let original = saved.events[eventIndex]
                                    let shiftedTick = original.tick + offset
                                    guard shiftedTick >= 0 else { continue }
                                    var shifted = saved.events
                                    shifted[eventIndex] = ClassicDOSReplayEvent(
                                        tick: shiftedTick, action: original.action, afterTick: original.afterTick)
                                    let shiftedReplay = ClassicDOSReplay(rank: id.packID,
                                        number: rows[index].entry.levelNumberSnapshot, title: level.title,
                                        initialStateHash: hash, events: shifted)
                                    attempts += 1
                                    if let outcome = try? ClassicDOSReplayPlayer.run(shiftedReplay,
                                        simulation: initial, verify: false), outcome.didWin {
                                        witness = ClassicDOSReplay(rank: shiftedReplay.rank,
                                            number: shiftedReplay.number, title: shiftedReplay.title,
                                            initialStateHash: hash, events: shifted, expected: outcome)
                                        retimedWitnesses[id.packID + "\0" + id.levelID] = RetimedFanWitness(
                                            candidateReplaySHA256: SHA256.hash(data: try encoder.encode(saved))
                                                .map { String(format: "%02x", $0) }.joined(),
                                            eventIndex: eventIndex, originalTick: original.tick,
                                            nativeTick: shiftedTick)
                                    }
                                }
                            }
                        }
                        let multiCount: Int
                        if ProcessInfo.processInfo.environment["FAN_TWO_EVENT_RETIME_SEARCH"] == "1" { multiCount = 2 }
                        else if ProcessInfo.processInfo.environment["FAN_THREE_EVENT_RETIME_SEARCH"] == "1" { multiCount = 3 }
                        else if ProcessInfo.processInfo.environment["FAN_FOUR_EVENT_RETIME_SEARCH"] == "1" { multiCount = 4 }
                        else { multiCount = 0 }
                        let defaultMaximum = multiCount == 2 ? 8 : multiCount == 3 ? 6 : 5
                        let maximumEvents = min(12, max(multiCount,
                            Int(ProcessInfo.processInfo.environment["FAN_MULTI_MAX_EVENTS"] ?? "") ?? defaultMaximum))
                        if witness == nil, multiCount >= 2,
                           (multiCount...maximumEvents).contains(saved.events.count),
                           solverReplays[hash]?.contains(saved) == true {
                            let radius = min(2, max(1,
                                Int(ProcessInfo.processInfo.environment["FAN_MULTI_OFFSET_RADIUS"] ?? "1") ?? 1))
                            let offsets = (1...radius).flatMap { [-$0, $0] }
                            var picked = Array(0..<multiCount)
                            var variants = 1
                            var places = Array(repeating: 1, count: multiCount)
                            for position in picked.indices.reversed() {
                                places[position] = variants
                                variants *= offsets.count
                            }
                            while witness == nil {
                                for variant in 0..<variants where witness == nil {
                                    var shifted = saved.events
                                    var valid = true
                                    for position in picked.indices {
                                        let eventIndex = picked[position]
                                        let offset = offsets[(variant / places[position]) % offsets.count]
                                        let tick = saved.events[eventIndex].tick + offset
                                        if tick < 0 { valid = false; break }
                                        shifted[eventIndex] = .init(tick: tick,
                                            action: shifted[eventIndex].action, afterTick: shifted[eventIndex].afterTick)
                                    }
                                    if !valid { continue }
                                    let shiftedReplay = ClassicDOSReplay(rank: id.packID,
                                        number: rows[index].entry.levelNumberSnapshot, title: level.title,
                                        initialStateHash: hash, events: shifted)
                                    attempts += 1
                                    if let outcome = try? ClassicDOSReplayPlayer.run(shiftedReplay,
                                        simulation: initial, verify: false), outcome.didWin {
                                        witness = ClassicDOSReplay(rank: shiftedReplay.rank,
                                            number: shiftedReplay.number, title: shiftedReplay.title,
                                            initialStateHash: hash, events: shifted, expected: outcome)
                                        let first = picked[0]
                                        retimedWitnesses[id.packID + "\0" + id.levelID] = RetimedFanWitness(
                                            candidateReplaySHA256: SHA256.hash(data: try encoder.encode(saved))
                                                .map { String(format: "%02x", $0) }.joined(),
                                            eventIndex: first, originalTick: saved.events[first].tick,
                                            nativeTick: shifted[first].tick)
                                    }
                                }
                                var cursor = multiCount - 1
                                while cursor >= 0 && picked[cursor] == saved.events.count - multiCount + cursor {
                                    cursor -= 1
                                }
                                if cursor < 0 { break }
                                picked[cursor] += 1
                                if cursor + 1 < multiCount {
                                    for position in (cursor + 1)..<multiCount {
                                        picked[position] = picked[position - 1] + 1
                                    }
                                }
                            }
                        }
                    }
                    if witness == nil, ProcessInfo.processInfo.environment["FAN_RELEASE_RATE_SWEEP"] == "1",
                       level.skills.values.allSatisfy({ $0 == 0 }) {
                        for rate in 1...99 where witness == nil {
                            let events = [ClassicDOSReplayEvent(tick: 0, action: .releaseRate(rate), afterTick: true)]
                            let candidate = ClassicDOSReplay(rank: id.packID,
                                number: rows[index].entry.levelNumberSnapshot, title: level.title,
                                initialStateHash: hash, events: events)
                            attempts += 1
                            if let outcome = try? ClassicDOSReplayPlayer.run(candidate,
                                simulation: initial, verify: false), outcome.didWin {
                                witness = ClassicDOSReplay(rank: candidate.rank, number: candidate.number,
                                    title: candidate.title, initialStateHash: hash,
                                    events: events, expected: outcome)
                            }
                        }
                    }
                    if witness == nil, ProcessInfo.processInfo.environment["FAN_RELEASE_RATE_CHANGE_SWEEP"] == "1",
                       level.skills.values.allSatisfy({ $0 == 0 }) {
                        let rates = [1, 25, 50, 75, 99]
                        let latest = min(3_060, max(17, level.timeLimitMinutes * 1_020))
                        for firstRate in rates where witness == nil {
                            for switchTick in stride(from: 17, through: latest, by: 17) where witness == nil {
                                for secondRate in rates where secondRate != firstRate && witness == nil {
                                    let events = [
                                        ClassicDOSReplayEvent(tick: 0, action: .releaseRate(firstRate), afterTick: true),
                                        ClassicDOSReplayEvent(tick: switchTick,
                                            action: .releaseRate(secondRate), afterTick: true)
                                    ]
                                    let candidate = ClassicDOSReplay(rank: id.packID,
                                        number: rows[index].entry.levelNumberSnapshot, title: level.title,
                                        initialStateHash: hash, events: events)
                                    attempts += 1
                                    if let outcome = try? ClassicDOSReplayPlayer.run(candidate,
                                        simulation: initial, verify: false), outcome.didWin {
                                        witness = ClassicDOSReplay(rank: candidate.rank, number: candidate.number,
                                            title: candidate.title, initialStateHash: hash,
                                            events: events, expected: outcome)
                                    }
                                }
                            }
                        }
                    }
                    let key = geometry(initial)
                    if witness == nil && distinct.insert(hash).inserted {
                        // A matching mask only proposes a route. Objects, resources and mechanics
                        // are always checked by replaying against this level's complete simulation.
                        let proposals = templates[key, default: []] + [[]]
                        for events in proposals where witness == nil {
                            attempts += 1
                            let candidate = ClassicDOSReplay(rank: id.packID, number: rows[index].entry.levelNumberSnapshot, title: level.title, initialStateHash: hash, events: events)
                            if let outcome = try? ClassicDOSReplayPlayer.run(candidate, simulation: initial), outcome.didWin {
                                witness = ClassicDOSReplay(rank: candidate.rank, number: candidate.number, title: candidate.title, initialStateHash: hash, events: events, expected: outcome)
                            }
                        }
                    }
                    if witness == nil, ProcessInfo.processInfo.environment["FAN_APPROXIMATE_SEARCH"] == "1" {
                        let sample = sketch(initial)
                        var distances: [(index: Int, distance: Int)] = []
                        for i in nearbyTemplates.indices {
                            var distance = 0
                            for j in sample.indices { distance += (sample[j] ^ nearbyTemplates[i].sketch[j]).nonzeroBitCount }
                            if distance < 1000 { distances.append((i, distance)) }
                        }
                        distances.sort { a, b in a.distance != b.distance ? a.distance < b.distance : a.index < b.index }
                        let nearby = distances.prefix(6)
                        for match in nearby where witness == nil {
                            attempts += 1
                            let events = nearbyTemplates[match.index].events
                            let candidate = ClassicDOSReplay(rank: id.packID, number: rows[index].entry.levelNumberSnapshot,
                                title: level.title, initialStateHash: hash, events: events)
                            if let outcome = try? ClassicDOSReplayPlayer.run(candidate, simulation: initial), outcome.didWin {
                                witness = ClassicDOSReplay(rank: candidate.rank, number: candidate.number, title: candidate.title,
                                    initialStateHash: hash, events: events, expected: outcome)
                            }
                        }
                    }
                    if witness == nil, ProcessInfo.processInfo.environment["FAN_REACTIVE_SEARCH"] == "1" {
                        // Small deterministic policies propose ordinary routes. They do not
                        // classify a level or count as a solution until the replay wins.
                        let exits = initial.configuration.triggers.filter { $0.effect == .exit }
                        for policy in 0..<8 where witness == nil {
                            var sim = initial
                            var events: [ClassicDOSReplayEvent] = []
                            let bridgeLead = policy % 2 == 0 ? 6 : 12
                            while !sim.isComplete && sim.tickCount < 8000 && events.count < 100 {
                                sim.tick()
                                if sim.savedCount >= sim.configuration.requiredToSave && !sim.isNuking {
                                    sim.beginNuke()
                                    events.append(.init(tick: sim.tickCount, action: .nuke, afterTick: true))
                                }
                                if sim.lostCount > sim.configuration.totalLemmings - sim.configuration.requiredToSave { break }
                                for lem in sim.lemmings where lem.isActive && !sim.isNuking {
                                    let x = lem.foot.x, y = lem.foot.y
                                    let dx = lem.direction == .right ? 1 : -1
                                    let wall = sim.terrain.isSolid(x: x + dx * 3, y: y - 4)
                                    let gap = !sim.terrain.isSolid(x: x + dx * bridgeLead, y: y + 1)
                                    let target = exits.min {
                                        abs(x - ($0.bounds.x1 + $0.bounds.x2)/2) + abs(y - $0.bounds.y1)
                                        < abs(x - ($1.bounds.x1 + $1.bounds.x2)/2) + abs(y - $1.bounds.y1)
                                    }
                                    var skills: [ClassicSkill] = []
                                    if lem.action == .falling && lem.fallDistance > 32 { skills = [.floater] }
                                    if lem.action == .shrugging && (gap || policy >= 4) { skills = [.builder] }
                                    if lem.action == .walking {
                                        if wall { skills = policy % 4 < 2 ? [.basher, .climber, .builder] : [.climber, .basher, .builder] }
                                        else if gap { skills = [.builder] }
                                        else if policy >= 4, let target, y + 16 < target.bounds.y1 {
                                            let tx = (target.bounds.x1 + target.bounds.x2)/2
                                            if abs(x - tx) < 12 { skills = [.digger] }
                                            else if (tx - x) * dx > 0 { skills = [.miner] }
                                        }
                                    }
                                    for skill in skills where sim.remainingSkillCount(skill) > 0 {
                                        if sim.assign(skill, to: lem.id) == .assigned {
                                            events.append(.init(tick: sim.tickCount, action: .assign(lemmingID: lem.id, skill: skill), afterTick: true))
                                            break
                                        }
                                    }
                                }
                            }
                            attempts += 1
                            if sim.didWin {
                                let candidate = ClassicDOSReplay(rank: id.packID, number: rows[index].entry.levelNumberSnapshot,
                                    title: level.title, initialStateHash: hash, events: events)
                                if let outcome = try? ClassicDOSReplayPlayer.run(candidate, simulation: initial), outcome.didWin {
                                    witness = ClassicDOSReplay(rank: candidate.rank, number: candidate.number, title: candidate.title,
                                        initialStateHash: hash, events: events, expected: outcome)
                                }
                            }
                        }
                    }
                    if let witness {
                        let profileKey = DifficultyCacheKey(identity: id, levelRevision: rows[index].entry.sourceRevision,
                            replayRevision: SHA256.hash(data: try encoder.encode(witness)).description, assetsRevision: hash + ":probes-10")
                        rows[index].profile = try ClassicDifficultyAnalysis.analyse(initial: initial, replay: witness, key: profileKey, maximumProbeRuns: 10)
                        solutions[hash] = witness; found[hash] = witness
                        solutions[profileKey.replayRevision] = witness
                        found[profileKey.replayRevision] = witness
                        foundHashes.insert(hash)
                        if !witness.events.isEmpty { templates[key, default: []].append(witness.events) }
                        print("WIN \(foundHashes.count): \(level.title) [\(Int(rows[index].profile.overallScore))]"); fflush(stdout)
                    }
                } catch { failures.append("\(id.packID)/\(id.levelID): \(error)") }
            }
            if packNumber % 10 == 0 { try save() }
            print("PACK \(packNumber+1)/\(packs.count), \(attempts) trials, \(foundHashes.count) new distinct witnesses"); fflush(stdout)
        }
        try save()
        if compareGolemsObjects {
            print("Compared \(golemsComparisons.count)/\(rows.filter { !$0.official }.count) selected fan replays under Golems object slots")
            guard failures.isEmpty, golemsComparisons.count == rows.filter({ !$0.official }).count else {
                throw LevelPlaylistError.invalidSequence
            }
            return
        }
        if verifyOnly {
            print("Verified \(verifiedCount)/\(rows.filter { !$0.official }.count) selected fan levels")
            guard failures.isEmpty, verifiedCount == rows.filter({ !$0.official }).count else { throw LevelPlaylistError.invalidSequence }
        }
    }
}
