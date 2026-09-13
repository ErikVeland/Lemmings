import Foundation
import NxlvKit

// Reports requirements from local game files. Decoding is not proof of playability.
let root = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1] : "Sources/Ports/Lemm2")
let campaign = try Lemmings2Campaign(root: root)
let masks = try Lemmings2TerrainMasks(root:root)
let names = try Lemmings2FrontEnd(root: root).banks["INFO"]!.strings
struct Fixture: Decodable { let levelSHA256: String }
let fixtures = URL(fileURLWithPath: CommandLine.arguments.count > 2
    ? CommandLine.arguments[2] : "Tests/Lemmings2CompletionTests/Fixtures")
let recorded = try Set(FileManager.default.contentsOfDirectory(at:fixtures,includingPropertiesForKeys:nil)
    .filter { $0.pathExtension == "json" }.map {
        try JSONDecoder().decode(Fixture.self,from:Data(contentsOf:$0)).levelSHA256
    })
guard recorded.isSubset(of:Set(campaign.levels.map(\.fingerprint))) else {
    throw SequelDataError.invalid("A completion fixture refers to an unknown level.")
}
print("# L2 campaign requirements")
print("\nGenerated from local level files. All twelve tribes are enabled in the runtime.")
print("Missing skills below count stocked slots only. Object IDs describe behaviour, not graphics. Loading is not completion evidence.")
print("Recorded completions list the level numbers with saved input fixtures. Run the runtime suite to verify those inputs.")
print("\n| Tribe | Missing stocked skills | Unsupported object types | Levels that load | Recorded completions |")
print("| --- | --- | --- | --- | --- |")
for tribe in 0..<12 {
    let levels = campaign.levels[(tribe * 10)..<(tribe * 10 + 10)]
    let skills = Set(levels.flatMap { $0.skills }.filter {
        $0.count > 0 && Lemmings2Runtime.Skill(rawValue: $0.identifier) == nil
    }.map(\.identifier)).sorted()
    let style = try Lemmings2Style(data: Data(contentsOf: root.appendingPathComponent(
        "STYLES/\(Lemmings2Campaign.styleNames[tribe]).DAT")))
    var types = Set<Int>()
    for level in levels {
        for placed in level.objects where placed.identifier != 65535 {
            guard style.objects.indices.contains(placed.identifier) else {
                throw SequelDataError.invalid("Unknown object in \(level.title).")
            }
            let type = style.objects[placed.identifier].type
            if !Array(0...14).contains(type) { types.insert(type) }
        }
    }
    let loadCount = levels.filter { (try? Lemmings2Runtime(level:$0,style:style,masks:masks,allowExperimentalTribes:true)) != nil }.count
    let missing = skills.map { names.indices.contains($0 - 1) ? names[$0 - 1] : "ID \($0)" }
    let completed = levels.enumerated().filter { recorded.contains($0.element.fingerprint) }.map { String($0.offset+1) }
    print("| \(Lemmings2Campaign.tribeNames[tribe]) | \(missing.isEmpty ? "None" : missing.joined(separator: ", ")) | \(types.isEmpty ? "None" : types.sorted().map(String.init).joined(separator: ", ")) | \(loadCount)/10 | \(completed.isEmpty ? "None" : completed.joined(separator: ", ")) |")
}
print("\n\(recorded.count) of 120 levels have recorded completions. Missing fixtures are verification gaps, not confirmed gameplay defects.")
