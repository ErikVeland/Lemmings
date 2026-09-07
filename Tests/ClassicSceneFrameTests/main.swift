import Foundation
@testable import NxlvKit

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
    let blue: [UInt8] = [32, 64, 192, 255]
    let surface = [UInt8](repeating: 0, count: 8) + blue + blue
    var liquidPixels = [UInt8](repeating: 0, count: 4 * 6 * 4)
    var liquidMask = [UInt8](repeating: 0, count: 4 * 6)
    liquidMask[4 * 4 + 1] = 1
    liquidPixels[(4 * 4 + 1) * 4] = 200
    liquidPixels[(4 * 4 + 1) * 4 + 3] = 255
    ClassicLiquidFill.draw(source: surface, sourceWidth: 2, sourceHeight: 2,
        x: 1, y: 0, into: &liquidPixels, width: 4, height: 6, solid: liquidMask, scale: 1)
    try check(Array(liquidPixels[(3 * 4 + 1) * 4..<(3 * 4 + 1) * 4 + 4]) == blue,
        "Liquid did not extend in its own colour")
    try check(liquidPixels[(4 * 4 + 1) * 4] == 200, "Liquid covered its floor")
    try check(liquidPixels[(5 * 4 + 1) * 4 + 3] == 0, "Liquid leaked below its floor")
    try check(liquidPixels[(5 * 4 + 2) * 4 + 3] == 255, "Open liquid did not reach the level bottom")
    try check(liquidPixels[(5 * 4) * 4 + 3] == 0, "Liquid extended beyond the tile width")
    var covered = [UInt8](repeating: 0, count: 4 * 6 * 4)
    liquidMask[1 * 4 + 1] = 1
    ClassicLiquidFill.draw(source: surface, sourceWidth: 2, sourceHeight: 2,
        x: 1, y: 0, into: &covered, width: 4, height: 6, solid: liquidMask, scale: 1)
    try check(covered[(2 * 4 + 1) * 4 + 3] == 0, "Liquid leaked through terrain covering the source tile")
    print("PASS liquid colour, bounds, open depth, and terrain floors")
    print("PASS visible entrance and exit, animated objects, digging, and frame restoration after rewind")
} catch { print("FAIL \(error)"); exit(1) }
