import Foundation
import NxlvKit

// Looks at one level closely: where its objects sit, and what is solid around
// them, so a gap between a drawn object and the surface a lemming stands on
// can be measured rather than guessed.
let root = URL(
    fileURLWithPath: ".build/local/Ultimate Lemmings.app/Contents/Resources/Ports/holiday_native_1994",
    isDirectory: true)
let rsrcName = ((try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? [])
    .first { $0.lowercased().hasSuffix(".rsrc") }
guard let rsrcName, let fork = try? Data(contentsOf: root.appendingPathComponent(rsrcName)) else {
    print("no resource fork under \(root.path)"); exit(1)
}
let campaign = try ClassicHolidayCampaign.load(resourceFork: fork, title: .holidayLemmings1994)
print("ranks: \(campaign.ranks)")
for (index, entry) in campaign.levels.enumerated() {
    print("  \(index): [\(entry.rank) \(entry.number)] \(entry.level.title)")
}

guard let entry = campaign.levels.first(where: {
    $0.rank.lowercased() == "frost" && $0.number == 3
}) else { print("\nFrost 3 not found"); exit(1) }

let level = entry.level
let ground = try ClassicGroundSet.load(style: level.groundStyle, from: root)
let rendered = try ClassicLevelRenderer.render(level, groundSet: ground)
let solid = [UInt8](rendered.solidMask)

print("\n=== \(level.title)  style=\(level.groundStyle)  \(rendered.width)x\(rendered.height)")
print("terrain pieces \(level.terrain.count), objects \(level.objects.count)")

// Render the same level through the Macintosh artwork and compare.
let macRoot = URL(
    fileURLWithPath: ".build/local/Ultimate Lemmings.app/Contents/Resources/MacArtwork",
    isDirectory: true)
guard let artwork = try? ClassicMacArtwork(
    directory: macRoot.appendingPathComponent("holiday")) else {
    print("no Macintosh holiday artwork"); exit(1)
}
let scene = try ClassicMacScene(
    level: level, rendered: rendered, artwork: artwork, groundSet: ground)
let out = URL(fileURLWithPath: "/tmp/frost3")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
try Data(rendered.solidMask).write(to: out.appendingPathComponent("solid.bin"))
try Data(scene.terrainRGBA).write(to: out.appendingPathComponent("mac.bin"))
try "\(rendered.width) \(rendered.height) \(scene.width) \(scene.height)".write(
    to: out.appendingPathComponent("size.txt"), atomically: true, encoding: .utf8)
print("dumped dos \(rendered.width)x\(rendered.height) and mac \(scene.width)x\(scene.height)")
