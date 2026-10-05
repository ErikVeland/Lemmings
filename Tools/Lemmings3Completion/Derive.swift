import Foundation
import NxlvKit

@main private enum Lemmings3CarriedRouteDerivation {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.count == 4, let number = Int(arguments[0]),
              let population = Int(arguments[1]), population > 0 else {
            throw SequelDataError.invalid("Usage: Derive LEVEL POPULATION SOURCE_FIXTURE OUTPUT_CANDIDATE")
        }
        let source = URL(fileURLWithPath: arguments[2])
        let output = URL(fileURLWithPath: arguments[3])
        guard source.standardizedFileURL != output.standardizedFileURL else {
            throw SequelDataError.invalid("The candidate output must differ from its source fixture.")
        }
        let project = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let root = project.appendingPathComponent("Sources/Ports/LEM3CD")
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
        guard donor.level == number else {
            throw SequelDataError.invalid("The source fixture belongs to a different level.")
        }
        let donorStart = try Lemmings3Runtime(level: level, style: style, permanent: permanent,
                                              temporary: temporary, total: donor.population)
        _ = try donor.replay(from: donorStart, levelData: level.rawData)

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
        print("DERIVED L3 \(number) at population \(population): saved \(game.saved), lost \(game.lost), " +
              "reserve \(game.reserve), \(accepted.count) inputs kept, \(donor.inputs.count - accepted.count) omitted")
    }
}
