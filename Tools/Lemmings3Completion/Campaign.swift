import Foundation
import NxlvKit

private struct ChainStep: Codable, Equatable {
    let fixture: String
    let fixtureSHA256: String
    let level: Int
    let population: Int
    let saved: Int
    let lost: Int
    let reserves: Int
    let ticks: Int
    let stateHash: String
}

private struct ChainGap: Codable, Equatable {
    let tribe: String
    let level: Int
    let population: Int
}

private struct ChainEvidence: Codable, Equatable {
    let schemaVersion: Int
    let steps: [ChainStep]
    let gaps: [ChainGap]
}

private func play(_ inputs: [L3Replay.Input], from start: Lemmings3Runtime) throws -> Lemmings3Runtime {
    var game = start
    var cursor = 0
    while !game.isComplete && game.tick < 30_000 {
        while cursor < inputs.count && inputs[cursor].tick == game.tick {
            guard L3Replay.apply(inputs[cursor], to: &game) else {
                throw SequelDataError.invalid("L3 campaign input \(cursor) failed at tick \(game.tick).")
            }
            cursor += 1
        }
        game.step()
    }
    guard cursor == inputs.count, game.isComplete, game.saved > 0 else {
        throw SequelDataError.invalid("L3 campaign route did not finish with every input applied.")
    }
    return game
}

private func verifyCarriedFixtures(root: URL, directory: URL) throws -> Int {
    let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    for file in files {
        do {
            let replay = try JSONDecoder().decode(L3Replay.self, from: Data(contentsOf: file))
            guard (1...1000).contains(replay.population),
                  file.lastPathComponent == String(format: "%03d-%d.json", replay.level, replay.population),
                  let tribe = Lemmings3ClassicCampaign.Tribe.allCases.first(where: {
                      ($0.firstLevel...($0.firstLevel + 29)).contains(replay.level)
                  }) else { throw SequelDataError.invalid("Carried fixture name, level or population differs.") }
            let campaign = try Lemmings3ClassicCampaign(root: root, tribe: tribe)
            let level = campaign.levels[replay.level - tribe.firstLevel]
            let style = try Lemmings3Style(directory: root.appendingPathComponent("STYLES"), number: tribe.rawValue)
            let permanent = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
                String(format: "LEVELS/PERM%03d.OBS", level.permanentObjectsReference))))
            let temporary = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
                String(format: "LEVELS/TEMP%03d.OBS", level.temporaryObjectsReference))))
            let initial = try Lemmings3Runtime(level: level, style: style, permanent: permanent,
                temporary: temporary, total: replay.population)
            let first = try replay.replay(from: initial, levelData: level.rawData)
            let second = try replay.replay(from: initial, levelData: level.rawData)
            guard L3Replay.Outcome(first) == L3Replay.Outcome(second) else {
                throw SequelDataError.invalid("Carried fixture replays disagree.")
            }
        } catch {
            throw SequelDataError.invalid("Carried fixture \(file.lastPathComponent) failed: \(error)")
        }
    }
    return files.count
}

@main private enum Lemmings3CampaignProof {
    static func main() throws {
        let arguments = Set(CommandLine.arguments.dropFirst())
        guard arguments.isSubset(of: ["--write", "--require-all"]), !arguments.contains("--write") || arguments.count == 1 else {
            throw SequelDataError.invalid("Usage: Lemmings3CampaignProof [--write | --require-all]")
        }
        let project = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let root = project.appendingPathComponent("Sources/Ports/LEM3CD")
        let manifest = project.appendingPathComponent("Documentation/CampaignCompletion/l3-chain-evidence.json")
        let originalFixtures = project.appendingPathComponent("Tests/Lemmings3CompletionTests/Fixtures")
        let carriedFixtures = project.appendingPathComponent("Tests/Lemmings3CampaignTests/Fixtures")
        let carriedCount = try verifyCarriedFixtures(root: root, directory: carriedFixtures)
        var steps: [ChainStep] = []
        var gaps: [ChainGap] = []
        for tribe in Lemmings3ClassicCampaign.Tribe.allCases {
            var campaign = try Lemmings3ClassicCampaign(root: root, tribe: tribe)
            let style = try Lemmings3Style(directory: root.appendingPathComponent("STYLES"), number: tribe.rawValue)
            for (index, level) in campaign.levels.enumerated() {
                let number = tribe.firstLevel + index
                let carriedName = String(format: "%03d-%d.json", number, campaign.population)
                let originalName = String(format: "%03d.json", number)
                let carried = carriedFixtures.appendingPathComponent(carriedName)
                let hasCarried = FileManager.default.fileExists(atPath: carried.path)
                let file = hasCarried ? carried : originalFixtures.appendingPathComponent(originalName)
                guard FileManager.default.fileExists(atPath: file.path) else {
                    gaps.append(.init(tribe: tribe.title, level: number, population: campaign.population))
                    break
                }
                let data = try Data(contentsOf: file)
                let replay = try JSONDecoder().decode(L3Replay.self, from: data)
                guard replay.version == 1, replay.level == number,
                      replay.levelSHA256 == L3Replay.digest(level.rawData),
                      !hasCarried || replay.population == campaign.population,
                      replay.inputs.count <= 100_000,
                      replay.inputs.allSatisfy({ (0..<30_000).contains($0.tick) }),
                      zip(replay.inputs, replay.inputs.dropFirst()).allSatisfy({ $0.tick <= $1.tick }) else {
                    throw SequelDataError.invalid("L3 campaign fixture identity or input order differs at level \(number).")
                }
                let permanent = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
                    String(format: "LEVELS/PERM%03d.OBS", level.permanentObjectsReference))))
                let temporary = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
                    String(format: "LEVELS/TEMP%03d.OBS", level.temporaryObjectsReference))))
                let start = try Lemmings3Runtime(level: level, style: style, permanent: permanent,
                                                 temporary: temporary, total: campaign.population)
                let first: Lemmings3Runtime
                let second: Lemmings3Runtime
                if replay.population == campaign.population {
                    first = try replay.replay(from: start, levelData: level.rawData)
                    second = try replay.replay(from: start, levelData: level.rawData)
                } else {
                    let standaloneStart = try Lemmings3Runtime(level: level, style: style,
                        permanent: permanent, temporary: temporary, total: replay.population)
                    _ = try replay.replay(from: standaloneStart, levelData: level.rawData)
                    do {
                        first = try play(replay.inputs, from: start)
                        second = try play(replay.inputs, from: start)
                    } catch {
                        gaps.append(.init(tribe: tribe.title, level: number, population: campaign.population))
                        break
                    }
                }
                let outcome = L3Replay.Outcome(first)
                guard outcome == L3Replay.Outcome(second) else {
                    throw SequelDataError.invalid("L3 campaign replays disagree at level \(number).")
                }
                let fixture = hasCarried ? "Tests/Lemmings3CampaignTests/Fixtures/\(carriedName)"
                                         : "Tests/Lemmings3CompletionTests/Fixtures/\(originalName)"
                steps.append(.init(fixture: fixture, fixtureSHA256: L3Replay.digest(data), level: number,
                                   population: campaign.population, saved: first.saved, lost: first.lost,
                                   reserves: first.reserve, ticks: first.tick, stateHash: outcome.stateHash))
                if index == 29 {
                    guard campaign.record(first) else { throw SequelDataError.invalid("L3 final result was rejected.") }
                    guard campaign.completed.count == campaign.levels.count else {
                        throw SequelDataError.invalid("L3 strict campaign proof missed a level in the tribe.")
                    }
                    guard campaign.hasCompletedTribe else {
                        throw SequelDataError.invalid("L3 \(tribe.title) finale finished below the 50-lemming tribe target.")
                    }
                } else {
                    guard campaign.advance(after: first) else {
                        throw SequelDataError.invalid("L3 campaign did not advance after level \(number).")
                    }
                }
            }
        }
        let evidence = ChainEvidence(schemaVersion: 1, steps: steps, gaps: gaps)
        if arguments.contains("--write") {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            var data = try encoder.encode(evidence)
            data.append(10)
            try data.write(to: manifest, options: .atomic)
        } else {
            let recorded = try JSONDecoder().decode(ChainEvidence.self, from: Data(contentsOf: manifest))
            guard evidence == recorded else {
                throw SequelDataError.invalid("L3 campaign route, outcome or first gap differs from the recorded chain evidence.")
            }
        }
        print("PASS L3 campaign prefixes: \(steps.count) carried results, \(gaps.count) open chains")
        print("PASS \(carriedCount) carried-population fixtures double-replayed")
        for gap in gaps {
            let noun = gap.population == 1 ? "lemming" : "lemmings"
            print("GAP \(gap.tribe) \(gap.level): \(gap.population) \(noun)")
        }
        if arguments.contains("--require-all"), !gaps.isEmpty { exit(1) }
    }
}
