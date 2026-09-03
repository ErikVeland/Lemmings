import Dispatch
import Foundation
import NxlvKit

// Reports how far the engine gets on every official level using a bounded
// single-assignment search. This is a diagnostic, not a pass/fail gate. Levels
// that need several skills will not solve here, so the count is a floor.

private struct ProbeFailure: Error, CustomStringConvertible {
    let description: String
}

private struct Prepared {
    let index: Int
    let rank: String
    let number: Int
    let title: String
    let simulation: ClassicDOSSimulation
}

private let probeTickLimit = ClassicDOSRules.ticksPerSecond * 90

private func prepareAll(directory: URL) throws -> [Prepared] {
    let campaign = try ClassicCampaignDefinition.originalDOSLemmings.load(from: directory)
    let assets = try ClassicMainDATAssets.load(from: directory)
    var grounds: [Int: ClassicGroundSet] = [:]
    for style in 0..<5 { grounds[style] = try ClassicGroundSet.load(style: style, from: directory) }
    var specials: [Int: ClassicSpecialGraphic] = [:]
    for index in 0..<4 {
        specials[index + 1] = try ClassicSpecialGraphic.load(index: index, from: directory)
    }

    return try campaign.levels.enumerated().map { index, entry in
        let level = entry.level
        guard let ground = grounds[level.groundStyle] else {
            throw ProbeFailure(description: "missing ground style \(level.groundStyle)")
        }
        let rendered = try ClassicLevelRenderer.render(
            level, groundSet: ground, specialGraphic: specials[level.specialStyle])
        return Prepared(
            index: index + 1,
            rank: entry.rank,
            number: entry.number,
            title: level.title.trimmingCharacters(in: .whitespaces),
            simulation: try ClassicDOSSimulation(
                level: level, renderedLevel: rendered, mainDATAssets: assets)
        )
    }
}

private struct ProbeResult: Sendable {
    let index: Int
    let rank: String
    let number: Int
    let title: String
    let solved: Bool
    let bestSaved: Int
    let required: Int
    let skill: String?
    let tick: Int?
}

private func probe(_ prepared: Prepared) -> ProbeResult {
    let base = prepared.simulation
    let required = base.configuration.requiredToSave
    var bestSaved = 0
    var bestSkill: String?
    var bestTick: Int?

    let available = ClassicSkill.allCases.filter { base.remainingSkillCount($0) > 0 }
    let hash = ClassicDOSReplayRecorder.stateHash(of: base)

    for skill in available {
        for tick in stride(from: 36, through: 320, by: 4) {
            let replay = ClassicDOSReplay(
                rank: prepared.rank,
                number: prepared.number,
                title: prepared.title,
                initialStateHash: hash,
                events: [
                    ClassicDOSReplayEvent(tick: tick, action: .assign(lemmingID: 0, skill: skill))
                ]
            )
            guard
                let outcome = try? ClassicDOSReplayPlayer.run(
                    replay, simulation: base, tickLimit: probeTickLimit, verify: false)
            else { continue }
            if outcome.saved > bestSaved {
                bestSaved = outcome.saved
                bestSkill = skill.rawValue
                bestTick = tick
            }
            if outcome.didWin {
                return ProbeResult(
                    index: prepared.index, rank: prepared.rank, number: prepared.number,
                    title: prepared.title, solved: true, bestSaved: outcome.saved,
                    required: required, skill: skill.rawValue, tick: tick)
            }
        }
    }
    return ProbeResult(
        index: prepared.index, rank: prepared.rank, number: prepared.number,
        title: prepared.title, solved: false, bestSaved: bestSaved, required: required,
        skill: bestSkill, tick: bestTick)
}

/// Collects probe results from concurrent workers.
private final class ResultCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [ProbeResult] = []

    func add(_ result: ProbeResult) {
        lock.lock()
        storage.append(result)
        lock.unlock()
    }

    func sorted() -> [ProbeResult] {
        lock.lock()
        defer { lock.unlock() }
        return storage.sorted { $0.index < $1.index }
    }
}

let arguments = CommandLine.arguments
let directory = arguments.count > 1
    ? URL(fileURLWithPath: arguments[1], isDirectory: true)
    : URL(fileURLWithPath: "Content/lemming1.pc", isDirectory: true)

do {
    let prepared = try prepareAll(directory: directory)
    let collector = ResultCollector()
    DispatchQueue.concurrentPerform(iterations: prepared.count) { index in
        collector.add(probe(prepared[index]))
    }
    let results = collector.sorted()

    let solved = results.filter(\.solved)
    let anySaved = results.filter { $0.bestSaved > 0 }

    print("Classic DOS solvability probe")
    print("  levels probed                 : \(results.count)")
    print("  solved by one assignment      : \(solved.count)")
    print("  saved at least one lemming    : \(anySaved.count)")
    print("")
    print("  Solved levels:")
    for result in solved {
        let skill = result.skill ?? "?"
        let tick = result.tick.map(String.init) ?? "?"
        print(
            "    \(result.rank) \(result.number) — \(result.title)"
                + " [\(skill) @ tick \(tick)] saved \(result.bestSaved)/\(result.required)")
    }
    print("")
    print("  Levels reaching the exit but not winning:")
    for result in anySaved where !result.solved {
        print(
            "    \(result.rank) \(result.number) — \(result.title)"
                + " best \(result.bestSaved)/\(result.required)")
    }
} catch {
    FileHandle.standardError.write(Data("Probe failed: \(error)\n".utf8))
    exit(1)
}
