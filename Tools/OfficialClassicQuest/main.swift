import CryptoKit
import Foundation
import NxlvKit

// Run the official campaign through the app's session and recovery code.
// The separate completion verifier also checks every recorded input twice.
struct Failure: Error, CustomStringConvertible { let description: String }
func check(_ value: Bool, _ message: String) throws {
    if !value { throw Failure(description: message) }
}
func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
let officialReleases: [(ClassicTitle, String)] = [
    (.lemmings, "lemmings_dos_1991-07-30"),
    (.xmasLemmings1991, "xmas_dos_XmasLemmingsV1.9"),
    (.ohNoMoreLemmings, "oh_no_more_lemmings_dos-1991-11-14_2232"),
    (.xmasLemmings1992, "xmas_dos_XmasLemmingsV1.9a1"),
    (.holidayLemmings1993, "holiday_native_1993"),
    (.holidayLemmings1994, "holiday_native_1994"),
]
struct Evidence: Codable {
    let title: String
    let rank: String
    let number: Int
    let fixtureSHA256: String
    let initialStateHash: String
    let outcome: ClassicDOSReplayOutcome
    let recoveryTicks: [Int]
}
struct Report: Codable {
    let scope: String
    let levels: Int
    let recoveries: Int
    let progressResumes: Int
    let chapterTransitions: Int
    let finalDestination: String
    let evidence: [Evidence]
}

do {
    let args = CommandLine.arguments
    try check(args.count == 3 || (args.count == 4 && args[3] == "--include-conversions"),
              "Usage: OfficialClassicQuest PORTS REPORT.json [--include-conversions]")
    let includeConversions = args.count == 4
    let releases = (officialReleases + (includeConversions ? [(.ohYesMoreLemmings, "")] : []))
        .sorted { $0.0.canonOrder < $1.0.canonOrder }
    let expectedLevels = includeConversions ? 352 : 292
    let ports = URL(fileURLWithPath: args[1])
    let fixtureRoot = URL(fileURLWithPath: ProcessInfo.processInfo.environment["CLASSIC_QUEST_FIXTURES_ROOT"] ?? "Tests")
    let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("OfficialQuest-\(UUID())")
    try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: scratch) }
    var evidence: [Evidence] = []
    var passed: [ClassicTitle: Int] = [:]
    var resumes = 0
    var transitions = 0
    func library() -> UnifiedGameLibrary {
        UnifiedGameLibrary(entries: releases.map { title, _ in
            .init(title: title, total: title.expectedLevelCount!, passed: passed[title, default: 0])
        })
    }
    try check(library().questStart == releases[0].0, "Quest starts at the wrong release")
    for (chapterIndex, release) in releases.enumerated() {
        let (title, folder) = release
        let root = ports.appendingPathComponent(folder)
        let set: ClassicDataSet
        if title == .ohYesMoreLemmings {
            guard let converted = try PortExclusivePack.dataSet(
                amigaRoot: ports.appendingPathComponent("amiga_extracted"), portsRoot: ports) else {
                throw Failure(description: "Missing conversion campaign")
            }
            set = converted
        } else { set = try ClassicDataSet.detect(directory: root) }
        let campaign = set.campaign
        try check(set.title == title && campaign.levels.count == title.expectedLevelCount,
                  "Wrong or incomplete release: \(title.rawValue)")
        var assetCache: [URL: ClassicMainDATAssets] = [:]
        var groundCache: [String: ClassicGroundSet] = [:]
        var flow = ClassicGameFlow(campaign: campaign)
        flow.startGame()
        flow.resumeCampaign()
        for index in campaign.levels.indices {
            let entry = campaign.levels[index]
            let artwork = title == .ohYesMoreLemmings
                ? PortExclusivePack.artworkDirectory(for: entry, portsRoot: ports) : root
            let fallback = title == .ohYesMoreLemmings
                ? PortExclusivePack.fallbackArtworkDirectory(for: entry, portsRoot: ports) : nil
            let assetRoot = fallback ?? artwork
            if assetCache[assetRoot] == nil {
                assetCache[assetRoot] = try ClassicMainDATAssets.load(from: assetRoot)
            }
            let groundKey = "\(artwork.path)|\(fallback?.path ?? "")|\(entry.level.groundStyle)"
            if groundCache[groundKey] == nil {
                groundCache[groundKey] = try ClassicGroundSet.load(style: entry.level.groundStyle,
                    from: artwork, fallbackDirectory: fallback)
            }
            let label = "\(title.rawValue) \(entry.rank) \(entry.number)"
            try check(flow.screen == .briefing(level: index), "Progression skipped \(label)")
            flow.beginPlaying()
            let fixtureFolder = title == .lemmings ? "ClassicDOSCompletionTests/Fixtures"
                : "ClassicFamilyCompletionTests/Fixtures/\(title.rawValue)"
            let file = fixtureRoot.appendingPathComponent(fixtureFolder)
                .appendingPathComponent(String(format: "%@-%02d.json", entry.rank.lowercased(), entry.number))
            let data = try Data(contentsOf: file)
            let replay = try JSONDecoder().decode(ClassicDOSReplay.self, from: data)
            try check(replay.rank == entry.rank && replay.number == entry.number
                && replay.title == entry.level.title.trimmingCharacters(in: .whitespaces), "Wrong witness: \(label)")
            guard let expected = replay.expected else { throw Failure(description: "Missing outcome: \(label)") }
            let special = entry.level.specialStyle == 0 ? nil
                : try ClassicSpecialGraphic.load(index: entry.level.specialStyle - 1, from: artwork)
            let rendered = try ClassicLevelRenderer.render(entry.level, groundSet: groundCache[groundKey]!, specialGraphic: special)
            let base = try ClassicDOSSimulation(level: entry.level, renderedLevel: rendered,
                mainDATAssets: assetCache[assetRoot]!, mechanics: ClassicDOSMechanics(title: title, rank: entry.rank))
            try check(replay.initialStateHash == ClassicDOSReplayRecorder.stateHash(of: base), "Stale witness: \(label)")
            func freshSession() -> ClassicSession {
                ClassicSession(simulation: base, width: rendered.width, height: rendered.height)
            }
            var session = freshSession()
            // Legacy assignments run at the end of their tick. Legacy rate and
            // nuke inputs run before it; convert them to the live input clock.
            var live: [(Int, Int, ClassicDOSReplayAction)] = []
            for (offset, event) in replay.events.enumerated() {
                let tick: Int
                if event.afterTick == true { tick = event.tick }
                else if case .assign = event.action { tick = event.tick }
                else { tick = event.tick - 1 }
                live.append((tick, offset, event.action))
            }
            live.sort { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 }
            var input = 0
            let recoveryTicks = Set([1, max(1, expected.ticks / 2), max(1, expected.ticks - 1)])
            var recovered: [Int] = []
            while !session.isComplete && session.currentTick <= expected.ticks {
                while input < live.count && live[input].0 == session.currentTick {
                    switch live[input].2 {
                    case let .assign(id, skill):
                        try check(session.assign(skillIndex: ClassicSkill.allCases.firstIndex(of: skill)!, to: id) == nil,
                                  "Rejected input \(input): \(label)")
                    case let .releaseRate(rate): session.adjustRate(by: rate - session.rate)
                    case .nuke: session.nuke()
                    }
                    input += 1
                }
                if recoveryTicks.contains(session.currentTick) {
                    let tick = session.currentTick
                    var checkpoint = RunRecovery(engine: "official-quest-validation", profileID: "isolated-test",
                        runID: UUID(), dataSetID: set.identifierKey, levelIndex: index,
                        levelFingerprint: replay.initialStateHash, initialStateHash: replay.initialStateHash,
                        tick: tick, events: session.recoveryEvents,
                        stateHash: ClassicDOSReplayRecorder.stateHash(of: session.simulation),
                        usedRewind: false, nukeCount: session.nukeCount, rewindCount: 0, undoCount: 0,
                        selectedSkill: 0, scrollX: 0, scrollY: 0)
                    checkpoint.fullQuest = true
                    let url = scratch.appendingPathComponent("\(title.rawValue)-\(index)-\(tick).json")
                    let writer = RunRecoveryFile(url: url)
                    _ = try writer.load()
                    try writer.save(checkpoint)
                    guard let saved = try RunRecoveryFile(url: url).load() else {
                        throw Failure(description: "Missing checkpoint: \(label)")
                    }
                    try check(saved.fullQuest == true, "Checkpoint lost Full Quest mode")
                    let restored = freshSession()
                    try restored.restore(saved)
                    // Recovery does not replay transient sound events. A rate
                    // input that changes nothing clears that event buffer and
                    // is intentionally absent from the recorded input log.
                    var restoredState = restored.simulation
                    var originalState = session.simulation
                    restoredState.setReleaseRate(restoredState.releaseRate)
                    originalState.setReleaseRate(originalState.releaseRate)
                    try check(restoredState == originalState, "Restored state differs: \(label) at \(tick)")
                    session = restored
                    recovered.append(tick)
                }
                session.tick()
            }
            let outcome = ClassicDOSReplayOutcome(ticks: session.currentTick, released: session.released,
                saved: session.saved, required: session.required, didWin: session.didWin,
                stateHash: ClassicDOSReplayRecorder.stateHash(of: session.simulation))
            try check(input == live.count && outcome == expected && outcome.didWin,
                      "Session result differs: \(label), got \(outcome.saved)/\(outcome.required) at \(outcome.ticks)")
            try check(Set(recovered) == recoveryTicks, "Missing recovery checkpoint: \(label)")
            flow.finishLevel(saved: session.saved, required: session.required, total: session.total)
            try check(flow.screen == .results(level: index, saved: session.saved, required: session.required, total: session.total),
                      "Wrong result screen: \(label)")
            flow.acknowledgeResults()
            if case .rankComplete = flow.screen { flow.acknowledgeRankComplete() }
            passed[title] = index + 1
            // Write progress to disk and rebuild the flow, as on an app launch.
            let progressURL = scratch.appendingPathComponent("progress.json")
            try JSONEncoder().encode(flow.progress).write(to: progressURL, options: .atomic)
            var resumed = ClassicGameFlow(campaign: campaign)
            resumed.restore(try JSONDecoder().decode(ClassicGameFlow.Progress.self, from: Data(contentsOf: progressURL)))
            try check(resumed.passed == flow.passed, "Progress lost passed levels: \(label)")
            if index + 1 < campaign.levels.count {
                resumed.resumeCampaign()
                try check(resumed.screen == flow.screen, "Resume skipped the next level: \(label)")
                flow = resumed
            } else { try check(flow.screen == .gameComplete, "Missing campaign ending: \(label)") }
            resumes += 1
            evidence.append(.init(title: title.rawValue, rank: entry.rank, number: entry.number,
                fixtureSHA256: digest(data), initialStateHash: replay.initialStateHash, outcome: outcome,
                recoveryTicks: recovered))
            print("PASS \(label): win, three recovery points, results and progress resume")
            fflush(nil)
        }
        let destination = library().next(after: title, mode: .quest)
        if chapterIndex + 1 < releases.count {
            let next = releases[chapterIndex + 1].0
            try check(destination == .title(next) && library().questStart == next, "Wrong chapter transition after \(title)")
            transitions += 1
        } else { try check(destination == .questComplete, "Missing final Full Quest result") }
    }
    try check(evidence.count == expectedLevels && library().passed == expectedLevels
        && library().total == expectedLevels, "Incomplete Classic quest")
    let report = Report(scope: includeConversions
        ? "352 Classic levels: 292 official levels and 60 conversions; sequel previews excluded"
        : "292 official Classic levels; conversions and sequel previews excluded",
        levels: evidence.count, recoveries: evidence.reduce(0) { $0 + $1.recoveryTicks.count },
        progressResumes: resumes, chapterTransitions: transitions, finalDestination: "questComplete", evidence: evidence)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    try encoder.encode(report).write(to: URL(fileURLWithPath: args[2]), options: .atomic)
    print("PASS Classic Full Quest: \(report.levels) wins, \(report.recoveries) recoveries, \(report.progressResumes) progress resumes, \(report.chapterTransitions) chapter transitions and final result")
} catch {
    FileHandle.standardError.write(Data("Official Classic quest failed: \(error)\n".utf8))
    exit(1)
}
