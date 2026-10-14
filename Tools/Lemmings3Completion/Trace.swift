import Foundation
import NxlvKit

@main
struct L3GuideTraceCommand {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let routePath = arguments.first, arguments.count == 3, arguments[1] == "--through",
              let throughTick = Int(arguments[2]) else {
            throw SequelDataError.invalid("Usage: Trace <guide-prefix.json> --through <tick>.")
        }
        let seed = try JSONDecoder().decode(L3GuideSeed.self, from: Data(contentsOf: URL(fileURLWithPath: routePath)))
        let root = URL(fileURLWithPath: ProcessInfo.processInfo.environment["L3_PORTS_ROOT"]
            ?? "Sources/Ports/LEM3CD")
        guard let tribe = Lemmings3ClassicCampaign.Tribe.allCases.first(where: {
            ($0.firstLevel...($0.firstLevel + 29)).contains(seed.level)
        }) else {
            throw SequelDataError.invalid("L3 guide level is outside the three original campaigns.")
        }
        let campaign = try Lemmings3ClassicCampaign(root: root, tribe: tribe)
        let levelIndex = seed.level - tribe.firstLevel
        let level = campaign.levels[levelIndex]
        let style = try Lemmings3Style(directory: root.appendingPathComponent("STYLES"), number: tribe.rawValue)
        let permanent = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
            String(format: "LEVELS/PERM%03d.OBS", level.permanentObjectsReference))))
        let temporary = try Lemmings3Objects(data: Data(contentsOf: root.appendingPathComponent(
            String(format: "LEVELS/TEMP%03d.OBS", level.temporaryObjectsReference))))
        let base = try Lemmings3Runtime(level: level, style: style, permanent: permanent, temporary: temporary,
                                        total: seed.population)
        let result = try L3GuideTrace.replay(seed: seed, from: base, levelData: level.rawData, throughTick: throughTick)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(result), as: UTF8.self))
    }
}
