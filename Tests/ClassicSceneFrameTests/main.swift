import Foundation
import NxlvKit

struct Failure: Error { let message: String }
func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw Failure(message: message) }
}
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
do {
    let level = try ClassicCampaignDefinition.originalDOSLemmings.load(from: directory).levels[0].level
    let ground = try ClassicGroundSet.load(style: level.groundStyle, from: directory)
    let scene = try ClassicLevelRenderer.render(level, groundSet: ground)
    let assets = try ClassicMainDATAssets.load(from: directory)
    var sim = try ClassicDOSSimulation(level: level, renderedLevel: scene, mainDATAssets: assets)
    let closed = ClassicSceneFrame.rgba(scene, simulation: sim)
    for _ in 0..<148 { sim.tick() }
    let open = ClassicSceneFrame.rgba(scene, simulation: sim)
    for id in [0, 1] {
        let object = scene.objects.first { $0.placement.id == id }!
        var visible = 0
        for y in max(0,object.placement.y)..<min(scene.height,object.placement.y + object.graphic.height) {
            for x in max(0,object.placement.x)..<min(scene.width,object.placement.x + object.graphic.width) {
                let offset = (y * scene.width + x) * 4
                if open[offset..<offset+4] != scene.rgba[offset..<offset+4] { visible += 1 }
            }
        }
        try check(visible > 0, "Object \(id) has no visible pixels")
    }
    try check(closed != open, "Object animation never changes")
    try check(sim.assign(.digger, to: 0) == .assigned, "Could not start digger")
    for _ in 0..<30 { sim.tick() }
    let dug = ClassicSceneFrame.rgba(scene, simulation: sim)
    let original = scene.solidMask, current = sim.terrain.solidMask
    let removed = original.indices.filter { original[$0] != 0 && current[$0] == 0 }
    try check(!removed.isEmpty, "Digger removed no terrain")
    try check(removed.contains { dug[$0 * 4 + 3] == 0 }, "Removed terrain remains visible")
    var history = ClassicDOSRewind(simulation: sim)
    let before = ClassicSceneFrame.rgba(scene, simulation: history.simulation)
    for _ in 0..<10 { _ = history.tick() }
    _ = history.rewind(seconds: 10.0 / Double(ClassicDOSRules.ticksPerSecond))
    try check(ClassicSceneFrame.rgba(scene, simulation: history.simulation) == before, "Rewind did not restore the frame")
    print("PASS visible entrance and exit, animated objects, digging, and frame restoration after rewind")
} catch { print("FAIL \(error)"); exit(1) }
