import Foundation
import NxlvKit

// Runs the DOS simulation against every official campaign level using real
// imported data. The unit regressions cover rules on synthetic terrain; this
// harness proves the same engine survives all 120 shipping levels end to end.

private struct SmokeFailure: Error, CustomStringConvertible {
    let description: String
}

private func require(
    _ condition: @autoclosure () -> Bool,
    _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw SmokeFailure(description: message()) }
}

private struct LevelReport {
    let index: Int
    let rank: String
    let title: String
    let entrances: Int
    let exitTriggers: Int
    let released: Int
    let saved: Int
    let moved: Bool
    let actions: Set<String>
}

private let ticksToRun = ClassicDOSRules.ticksPerSecond * 30

private func run(dataDirectory: URL) throws -> [LevelReport] {
    // The scanner must find every physical record without an order table.
    let scanned = try ClassicCampaign.scan(directory: dataDirectory)
    try require(
        scanned.levels.count == 80,
        "scan found \(scanned.levels.count) physical levels, expected 80")
    print("Scanner found \(scanned.levels.count) physical levels with no order table.")

    let campaign = try ClassicCampaignDefinition.originalDOSLemmings.load(from: dataDirectory)
    let assets = try ClassicMainDATAssets.load(from: dataDirectory)

    var grounds: [Int: ClassicGroundSet] = [:]
    for style in 0..<5 {
        grounds[style] = try ClassicGroundSet.load(style: style, from: dataDirectory)
    }
    var specials: [Int: ClassicSpecialGraphic] = [:]
    for index in 0..<4 {
        specials[index + 1] = try ClassicSpecialGraphic.load(index: index, from: dataDirectory)
    }

    try require(campaign.levels.count == 120, "expected 120 levels, found \(campaign.levels.count)")

    var reports: [LevelReport] = []
    for (index, entry) in campaign.levels.enumerated() {
        let level = entry.level
        guard let ground = grounds[level.groundStyle] else {
            throw SmokeFailure(description: "level \(index + 1): missing ground style \(level.groundStyle)")
        }
        let rendered = try ClassicLevelRenderer.render(
            level,
            groundSet: ground,
            specialGraphic: specials[level.specialStyle]
        )

        var simulation = try ClassicDOSSimulation(
            level: level,
            renderedLevel: rendered,
            mainDATAssets: assets
        )

        try require(
            !simulation.configuration.entrances.isEmpty,
            "level \(index + 1) '\(level.title)': no entrances"
        )

        let exitTriggers = simulation.configuration.triggers.filter { $0.effect == .exit }.count

        var firstPositions: [Int: ClassicDOSPoint] = [:]
        var moved = false
        var actions: Set<String> = []

        for _ in 0..<ticksToRun {
            _ = simulation.tick()
            for lemming in simulation.lemmings where lemming.isActive {
                actions.insert(lemming.action.rawValue)
                if let seen = firstPositions[lemming.id] {
                    if seen != lemming.foot { moved = true }
                } else {
                    firstPositions[lemming.id] = lemming.foot
                }
            }
            if simulation.isComplete { break }
        }

        try require(
            simulation.releasedCount > 0,
            "level \(index + 1) '\(level.title)': no lemmings released in \(ticksToRun) ticks"
        )
        try require(
            moved,
            "level \(index + 1) '\(level.title)': lemmings released but never moved"
        )

        reports.append(
            LevelReport(
                index: index + 1,
                rank: entry.rank,
                title: level.title.trimmingCharacters(in: .whitespaces),
                entrances: simulation.configuration.entrances.count,
                exitTriggers: exitTriggers,
                released: simulation.releasedCount,
                saved: simulation.savedCount,
                moved: moved,
                actions: actions
            )
        )
    }
    return reports
}

let arguments = CommandLine.arguments
let directory = arguments.count > 1
    ? URL(fileURLWithPath: arguments[1], isDirectory: true)
    : URL(fileURLWithPath: "Content/lemming1.pc", isDirectory: true)

do {
    let reports = try run(dataDirectory: directory)
    let withoutExit = reports.filter { $0.exitTriggers == 0 }
    let multiEntrance = reports.filter { $0.entrances > 1 }
    let reachedExit = reports.filter { $0.saved > 0 }
    let allActions = reports.reduce(into: Set<String>()) { $0.formUnion($1.actions) }

    print("Classic DOS campaign smoke passed.")
    print("  levels simulated       : \(reports.count)")
    print("  ticks per level        : \(ticksToRun) (\(ticksToRun / ClassicDOSRules.ticksPerSecond)s)")
    print("  levels with >1 entrance: \(multiEntrance.count)")
    print("  levels with an exit    : \(reports.count - withoutExit.count)")
    print("  levels saving unaided  : \(reachedExit.count)")
    print("  distinct actions seen  : \(allActions.sorted().joined(separator: ", "))")

    if !withoutExit.isEmpty {
        print("  NOTE: no exit trigger decoded for \(withoutExit.count) level(s):")
        for report in withoutExit.prefix(10) {
            print("    \(report.index). \(report.rank) — \(report.title)")
        }
    }
} catch {
    FileHandle.standardError.write(Data("Campaign smoke failed: \(error)\n".utf8))
    exit(1)
}
