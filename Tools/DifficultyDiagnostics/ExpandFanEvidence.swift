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
        let savedURL = output.appendingPathComponent("solutions.json")
        var found = (try? decoder.decode([String: ClassicDOSReplay].self, from: Data(contentsOf: savedURL))) ?? [:]
        solutions.merge(found) { a, _ in a }
        var templates: [String: [[ClassicDOSReplayEvent]]] = [:]
        func geometry(_ sim: ClassicDOSSimulation) -> String { SHA256.hash(data: sim.terrain.solidMask + sim.terrain.steelMask).description }
        let verifyOnly = ProcessInfo.processInfo.environment["FAN_VERIFY_ONLY"] == "1"
        var verifiedCount = 0
        let semanticsOnly = ProcessInfo.processInfo.environment["FAN_SEMANTICS_ONLY"] == "1"
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
            for item in set.campaign.levels {
                let art = set.title == .ohYesMoreLemmings ? PortExclusivePack.artworkDirectory(for: item, portsRoot: ports) : url
                let fallback = set.title == .ohYesMoreLemmings ? PortExclusivePack.fallbackArtworkDirectory(for: item, portsRoot: ports) : nil
                let ground = try ClassicGroundSet.load(style: item.level.groundStyle, from: art, fallbackDirectory: fallback)
                let special = item.level.specialStyle > 0 ? try ClassicSpecialGraphic.load(index: item.level.specialStyle - 1, from: art, fallbackDirectory: fallback) : nil
                let rendered = try ClassicLevelRenderer.render(item.level, groundSet: ground, specialGraphic: special)
                let sim = try ClassicDOSSimulation(level: item.level, renderedLevel: rendered, mainDATAssets: assets(fallback ?? art), mechanics: ClassicDOSMechanics(title: set.title, rank: item.rank))
                officialScenarios.insert(try scenario(item.level, sim))
                if let replay = solutions[ClassicDOSReplayRecorder.stateHash(of: sim)] { templates[geometry(sim), default: []].append(replay.events); nearbyTemplates.append((sketch(sim), replay.events)) }
            }
        }
        let rowIndex = Dictionary(uniqueKeysWithValues: rows.indices.map { (rows[$0].entry.identity, $0) })
        var attempts = 0, distinct = Set<String>(), failures: [String] = []
        let measuredPacks = Set(rows.filter { !$0.official && $0.profile.confidence != .low }.map { $0.entry.identity.packID })
        let packs = FanLevelLibrary.packs(in: [root.appendingPathComponent("LevelPacks"), FanLevelLibrary.downloadFolder]).filter { !(semanticsOnly || verifyOnly) || measuredPacks.contains("fan:" + FanLevelLibrary.catalogueID($0)) }
        func save() throws {
            try encoder.encode(rows).write(to: output.appendingPathComponent("audit.json"), options: .atomic)
            try encoder.encode(found).write(to: savedURL, options: .atomic)
            try encoder.encode(officialScenarios.sorted()).write(to: output.appendingPathComponent("official-scenarios.json"), options: .atomic)
            try encoder.encode(fanScenarios).write(to: output.appendingPathComponent("fan-scenarios.json"), options: .atomic)
            try encoder.encode(failures).write(to: output.appendingPathComponent("failures.json"), options: .atomic)
        }
        for (packNumber, pack) in packs.enumerated() {
            for item in try FanLevelLibrary.validatedEntries(in: pack) {
                let id = LevelCatalogueIdentity(engine: .classic, packID: "fan:" + FanLevelLibrary.catalogueID(pack), levelID: item.file + "#\(item.section ?? -1)")
                guard let index = rowIndex[id], ((semanticsOnly || verifyOnly) ? rows[index].profile.confidence != .low : rows[index].profile.confidence == .low) else { continue }
                do {
                    let (level, style) = try FanLevelLibrary.level(item, in: pack)
                    let ground = try FanLevelLibrary.groundSet(for: level, styleName: style, portsRoot: ports, pack: pack, entry: item)
                    let special = try FanLevelLibrary.specialGraphic(for: level, entry: item, pack: pack, portsRoot: ports)
                    let rendered = try ClassicLevelRenderer.render(level, groundSet: ground, specialGraphic: special)
                    let initial = try ClassicDOSSimulation(level: level, renderedLevel: rendered, mainDATAssets: assets(ports.appendingPathComponent("lemmings_dos_1991-07-30")))
                    let hash = ClassicDOSReplayRecorder.stateHash(of: initial)
                    guard hash == rows[index].initialHash else { throw LevelPlaylistError.invalidEntry }
                    if verifyOnly {
                        guard FanLevelLibrary.archiveFingerprint(pack) == rows[index].entry.sourceRevision,
                              let replay = solutions[hash], let expected = replay.expected, expected.didWin else { throw LevelPlaylistError.invalidEntry }
                        let digest = SHA256.hash(data: try encoder.encode(replay)).description
                        guard rows[index].profile.key.replayRevision == digest || rows[index].profile.key.replayRevision == String(digest.dropFirst("SHA256 digest: ".count)) else {
                            throw NSError(domain: "Evidence", code: 1, userInfo: [NSLocalizedDescriptionKey: "Profile and bundled witness differ: " + level.title])
                        }
                        let result = try ClassicDOSReplayPlayer.run(replay, simulation: initial)
                        guard result.didWin else { throw DifficultyAnalysisError.replayDidNotWin }
                        verifiedCount += 1
                        continue
                    }
                    let scenarioHash = try scenario(level, initial)
                    fanScenarios[id.packID + "\0" + id.levelID] = scenarioHash
                    if semanticsOnly || officialScenarios.contains(scenarioHash) { continue }
                    var witness = solutions[hash]
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
                        if !witness.events.isEmpty { templates[key, default: []].append(witness.events) }
                        print("WIN \(found.count): \(level.title) [\(Int(rows[index].profile.overallScore))]"); fflush(stdout)
                    }
                } catch { failures.append("\(id.packID)/\(id.levelID): \(error)") }
            }
            if packNumber % 10 == 0 { try save() }
            print("PACK \(packNumber+1)/\(packs.count), \(attempts) trials, \(found.count) new distinct witnesses"); fflush(stdout)
        }
        try save()
        if verifyOnly {
            print("Verified \(verifiedCount)/\(rows.filter { !$0.official }.count) selected fan levels")
            guard failures.isEmpty, verifiedCount == rows.filter({ !$0.official }).count else { throw LevelPlaylistError.invalidSequence }
        }
    }
}
