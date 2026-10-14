import Foundation
import NxlvKit

@main private enum Lemmings3CarriedRouteDerivation {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let refreshEngine = arguments.last == "--refresh-engine"
        let values = refreshEngine ? Array(arguments.dropLast()) : arguments
        guard values.count == 4, let number = Int(values[0]),
              let population = Int(values[1]), population > 0 else {
            throw SequelDataError.invalid("Usage: Derive LEVEL POPULATION SOURCE_FIXTURE OUTPUT_CANDIDATE [--refresh-engine]")
        }
        let source = URL(fileURLWithPath: values[2])
        let output = URL(fileURLWithPath: values[3])
        guard source.standardizedFileURL != output.standardizedFileURL else {
            throw SequelDataError.invalid("The candidate output must differ from its source fixture.")
        }
        let project = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let root = URL(fileURLWithPath: ProcessInfo.processInfo.environment["L3_PORTS_ROOT"]
            ?? project.appendingPathComponent("Sources/Ports/LEM3CD").path)
        guard let tribe = Lemmings3ClassicCampaign.Tribe.allCases.first(where: {
            ($0.firstLevel...($0.firstLevel + 29)).contains(number)
        }) else {
            throw SequelDataError.invalid("The level number is outside the three L3 tribes.")
        }
        let campaign = try Lemmings3ClassicCampaign(root: root, tribe: tribe)
        let level = campaign.levels[number - tribe.firstLevel]
        let style = try Lemmings3Style(directory: root.appendingPathComponent("STYLES"), number: tribe.rawValue)
        let permanent = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
            String(format: "LEVELS/PERM%03d.OBS", level.permanentObjectsReference))))
        let temporary = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
            String(format: "LEVELS/TEMP%03d.OBS", level.temporaryObjectsReference))))
        let donor = try JSONDecoder().decode(L3Replay.self, from: Data(contentsOf: source))
        guard donor.level == number, donor.levelSHA256 == L3Replay.digest(level.rawData),
              donor.inputs.count <= 100_000, donor.inputs.allSatisfy({ (0..<30_000).contains($0.tick) }),
              zip(donor.inputs, donor.inputs.dropFirst()).allSatisfy({ $0.tick <= $1.tick }),
              !refreshEngine || donor.population == population else {
            throw SequelDataError.invalid("The source fixture level, data, population or input order differs.")
        }
        if !refreshEngine {
            let donorStart = try Lemmings3Runtime(level: level, style: style, permanent: permanent,
                                                  temporary: temporary, total: donor.population)
            _ = try donor.replay(from: donorStart, levelData: level.rawData)
        }

        let start = try Lemmings3Runtime(level: level, style: style, permanent: permanent,
                                        temporary: temporary, total: population)
        var game = start
        var cursor = 0
        var accepted: [L3Replay.Input] = []
        while !game.isComplete && game.tick < 30_000 {
            while cursor < donor.inputs.count && donor.inputs[cursor].tick == game.tick {
                let input = donor.inputs[cursor]
                if L3Replay.apply(input, to: &game) { accepted.append(input) }
                cursor += 1
            }
            game.step()
        }
        guard game.isComplete, game.saved > 0 else {
            throw SequelDataError.invalid("The source inputs do not win at the carried population.")
        }
        let derived = L3Replay(level: number, levelSHA256: L3Replay.digest(level.rawData),
            population: population, initialStateHash: L3Replay.stateHash(start),
            inputs: accepted, expected: .init(game))
        _ = try derived.replay(from: start, levelData: level.rawData)
        _ = try derived.replay(from: start, levelData: level.rawData)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(derived).write(to: output, options: .atomic)
        let operation = refreshEngine ? "REFRESHED" : "DERIVED"
        print("\(operation) L3 \(number) at population \(population): saved \(game.saved), lost \(game.lost), " +
              "reserve \(game.reserve), \(accepted.count) inputs kept, \(donor.inputs.count - accepted.count) omitted")
    }
}
