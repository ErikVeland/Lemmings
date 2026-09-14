import Foundation
import CryptoKit
import NxlvKit

// This tool observes the real engines. Search failure never establishes an upper bound.
let project = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = ProcessInfo.processInfo.environment["TROLLEY_RESOURCES"].map { URL(fileURLWithPath: $0) }
    ?? project.appendingPathComponent(".build/local/Ultimate Lemmings.app/Contents/Resources")
let ports = resources.appendingPathComponent("Ports")
let output = ProcessInfo.processInfo.environment["TROLLEY_OUTPUT"].map { URL(fileURLWithPath: $0) }
    ?? project.appendingPathComponent(".build/trolley-verification/results")
let family = CommandLine.arguments.dropFirst().first ?? "all"
guard ["all", "classic", "ports", "l2", "l2-proofs", "l3", "fingerprint"].contains(family) else {
    throw SequelDataError.invalid("Choose all, classic, ports, l2, l2-proofs, l3, or fingerprint.")
}
let search = CommandLine.arguments.contains("--search")
let refreshOutcomes = CommandLine.arguments.contains("--refresh-outcomes")
let shard = CommandLine.arguments.first { $0.hasPrefix("--shard=") }?.dropFirst(8).split(separator: "/").compactMap { Int($0) }
if let shard, shard.count != 2 || shard[1] < 1 || shard[0] < 0 || shard[0] >= shard[1] {
    throw SequelDataError.invalid("Use --shard=index/count with a zero-based index.")
}
let outputName = shard.map { "\(family)-\($0[0])" } ?? family
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
encoder.dateEncodingStrategy = .iso8601
try FileManager.default.createDirectory(at: output.appendingPathComponent("witnesses"), withIntermediateDirectories: true)

func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
func compact<T: Encodable>(_ value: T) throws -> Data {
    let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]
    return try e.encode(value)
}
func fileHash(_ url: URL) throws -> String { try hash(Data(contentsOf: url)) }
func assetHash(_ root: URL) throws -> String {
    // Match live sequel identity even when the build folder is a symlink.
    let root = root.resolvingSymlinksInPath().standardizedFileURL
    let excluded = Set(["sav", "mp4", "m4a", "wav", "ogg", "mp3", "mod", "mid", "png", "jpg"])
    guard let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
        throw SequelDataError.invalid("Cannot enumerate \(root.path)")
    }
    var hashes: [String: String] = [:]
    for case let file as URL in files where !excluded.contains(file.pathExtension.lowercased()) {
        if try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            hashes[String(file.path.dropFirst(root.path.count))] = try fileHash(file)
        }
    }
    return try hash(compact(hashes))
}
let sourceFiles = try FileManager.default.contentsOfDirectory(at: project.appendingPathComponent("Sources/NxlvKit"), includingPropertiesForKeys: nil)
var sourceHashes: [String: String] = [:]
// The packager and verifier use one source-selection policy.
let presentationFiles = Set(try JSONDecoder().decode([String].self, from:
    Data(contentsOf: project.appendingPathComponent("Tools/TrolleyVerification/presentation-files.json"))))
for file in sourceFiles where file.pathExtension == "swift" && !file.lastPathComponent.hasPrefix("Trolley") && !file.lastPathComponent.hasPrefix("Arcade") && !presentationFiles.contains(file.lastPathComponent) {
    sourceHashes[file.lastPathComponent] = try fileHash(file)
}
let engineHash = try hash(compact(sourceHashes))
if family == "fingerprint" {
    print(engineHash)
    exit(0)
}

struct Witness: Codable {
    let path: String
    let sha256: String
    let saved: Int
    let released: Int
    let lost: Int
    let retainedReserves: Int
    let ticks: Int
    let completed: Bool
    let didWin: Bool
}
struct Row: Codable {
    let gameID: String
    let rank: String
    let number: Int
    let title: String
    let population: Int
    let required: Int
    var conditions: TrolleyConditions?
    var status = "UNKNOWN"
    var maximumSaveable: Int?
    var minimumSacrifices: Int?
    var bestSaved: Int?
    var lossesInBestSolution: Int?
    var witness: Witness?
    var testedCandidates = 0
    var notes: [String] = []
    mutating func accept(_ candidate: Witness, upperBound: Int? = nil) {
        guard candidate.completed, candidate.didWin else { return }
        if bestSaved == nil || candidate.saved > bestSaved! || (candidate.saved == bestSaved && candidate.lost < (lossesInBestSolution ?? Int.max)) {
            bestSaved = candidate.saved; lossesInBestSolution = candidate.lost; witness = candidate; status = "OBSERVED"
        }
        // A complete population rescue is both a witness and a tight upper bound.
        if candidate.saved == (upperBound ?? population), candidate.lost == 0 {
            maximumSaveable = candidate.saved; minimumSacrifices = 0; status = "VERIFIED"
        }
    }
}
struct Audit: Encodable {
    let schemaVersion = 1
    let generatedAt: Date
    let engineSourceFingerprint: String
    let family: String
    let exhaustive = false
    let levels: [Row]
}
var rows: [Row] = []
@MainActor func persist() throws {
    try encoder.encode(Audit(generatedAt: Date(), engineSourceFingerprint: engineHash, family: family, levels: rows))
        .write(to: output.appendingPathComponent("\(outputName).json"), options: .atomic)
}
@MainActor func record(_ row: Row) throws {
    rows.append(row); try persist()
    print("\(row.gameID) \(row.rank) \(row.number): \(row.status), best \(row.bestSaved.map(String.init) ?? "?")/\(row.population)")
    fflush(stdout)
}
func save<T: Encodable>(_ value: T, name: String, saved: Int, released: Int, lost: Int, reserves: Int = 0,
                        ticks: Int, completed: Bool, won: Bool) throws -> Witness {
    let relative = "witnesses/\(name).json", bytes = try encoder.encode(value)
    try bytes.write(to: output.appendingPathComponent(relative), options: .atomic)
    return Witness(path: relative, sha256: hash(bytes), saved: saved, released: released, lost: lost,
                   retainedReserves: reserves, ticks: ticks, completed: completed, didWin: won)
}

func classicFingerprint(_ game: ClassicDOSSimulation) throws -> String {
    var bytes = Data(ClassicDOSReplayRecorder.stateHash(of: game).utf8)
    bytes.append(try compact(game.configuration.entrances))
    bytes.append(try compact(game.configuration.triggers))
    bytes.append(try compact(game.comparisonDestructionMasks))
    return hash(bytes)
}
@MainActor func auditClassic(_ set: ClassicDataSet, directory: URL) throws {
    let titleID = set.title?.rawValue ?? set.identifierKey
    struct Catalogue: Decodable { let levels: [Row] }
    let proofRoot = project.appendingPathComponent("Resources/Trolley")
    let published = try JSONDecoder().decode(Catalogue.self,
        from: Data(contentsOf: proofRoot.appendingPathComponent("verified-maxima.json"))).levels
    var assetsByDirectory: [URL: ClassicMainDATAssets] = [:]
    var grounds: [String: ClassicGroundSet] = [:], specials: [String: ClassicSpecialGraphic] = [:]
    for (index, entry) in set.campaign.levels.enumerated() {
        if let shard, index % shard[1] != shard[0] { continue }
        let level = entry.level
        var row = Row(gameID: titleID, rank: entry.rank, number: entry.number, title: level.title,
                      population: level.lemmingCount, required: level.saveRequirement)
        do {
            let artDirectory = set.title == .ohYesMoreLemmings
                ? PortExclusivePack.artworkDirectory(for: entry, portsRoot: directory) : directory
            let fallback = set.title == .ohYesMoreLemmings
                ? PortExclusivePack.fallbackArtworkDirectory(for: entry, portsRoot: directory) : nil
            if assetsByDirectory[artDirectory] == nil { assetsByDirectory[artDirectory] = try ClassicMainDATAssets.load(from: fallback ?? artDirectory) }
            let assets = assetsByDirectory[artDirectory]!
            let groundKey = artDirectory.path + "/\(level.groundStyle)"
            if grounds[groundKey] == nil { grounds[groundKey] = try ClassicGroundSet.load(style: level.groundStyle, from: artDirectory, fallbackDirectory: fallback) }
            let specialKey = artDirectory.path + "/\(level.specialStyle)"
            if level.specialStyle != 0, specials[specialKey] == nil {
                specials[specialKey] = try ClassicSpecialGraphic.load(index: level.specialStyle - 1, from: artDirectory, fallbackDirectory: fallback)
            }
            let rendered = try ClassicLevelRenderer.render(level, groundSet: grounds[groundKey]!, specialGraphic: specials[specialKey])
            let base = try ClassicDOSSimulation(level: level, renderedLevel: rendered, mainDATAssets: assets)
            row.conditions = TrolleyConditions(gameID: titleID, packID: set.identifierKey, levelID: "level-\(index)",
                levelFingerprint: try classicFingerprint(base), rulesetVersion: "classic-dos-v1", physicsMode: "classic-dos-v1",
                population: base.configuration.totalLemmings, rescueRequirement: base.configuration.requiredToSave,
                startingSkills: Dictionary(uniqueKeysWithValues: ClassicSkill.allCases.map { ($0.rawValue, base.remainingSkillCount($0)) }),
                timeLimitSeconds: base.remainingTimeSeconds.map(Double.init))
            let initialHash = ClassicDOSReplayRecorder.stateHash(of: base)
            func attempt(_ events: [ClassicDOSReplayEvent], fullOnly: Bool = false) throws {
                row.testedCandidates += 1
                var trial = base
                for event in events where event.afterTick != true {
                    if case let .assign(id, skill) = event.action {
                        guard trial.schedule(.init(tick: event.tick, lemmingID: id, skill: skill)) else { return }
                    }
                }
                func applyLive(_ tick: Int) -> Bool {
                    for event in events where event.afterTick == true && event.tick == tick {
                        switch event.action {
                        case let .assign(id, skill):
                            guard trial.assign(skill, to: id) == .assigned else { return false }
                        case let .releaseRate(value): trial.setReleaseRate(value)
                        case .nuke: trial.beginNuke()
                        }
                    }
                    return true
                }
                guard applyLive(0) else { return }
                while !trial.isComplete && trial.tickCount < ClassicDOSReplayPlayer.defaultTickLimit {
                    for event in events where event.afterTick != true && event.tick == trial.tickCount + 1 {
                        switch event.action {
                        case let .releaseRate(value): trial.setReleaseRate(value)
                        case .nuke: trial.beginNuke()
                        case .assign: break
                        }
                    }
                    var eventsApplied = trial.tick()
                    for event in events where event.afterTick != true && event.tick == trial.tickCount {
                        if case let .assign(id, skill) = event.action {
                            guard let applied = eventsApplied.firstIndex(of: .skillAssigned(lemmingID: id, skill: skill)) else { return }
                            eventsApplied.remove(at: applied)
                        }
                    }
                    guard applyLive(trial.tickCount) else { return }
                    if fullOnly && trial.lostCount > 0 { return }
                }
                guard events.allSatisfy({ $0.tick >= ($0.afterTick == true ? 0 : 1) && $0.tick <= trial.tickCount }), trial.isComplete, trial.didWin,
                      trial.savedCount > (row.bestSaved ?? -1) || trial.savedCount == row.population else { return }
                let candidate = ClassicDOSReplay(rank: entry.rank, number: entry.number, title: level.title,
                    initialStateHash: initialHash, events: events)
                let outcome = try ClassicDOSReplayPlayer.run(candidate, simulation: base)
                guard outcome.saved == trial.savedCount, outcome.stateHash == ClassicDOSReplayRecorder.stateHash(of: trial) else { throw SequelDataError.invalid("Replay is not deterministic") }
                let replay = ClassicDOSReplay(rank: entry.rank, number: entry.number, title: level.title,
                    initialStateHash: initialHash, events: events, expected: outcome)
                _ = try ClassicDOSReplayPlayer.run(replay, simulation: base)
                row.accept(try save(replay, name: "\(titleID)-\(index)", saved: outcome.saved,
                    released: outcome.released, lost: trial.lostCount, ticks: outcome.ticks, completed: true, won: outcome.didWin))
            }
            let existing = output.appendingPathComponent("witnesses/\(titleID)-\(index).json")
            // Keep a previous witness before a baseline observation can replace its file.
            let cached = try? Data(contentsOf: existing)
            try attempt([])
            var publishedRescueTarget: Int?
            if let proof = published.first(where: { $0.conditions == row.conditions }), let witness = proof.witness {
                publishedRescueTarget = witness.saved
                let url = proofRoot.appendingPathComponent(witness.path)
                guard try fileHash(url) == witness.sha256 else {
                    throw SequelDataError.invalid("Published Classic witness hash changed.")
                }
                let replay = try JSONDecoder().decode(ClassicDOSReplay.self, from: Data(contentsOf: url))
                if !refreshOutcomes { _ = try ClassicDOSReplayPlayer.run(replay, simulation: base) }
                try attempt(replay.events)
            }
            if row.status != "VERIFIED", let bytes = cached,
               let replay = try? JSONDecoder().decode(ClassicDOSReplay.self, from: bytes),
               (try? ClassicDOSReplayPlayer.run(replay, simulation: base)) != nil {
                try attempt(replay.events)
            }
            if titleID == "lemmings", row.status != "VERIFIED" {
                let name = String(format: "%@-%02d.json", entry.rank.lowercased(), entry.number)
                let fixture = project.appendingPathComponent("Tests/ClassicDOSCompletionTests/Fixtures/\(name)")
                let replay = try JSONDecoder().decode(ClassicDOSReplay.self, from: Data(contentsOf: fixture))
                _ = try ClassicDOSReplayPlayer.run(replay, simulation: base)
                try attempt(replay.events)
            }
            if titleID != "lemmings", row.status != "VERIFIED" {
                let name = String(format: "%@-%02d.json", entry.rank.lowercased(), entry.number)
                let fixture = project.appendingPathComponent("Tests/ClassicFamilyCompletionTests/Fixtures/\(titleID)/\(name)")
                if FileManager.default.fileExists(atPath: fixture.path) {
                    let replay = try JSONDecoder().decode(ClassicDOSReplay.self, from: Data(contentsOf: fixture))
                    _ = try ClassicDOSReplayPlayer.run(replay, simulation: base)
                    try attempt(replay.events)
                }
            }
            if let target = publishedRescueTarget, (row.bestSaved ?? 0) < target {
                throw SequelDataError.invalid("Published Classic rescue target regressed.")
            }
            if search && row.status != "VERIFIED" {
                // Complete zero-loss witnesses prove optimality. This bounded search does not prove failure.
                for tick in stride(from: 36, through: 600, by: 8) where row.status != "VERIFIED" {
                    for skill in ClassicSkill.allCases where base.remainingSkillCount(skill) > 0 && row.status != "VERIFIED" {
                        try attempt([.init(tick: tick, action: .assign(lemmingID: 0, skill: skill))], fullOnly: true)
                    }
                }
                if row.status != "VERIFIED" { row.notes.append("No full rescue found with one skill on the first Lemming in the sampled ticks. This is not an impossibility proof.") }
            }
        } catch { row.notes.append(String(describing: error)) }
        try record(row)
    }
}

typealias L2Replay = Lemmings2ReplayWitness
@MainActor func auditL2() throws {
    let root = ports.appendingPathComponent("Lemm2"), fingerprint = try assetHash(root)
    let campaign = try Lemmings2Campaign(root: root), masks = try Lemmings2TerrainMasks(root: root)
    struct Catalogue: Decodable { let levels: [Row] }
    let proofRoot = project.appendingPathComponent("Resources/Trolley")
    let bundled = family == "l2-proofs" ? try JSONDecoder().decode(Catalogue.self,
        from: Data(contentsOf: proofRoot.appendingPathComponent("verified-maxima.json"))).levels.filter { $0.gameID == "lemmings2" } : []
    for (index, level) in campaign.levels.enumerated() {
        if let shard, index % shard[1] != shard[0] { continue }
        let proof = bundled.first { $0.conditions?.levelID == "\(index / 10):\(index % 10)" }
        if family == "l2-proofs" && proof == nil { continue }
        let tribe = Lemmings2Campaign.tribeNames[level.style]
        let style = try Lemmings2Style(data: Data(contentsOf: root.appendingPathComponent("STYLES/\(Lemmings2Campaign.styleNames[level.style]).DAT")))
        let prefix = level.style == 2 ? "cavelem" : tribe.lowercased()
        let fixtureURL = proof?.witness.map { proofRoot.appendingPathComponent($0.path) }
            ?? project.appendingPathComponent(String(format: "Tests/Lemmings2CompletionTests/Fixtures/\(prefix)-%02d.json", index % 10 + 1))
        let fixture = FileManager.default.fileExists(atPath: fixtureURL.path) ? try JSONDecoder().decode(L2Replay.self, from: Data(contentsOf: fixtureURL)) : nil
        if let proof {
            guard let witness = proof.witness, let fixture,
                  try fileHash(fixtureURL) == witness.sha256,
                  fixture.population == proof.population,
                  fixture.expectedSaved == witness.saved, fixture.expectedTicks == witness.ticks else {
                throw SequelDataError.invalid("Bundled Tribes witness identity or outcome is inconsistent.")
            }
        }
        let populations = proof.map { [$0.population] }
            ?? fixture.map { $0.population != 60 ? [60, $0.population] : [60] } ?? [60]
        for population in populations {
            var row = Row(gameID: "lemmings2", rank: tribe, number: index % 10 + 1, title: level.title, population: population, required: 1)
            do {
                let base = try Lemmings2Runtime(level: level, style: style, masks: masks, total: population)
                let c = base.configuration
                row.conditions = TrolleyConditions(gameID: "lemmings2", packID: "tribes", levelID: "\(index / 10):\(index % 10)",
                    levelFingerprint: level.fingerprint + ":" + fingerprint, rulesetVersion: "l2-native-v1", physicsMode: "l2-native-v1",
                    population: population, rescueRequirement: 1,
                    startingSkills: Dictionary(zip(c.skills, c.supplies).map { ($0.0.name.lowercased().replacingOccurrences(of: " ", with: "_"), $0.1) }, uniquingKeysWith: +),
                    timeLimitSeconds: Double(c.timeLimit), modifiers: ["practice": String(c.isPractice), "releaseInterval": String(c.releaseInterval),
                        "firstReleaseTick": String(c.firstReleaseTick), "goldRequirement": String(max(1, population - level.allowedLossesForGold))])
                func play(_ replay: L2Replay?) throws -> Lemmings2Runtime {
                    var trial = base
                    if let replay {
                        guard replay.levelSHA256 == level.fingerprint,
                              (replay.version == 1 && replay.events == nil)
                                || (replay.version == 2 && replay.events != nil && replay.inputs.isEmpty && replay.pointers == nil) else {
                            throw SequelDataError.invalid("Replay level identity or input version mismatch")
                        }
                    }
                    if let replay, replay.version == 1 {
                        guard replay.inputsAreOrdered, (replay.pointers ?? []).allSatisfy({ pointer in
                            (level.minimumScreenX...level.maximumScreenX + 319).contains(pointer.x)
                                && (level.minimumScreenY...level.maximumScreenY + 159).contains(pointer.y)
                                && (!pointer.fan || (pointer.x == pointer.fanX && pointer.y == pointer.fanY))
                        }) else { throw SequelDataError.invalid("Legacy replay inputs or pointers are invalid") }
                    }
                    let events = replay?.timedEvents() ?? []
                    guard zip(events, events.dropFirst()).allSatisfy({ $0.tick <= $1.tick }),
                          events.allSatisfy({ $0.tick >= 0 }) else {
                        throw SequelDataError.invalid("Replay events are not ordered")
                    }
                    for timed in events {
                        let point: (Int, Int)?
                        switch timed.event {
                        case let .aim(x, y, _), let .machine(x, y), let .chain(x, y): point = (x, y)
                        case let .fan(x, y, active): point = active ? (x, y) : nil
                        case .assign, .releasePointer, .nuke: point = nil
                        }
                        if let point {
                            guard (level.minimumScreenX...level.maximumScreenX + 319).contains(point.0),
                                  (level.minimumScreenY...level.maximumScreenY + 159).contains(point.1) else {
                                throw SequelDataError.invalid("Replay pointer is outside the playable viewport")
                            }
                        }
                    }
                    var cursor = Lemmings2EventCursor()
                    while !trial.isComplete && trial.tick < max(15000, c.timeLimit * 18) {
                        try cursor.apply(eventsAt: &trial, events: events)
                        trial.step()
                    }
                    guard cursor.next == events.count else { throw SequelDataError.invalid("Replay ended before all inputs were used") }
                    return trial
                }
                for candidate in (family == "l2-proofs" ? [fixture] : [nil, fixture]) as [L2Replay?] {
                    if candidate == nil && row.testedCandidates > 0 { continue }
                    row.testedCandidates += 1
                    do {
                        let trial = try play(candidate)
                        if let candidate, candidate.population == population,
                           trial.saved != candidate.expectedSaved || trial.tick != candidate.expectedTicks {
                            row.notes.append("Existing completion fixture changed: expected \(candidate.expectedSaved) at \(candidate.expectedTicks), got \(trial.saved) at \(trial.tick).")
                            continue
                        }
                        guard trial.isComplete, trial.didWin, trial.saved > (row.bestSaved ?? -1) else { continue }
                        let verified = try play(candidate)
                        guard verified.saved == trial.saved, verified.lost == trial.lost, verified.tick == trial.tick else { throw SequelDataError.invalid("Replay is not deterministic") }
                        let replay: L2Replay
                        if let events = candidate?.events {
                            replay = L2Replay(levelSHA256: level.fingerprint, population: population,
                                expectedSaved: trial.saved, expectedTicks: trial.tick, events: events)
                        } else {
                            replay = L2Replay(levelSHA256: level.fingerprint, population: population,
                                expectedSaved: trial.saved, expectedTicks: trial.tick, inputs: candidate?.inputs ?? [], pointers: candidate?.pointers ?? [])
                        }
                        row.accept(try save(replay, name: "lemmings2-\(index)-\(population)", saved: trial.saved, released: trial.released,
                            lost: trial.lost, ticks: trial.tick, completed: true, won: trial.didWin))
                    } catch { row.notes.append(String(describing: error)) }
                }
                if fixture == nil { row.notes.append("No recorded solution fixture is available.") }
                if row.status != "VERIFIED" { row.notes.append("The medal loss allowance is not an optimality proof.") }
            } catch { row.notes.append(String(describing: error)) }
            try record(row)
        }
    }
    if family == "l2-proofs" {
        guard !bundled.isEmpty, rows.count == bundled.count, rows.allSatisfy({ $0.status == "VERIFIED" }) else {
            throw SequelDataError.invalid("A bundled Tribes witness no longer proves its rescue target.")
        }
    }
}

@MainActor func auditL3() throws {
    let root = ports.appendingPathComponent("LEM3CD")
    for tribe in Lemmings3ClassicCampaign.Tribe.allCases {
        let campaign = try Lemmings3ClassicCampaign(root: root, tribe: tribe)
        let style = try Lemmings3Style(directory: root.appendingPathComponent("STYLES"), number: tribe.rawValue)
        for (index, level) in campaign.levels.enumerated() {
            var row = Row(gameID: "lemmings3", rank: tribe.title, number: index + 1, title: "\(tribe.title) \(index + 1)", population: 20 + level.extraLemmings, required: 1)
            do {
                let perm = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/PERM%03d.OBS", level.permanentObjectsReference))))
                let temp = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/TEMP%03d.OBS", level.temporaryObjectsReference))))
                let base = try Lemmings3Runtime(level: level, style: style, permanent: perm, temporary: temp, total: 20)
                var trial = base
                row.testedCandidates = 1
                let number = tribe.firstLevel + index
                let fixture = project.appendingPathComponent(String(format: "Tests/Lemmings3CompletionTests/Fixtures/%03d.json", number))
                let witness: Witness
                if FileManager.default.fileExists(atPath: fixture.path) {
                    let replay = try JSONDecoder().decode(L3Replay.self, from: Data(contentsOf: fixture))
                    guard replay.level == number else { throw SequelDataError.invalid("L3 replay names another level.") }
                    trial = try replay.replay(from: base, levelData: level.rawData)
                    _ = try replay.replay(from: base, levelData: level.rawData)
                    witness = try save(replay, name: "lemmings3-\(number)",
                        saved: trial.saved, released: trial.released + level.extraLemmings, lost: trial.lost, reserves: trial.reserve,
                        ticks: trial.tick, completed: trial.isComplete, won: trial.saved > 0)
                } else {
                    while !trial.isComplete && trial.tick < 30000 { trial.step() }
                    witness = try save(["level": number, "population": 20, "inputs": 0], name: "lemmings3-\(number)",
                        saved: trial.saved, released: trial.released + level.extraLemmings, lost: trial.lost, reserves: trial.reserve,
                        ticks: trial.tick, completed: trial.isComplete, won: trial.saved > 0)
                }
                row.accept(witness)
                row.notes.append("Chronicles retains unreleased reserves. Population minus saved must not be labelled necessary sacrifices. Fixed-input fixtures are replayed twice. Uncovered levels receive a no-input check.")
            } catch { row.notes.append(String(describing: error)) }
            try record(row)
        }
    }
}

if family == "all" || family == "classic" {
    let directories = try FileManager.default.contentsOfDirectory(at: ports, includingPropertiesForKeys: nil).sorted { $0.path < $1.path }
    var seen = Set<String>()
    for directory in directories {
        guard let set = try? ClassicDataSet.detect(directory: directory), set.title != nil, !seen.contains(set.identifierKey) else { continue }
        seen.insert(set.identifierKey)
        try auditClassic(set, directory: directory)
    }
}
if family == "all" || family == "ports" {
    if let set = try PortExclusivePack.dataSet(amigaRoot: ports.appendingPathComponent("amiga_extracted"), portsRoot: ports) {
        try auditClassic(set, directory: ports)
    }
}
if family == "all" || family == "l2" || family == "l2-proofs" { try auditL2() }
if family == "all" || family == "l3" { try auditL3() }
print("AUDIT", rows.count, "configurations; verified", rows.filter { $0.status == "VERIFIED" }.count,
      "observed", rows.filter { $0.status == "OBSERVED" }.count, "unknown", rows.filter { $0.status == "UNKNOWN" }.count)
