import Foundation
import NxlvKit

// solver <level number>... | missing [--budget SECONDS] [--beam N] [--promote]
// Searches Lemmings 3 levels with 20 lemmings. A route counts only after two replays agree.
let arguments = Array(CommandLine.arguments.dropFirst())
func option(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}
var limits = L3Limits()
if let value = option("--budget").flatMap(Double.init) { limits.budgetSeconds = value }
if let value = option("--beam").flatMap(Int.init) { limits.beamWidth = value }
if let value = option("--depth").flatMap(Int.init) { limits.maxDepth = value }
let promoting = arguments.contains("--promote")
fewerInputsFirst = arguments.contains("--fewer-inputs-first")
let root = URL(fileURLWithPath: "Sources/Ports/LEM3CD")
let fixtures = URL(fileURLWithPath: "Tests/Lemmings3CompletionTests/Fixtures")
let out = URL(fileURLWithPath: option("--out") ?? ".build/l3-solver/candidates")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let optionValues = Set(["--budget", "--beam", "--depth", "--out"].compactMap { option($0) })
var requested = Set(arguments.filter { !optionValues.contains($0) }.compactMap(Int.init))
let missingOnly = arguments.contains("missing")

var failed = false
for tribe in Lemmings3ClassicCampaign.Tribe.allCases {
    let campaign = try Lemmings3ClassicCampaign(root: root, tribe: tribe)
    let style = try Lemmings3Style(directory: root.appendingPathComponent("STYLES"), number: tribe.rawValue)
    for (index, level) in campaign.levels.enumerated() {
        let number = tribe.firstLevel + index
        let file = fixtures.appendingPathComponent(String(format: "%03d.json", number))
        let existing = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(L3Replay.self, from: $0) }
        guard requested.contains(number) || (missingOnly && existing == nil) else { continue }
        requested.remove(number)
        let perm = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/PERM%03d.OBS", level.permanentObjectsReference))))
        let temp = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(String(format: "LEVELS/TEMP%03d.OBS", level.temporaryObjectsReference))))
        let base = try Lemmings3Runtime(level: level, style: style, permanent: perm, temporary: temp, total: 20)
        // The depth follows the level: decision points on a run without input, plus 40. A search that
        // ends before its budget runs again with a wider beam, as the Lemmings 2 solver does.
        var passive = L3Candidate(game: base, detector: L3Detector(cell: limits.cell, refire: limits.refire))
        var points = 0
        while l3Advance(&passive, limits: limits) { points += 1 }
        var run = limits
        if option("--depth") == nil { run.maxDepth = points + 40 }
        let started = Date()
        var report = L3Report()
        var rounds = 0
        while true {
            rounds += 1
            run.budgetSeconds = limits.budgetSeconds - Date().timeIntervalSince(started)
            guard run.budgetSeconds > 0 else { break }
            let attempt = l3Search(from: base, limits: run)
            report.expanded += attempt.expanded
            if let found = attempt.best, report.best.map({ $0.game.saved < found.game.saved || ($0.game.saved == found.game.saved && $0.game.survivors < found.game.survivors) }) ?? true { report.best = found }
            if report.bestPartial == nil || (attempt.bestPartial?.game.saved ?? 0) > (report.bestPartial?.game.saved ?? 0) { report.bestPartial = attempt.bestPartial }
            if report.best?.game.lost == 0 || attempt.seconds >= run.budgetSeconds || run.beamWidth >= 4096 { break }
            run.beamWidth *= 2
        }
        report.seconds = Date().timeIntervalSince(started)
        let summary = "decision points \(points), depth \(run.maxDepth), \(rounds) rounds to beam \(run.beamWidth), expanded \(report.expanded), \(Int(report.seconds)) s"
        guard let best = report.best else {
            let partial = report.bestPartial?.game
            print(String(format: "UNSOLVED %03d: best saved %d, lost %d; ", number, partial?.saved ?? 0, partial?.lost ?? 0) + summary)
            fflush(stdout)
            continue
        }
        let replay = L3Replay(level: number, levelSHA256: L3Replay.digest(level.rawData), population: 20,
            initialStateHash: L3Replay.stateHash(base), inputs: best.inputs, expected: .init(best.game))
        do {
            let first = try replay.replay(from: base, levelData: level.rawData)
            let second = try replay.replay(from: base, levelData: level.rawData)
            guard L3Replay.stateHash(first) == L3Replay.stateHash(second) else {
                throw SequelDataError.invalid("two replays disagree")
            }
        } catch {
            print(String(format: "ERROR %03d: ", number) + "\(error)")
            failed = true
            continue
        }
        try encoder.encode(replay).write(to: out.appendingPathComponent(String(format: "%03d.json", number)), options: .atomic)
        let game = best.game
        var line = String(format: "SOLVED %03d: saved %d, lost %d, reserve %d, %d ticks, %d inputs; ", number, game.saved,
                          game.lost, game.reserve, game.tick, best.inputs.count) + summary
        if promoting {
            // A route replaces a fixture only when it keeps more lemmings, or keeps as many and saves more.
            let retained = existing.map { $0.expected.saved + $0.expected.reserves } ?? -1
            if game.survivors > retained || (game.survivors == retained && game.saved > (existing?.expected.saved ?? -1)) {
                try encoder.encode(replay).write(to: file, options: .atomic)
                line += existing == nil ? "; PROMOTED new fixture" : "; PROMOTED over \(existing!.expected.saved) saved"
            } else {
                line += "; KEPT fixture keeps \(retained)"
            }
        }
        print(line)
        fflush(stdout)
    }
}
exit(failed ? 1 : 0)
