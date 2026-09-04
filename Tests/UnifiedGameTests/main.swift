import Foundation
import NxlvKit

struct Failure: Error, CustomStringConvertible { let description: String }
func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw Failure(description: message) }
}

func navigation() throws {
    let all = ClassicTitle.allCases.map { UnifiedGameLibrary.Entry(title: $0,
        total: $0.expectedLevelCount!, passed: $0.expectedLevelCount!) }
    let library = UnifiedGameLibrary(entries: all.reversed())
    try require(library.total == 502 && library.passed == 502, "Canon count must include each Holiday release once")
    for (index, title) in ClassicTitle.allCases.enumerated() {
        try require(library.next(after: title, mode: .singleTitle) == .library, "Single title must return to library")
        let expected: UnifiedGameLibrary.Destination = index + 1 < all.count
            ? .title(ClassicTitle.allCases[index + 1]) : .questComplete
        try require(library.next(after: title, mode: .quest) == expected, "Quest routing failed for \(title)")
    }
    let partial = UnifiedGameLibrary(entries: [
        .init(title: .lemmings, total: 120, passed: 120),
        .init(title: .lemmings2TheTribes, total: 120, passed: 10),
        .init(title: .holidayLemmings1993, total: 32, available: false),
        .init(title: .lemmings3TheChronicles, total: 90)])
    try require(partial.questStart == .lemmings2TheTribes, "Resume must stop at an unfinished sequel")
    try require(partial.next(after: .lemmings2TheTribes, mode: .quest) == .library, "One tribe is not a completed title")
    try require(partial.total == 330, "Unavailable data must not count as installed")
    var flow = ClassicGameFlow(ranks: [.init(name: "A", levelIndices: [0, 1]), .init(name: "B", levelIndices: [2])])
    flow.selectLevel(rank: 1, position: 0); flow.beginPlaying()
    flow.finishLevel(saved: 1, required: 1, total: 1); flow.acknowledgeResults(); flow.acknowledgeRankComplete()
    try require(flow.screen == .rankSelect, "Skipping to the last level must not finish a title")
    flow.resumeCampaign()
    try require(flow.screen == .briefing(level: 0), "Resume must return to the first gap")
    print("PASS shared navigation, all eight releases, partial sequels, and skipped levels")
}

func campaigns(_ resources: URL) throws {
    let ports = resources.appendingPathComponent("Ports")
    let directories = try FileManager.default.contentsOfDirectory(at: ports, includingPropertiesForKeys: nil)
    var seen: Set<ClassicTitle> = []
    var total = 0
    for directory in directories.sorted(by: { $0.path < $1.path }) {
        guard let set = try? ClassicDataSet.detect(directory: directory), let title = set.title else { continue }
        if seen.contains(title) { continue }
        seen.insert(title)
        try require(set.campaign.levels.count == title.expectedLevelCount, "Incorrect count: \(title)")
        let assets = try ClassicMainDATAssets.load(from: directory)
        var grounds: [Int: ClassicGroundSet] = [:]
        for style in set.groundStyles { grounds[style] = try ClassicGroundSet.load(style: style, from: directory) }
        var specials: [Int: ClassicSpecialGraphic] = [:]
        for style in set.specialIndices { specials[style + 1] = try ClassicSpecialGraphic.load(index: style, from: directory) }
        for entry in set.campaign.levels {
            let rendered = try ClassicLevelRenderer.render(entry.level, groundSet: grounds[entry.level.groundStyle]!, specialGraphic: specials[entry.level.specialStyle])
            var simulation = try ClassicDOSSimulation(level: entry.level, renderedLevel: rendered, mainDATAssets: assets)
            try require(!simulation.configuration.entrances.isEmpty, "Missing entrance in \(entry.level.title)")
            try require(simulation.configuration.triggers.contains { $0.effect == .exit }, "Missing exit in \(entry.level.title)")
            for _ in 0..<200 { _ = simulation.tick() }
            try require(simulation.releasedCount > 0, "No lemmings released in \(entry.level.title)")
        }
        if title == .ohNoMoreLemmings {
            try require(set.campaign.ranks == ["Tame", "Crazy", "Wild", "Wicked", "Havoc"], "Oh No ratings")
            let first = stride(from: 0, to: 100, by: 20).map { set.campaign.levels[$0].level.title }
            try require(first == ["Down And Out Lemmings", "Quote: \"That`s a good level\"", "PoP YoR ToP!!!", "LeMming ToMato KetchUp fAcilitY", "Tubular Lemmings"], "Oh No rating starts")
            let physical = Set(set.campaign.levels.map { $0.archiveFile * 8 + $0.archiveSection })
            try require(physical == Set(0..<100), "Every Oh No record must appear exactly once")
            let migrated = set.migrateProgress(.init(furthestReached: ["All": 80], passed: ["All#0", "All#80", "All#99"]))
            try require(Set(migrated.passed) == ["Havoc#11", "Tame#0", "Tame#19"], "Physical-order progress migration")
            try require(set.migrateProgress(migrated) == migrated, "Migration must be idempotent")
        }
        if title == .holidayLemmings1993 || title == .holidayLemmings1994 {
            let expected = title == .holidayLemmings1993 ? ["Flurry", "Blizzard"] : ["Frost", "Hail"]
            try require(set.campaign.ranks == expected, "Holiday ratings")
            let first = title == .holidayLemmings1993 ? "Climbing to the Top!" : "Chains of Command"
            try require(set.campaign.levels[0].level.title == first, "Holiday release separation")
        }
        if title == .xmasLemmings1991 || title == .xmasLemmings1992 {
            try require(set.campaign.ranks == ["Xmas"], "Xmas rating")
            let migrated = set.migrateProgress(.init(furthestReached: ["All": 2], passed: ["All#0", "All#1"]))
            try require(Set(migrated.passed) == ["Xmas#0", "Xmas#1"], "Xmas progress migration")
        }
        total += set.campaign.levels.count
        print("PASS \(title.displayName): \(set.campaign.levels.count) levels render, decode triggers, and release lemmings")
    }
    try require(seen.count == 6 && total == 292, "Expected all six classic releases and 292 levels, got \(seen.count) / \(total)")
}

do {
    try navigation()
    guard CommandLine.arguments.count == 2 else { throw Failure(description: "Pass the bundled Resources directory") }
    try campaigns(URL(fileURLWithPath: CommandLine.arguments[1]))
    print("Unified game tests passed.")
} catch {
    FileHandle.standardError.write(Data("Unified game tests failed: \(error)\n".utf8)); exit(1)
}
