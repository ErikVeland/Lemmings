import Foundation
import NxlvKit

/// Diagnose every retained route without stopping at the first invalid replay.
@main private enum Lemmings3FixtureAudit {
    private struct Result: Codable {
        let fixture: String
        let level: Int
        let population: Int
        let passed: Bool
        let failure: String?
        let routeStatus: String
        let rebasedOutcome: L3Replay.Outcome?
        let rebasedFailure: String?
    }
    private struct Report: Codable {
        let schemaVersion: Int
        let results: [Result]
        var passed: Int { results.filter(\.passed).count }
        var failed: Int { results.count - passed }
        var rebasedWins: Int { results.filter { $0.routeStatus == "rebased-win" }.count }
        var routeFailures: Int { results.filter { $0.routeStatus == "route-fails" }.count }
    }
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.count <= 1 else {
            throw SequelDataError.invalid("Usage: L3FixtureAudit [REPORT_JSON]")
        }
        let root = URL(fileURLWithPath: ProcessInfo.processInfo.environment["L3_PORTS_ROOT"]
            ?? "Sources/Ports/LEM3CD")
        let standalone = ProcessInfo.processInfo.environment["L3_COMPLETION_FIXTURES"]
            ?? "Tests/Lemmings3CompletionTests/Fixtures"
        let carried = ProcessInfo.processInfo.environment["L3_CAMPAIGN_FIXTURES"]
            ?? "Tests/Lemmings3CampaignTests/Fixtures"
        var results: [Result] = []
        for directory in [standalone, carried] {
            let files = try FileManager.default.contentsOfDirectory(
                at: URL(fileURLWithPath: directory), includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            for file in files {
                var levelNumber = 0, population = 0
                var replay: L3Replay?
                var base: Lemmings3Runtime?
                var levelData: Data?
                do {
                    let fixture = try JSONDecoder().decode(L3Replay.self, from: Data(contentsOf: file))
                    replay = fixture
                    levelNumber = fixture.level; population = fixture.population
                    guard let tribe = Lemmings3ClassicCampaign.Tribe.allCases.first(where: {
                        ($0.firstLevel...($0.firstLevel + 29)).contains(fixture.level)
                    }), (1...1000).contains(fixture.population) else {
                        throw SequelDataError.invalid("Fixture level or population is outside the campaign.")
                    }
                    let expectedName = directory == standalone
                        ? String(format: "%03d.json", fixture.level)
                        : String(format: "%03d-%d.json", fixture.level, fixture.population)
                    guard file.lastPathComponent == expectedName,
                          directory != standalone || fixture.population == 20 else {
                        throw SequelDataError.invalid("Fixture filename, level or population differs.")
                    }
                    let campaign = try Lemmings3ClassicCampaign(root: root, tribe: tribe)
                    let level = campaign.levels[fixture.level - tribe.firstLevel]
                    let style = try Lemmings3Style(directory: root.appendingPathComponent("STYLES"), number: tribe.rawValue)
                    let permanent = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
                        String(format: "LEVELS/PERM%03d.OBS", level.permanentObjectsReference))))
                    let temporary = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
                        String(format: "LEVELS/TEMP%03d.OBS", level.temporaryObjectsReference))))
                    let initial = try Lemmings3Runtime(level: level, style: style,
                        permanent: permanent, temporary: temporary, total: fixture.population)
                    base = initial
                    levelData = level.rawData
                    _ = try fixture.replay(from: initial, levelData: level.rawData)
                    _ = try fixture.replay(from: initial, levelData: level.rawData)
                    results.append(.init(fixture: file.path, level: fixture.level,
                        population: fixture.population, passed: true, failure: nil,
                        routeStatus: "exact", rebasedOutcome: nil, rebasedFailure: nil))
                } catch {
                    let strictFailure = String(describing: error)
                    var rebasedOutcome: L3Replay.Outcome?
                    var rebasedFailure: String?
                    if let replay, let base, let levelData {
                        do {
                            rebasedOutcome = try rebaseAndReplay(replay, from: base, levelData: levelData)
                        } catch {
                            rebasedFailure = String(describing: error)
                        }
                    }
                    let routeStatus = rebasedOutcome == nil ? (replay == nil ? "invalid" : "route-fails") : "rebased-win"
                    results.append(.init(fixture: file.path, level: levelNumber,
                        population: population, passed: false, failure: strictFailure,
                        routeStatus: routeStatus, rebasedOutcome: rebasedOutcome, rebasedFailure: rebasedFailure))
                    print("FAIL \(file.path): \(strictFailure)")
                    if let rebasedOutcome {
                        print("REBASED WIN \(file.lastPathComponent): saved \(rebasedOutcome.saved), lost \(rebasedOutcome.lost)")
                    } else if let rebasedFailure {
                        print("REBASED FAIL \(file.lastPathComponent): \(rebasedFailure)")
                    }
                    fflush(stdout)
                }
            }
        }
        let report = Report(schemaVersion: 1, results: results)
        if let output = arguments.first {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(report).write(to: URL(fileURLWithPath: output), options: .atomic)
        }
        print("Audited \(results.count) retained L3 fixtures: \(report.passed) exact double-replays; " +
              "\(report.rebasedWins) stale-identity routes still win when rebased; " +
              "\(report.routeFailures) input schedules do not win under the current runtime.")
        // Coverage and linked survivor accounting remain the strict campaign gate's responsibility.
        if results.isEmpty || report.failed > 0 { exit(1) }
    }

    private static func rebaseAndReplay(_ replay: L3Replay, from base: Lemmings3Runtime,
                                        levelData: Data) throws -> L3Replay.Outcome {
        guard replay.levelSHA256 == L3Replay.digest(levelData),
              replay.population == base.configuration.total,
              replay.inputs.count <= 100_000,
              replay.inputs.allSatisfy({ (0..<30_000).contains($0.tick) }),
              zip(replay.inputs, replay.inputs.dropFirst()).allSatisfy({ $0.tick <= $1.tick }) else {
            throw SequelDataError.invalid("Fixture data, population or input order differs.")
        }
        func play() throws -> L3Replay.Outcome {
            var game = base, cursor = 0
            while !game.isComplete && game.tick < 30_000 {
                while cursor < replay.inputs.count && replay.inputs[cursor].tick == game.tick {
                    guard L3Replay.apply(replay.inputs[cursor], to: &game) else {
                        throw SequelDataError.invalid("Input \(cursor) was refused at tick \(game.tick).")
                    }
                    cursor += 1
                }
                game.step()
            }
            guard cursor == replay.inputs.count, game.isComplete, game.saved > 0 else {
                throw SequelDataError.invalid("Inputs did not complete the level with a rescue.")
            }
            return L3Replay.Outcome(game)
        }
        let first = try play()
        let second = try play()
        guard first == second else { throw SequelDataError.invalid("Rebased route replays disagree.") }
        return first
    }
}
