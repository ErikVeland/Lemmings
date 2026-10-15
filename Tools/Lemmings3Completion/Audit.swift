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
    }
    private struct Report: Codable {
        let schemaVersion: Int
        let results: [Result]
        var passed: Int { results.filter(\.passed).count }
        var failed: Int { results.count - passed }
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
                do {
                    let replay = try JSONDecoder().decode(L3Replay.self, from: Data(contentsOf: file))
                    levelNumber = replay.level; population = replay.population
                    guard let tribe = Lemmings3ClassicCampaign.Tribe.allCases.first(where: {
                        ($0.firstLevel...($0.firstLevel + 29)).contains(replay.level)
                    }), (1...1000).contains(replay.population) else {
                        throw SequelDataError.invalid("Fixture level or population is outside the campaign.")
                    }
                    let expectedName = directory == standalone
                        ? String(format: "%03d.json", replay.level)
                        : String(format: "%03d-%d.json", replay.level, replay.population)
                    guard file.lastPathComponent == expectedName,
                          directory != standalone || replay.population == 20 else {
                        throw SequelDataError.invalid("Fixture filename, level or population differs.")
                    }
                    let campaign = try Lemmings3ClassicCampaign(root: root, tribe: tribe)
                    let level = campaign.levels[replay.level - tribe.firstLevel]
                    let style = try Lemmings3Style(directory: root.appendingPathComponent("STYLES"), number: tribe.rawValue)
                    let permanent = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
                        String(format: "LEVELS/PERM%03d.OBS", level.permanentObjectsReference))))
                    let temporary = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
                        String(format: "LEVELS/TEMP%03d.OBS", level.temporaryObjectsReference))))
                    let base = try Lemmings3Runtime(level: level, style: style,
                        permanent: permanent, temporary: temporary, total: replay.population)
                    _ = try replay.replay(from: base, levelData: level.rawData)
                    _ = try replay.replay(from: base, levelData: level.rawData)
                    results.append(.init(fixture: file.path, level: replay.level,
                        population: replay.population, passed: true, failure: nil))
                } catch {
                    results.append(.init(fixture: file.path, level: levelNumber,
                        population: population, passed: false, failure: String(describing: error)))
                    print("FAIL \(file.path): \(error)"); fflush(stdout)
                }
            }
        }
        let report = Report(schemaVersion: 1, results: results)
        if let output = arguments.first {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(report).write(to: URL(fileURLWithPath: output), options: .atomic)
        }
        print("Audited \(results.count) retained L3 fixtures: \(report.passed) passed twice; \(report.failed) failed.")
        // Coverage and linked survivor accounting remain the strict campaign gate's responsibility.
        if results.isEmpty || report.failed > 0 { exit(1) }
    }
}
