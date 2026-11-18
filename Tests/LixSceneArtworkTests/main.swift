import CoreGraphics
import Foundation
import ImageIO
@testable import NxlvKit

struct Failure: Error { let message: String }
func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw Failure(message: message) }
}
func rejects(_ label: String, _ body: () throws -> Void) throws {
    do { try body() } catch { return }
    throw Failure(message: "Expected rejection: " + label)
}
func png(_ frame: LixSceneArtwork.Frame, to url: URL) throws {
    let provider = CGDataProvider(data: frame.rgba as CFData)!
    let image = CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8,
        bitsPerPixel: 32, bytesPerRow: frame.width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
        decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    try check(CGImageDestinationFinalize(destination), "Write scene capture")
}
func colour(_ frame: LixSceneArtwork.Frame, _ x: Int, _ y: Int) -> [UInt8] {
    guard (0..<frame.width).contains(x), (0..<frame.height).contains(y) else { return [] }
    let offset = (y * frame.width + x) * 4
    return Array(frame.rgba[offset..<(offset + 4)])
}
func bare(_ scene: ClassicRenderedLevel, steel: Data? = nil) -> ClassicRenderedLevel {
    ClassicRenderedLevel(width: scene.width, height: scene.height, rgba: scene.rgba,
        solidMask: scene.solidMask, steelMask: steel ?? scene.steelMask,
        entrances: scene.entrances, triggers: [], objects: [])
}

let pack = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
do {
    let art = try LixSceneArtwork(directory: pack)
    try check(art.hatches[.brick]!.rows[0].count == 7, "Brick hatch uses seven authored frames")
    try check(art.goals[.brick]!.rows[0].count == 6, "Brick exit uses six authored frames")
    try check(art.hatches[.earth]!.first.height == 56, "Earth hatch keeps its native height")
    try check(art.water.rows[0].count == 8 && art.water.first.width == 48, "Water grid removes its separators")
    try check(art.fire.rows[0].count == 6 && art.fire.first.width == 40, "Fire grid removes its separators")
    try check(art.trap.rows.map(\.count) == [8, 10], "Trap keeps eight idle and ten triggered frames")
    try check(art.hatches[.brick]!.trigger == .init(x: 32, y: 46, width: 0, height: 0), "Hatch sidecar anchor")
    try check(art.goals[.earth]!.trigger == .init(x: 26, y: 56, width: 12, height: 12), "Exit sidecar anchor")
    for gadget in Array(art.hatches.values) + Array(art.goals.values) + [art.water, art.fire, art.trap] {
        for row in gadget.rows { for frame in row {
            for offset in stride(from: 0, to: frame.rgba.count, by: 4) where frame.rgba[offset + 3] != 0 {
                let rgb = Array(frame.rgba[offset..<(offset + 3)])
                try check(rgb != [255, 0, 255], "Magenta is transparent")
                try check(rgb != [128, 0, 128] && rgb != [110, 80, 110], "Grid colours stay outside frames")
            }
        } }
    }
    let hatch = try Data(contentsOf: pack.appendingPathComponent("assets/images/matt/bricks/Hatch.H.png"))
    try rejects("malformed PNG") { _ = try LixSceneArtwork.decode(Data([1, 2, 3])) }
    try rejects("unbounded crop") {
        _ = try art.steel.crop(x: Int.max, y: 0, width: 1, height: 1)
    }
    for text in ["#TRIGGER_AREA_SIZE_X 99999999999999999999", "#HATCH_OPENING_FRAME -1",
                 "#TRIGGER_AREA_POSITION_FROM_CENTER_Y", String(repeating: "x", count: 8_193)] {
        try rejects("invalid sidecar") {
            _ = try LixSceneArtwork.decodeGadget(hatch, kind: .hatch, definition: Data(text.utf8))
        }
    }
    let linked = output.appendingPathComponent("linked-pack")
    try? FileManager.default.removeItem(at: linked)
    try FileManager.default.createSymbolicLink(at: linked, withDestinationURL: pack)
    try rejects("linked pack root") { _ = try LixSceneArtwork(directory: linked) }
    try FileManager.default.removeItem(at: linked)

    let entries = try OpenStarterContent.makeDataSet().campaign.levels
    let themes: [LixSceneArtwork.Theme] = [.brick, .earth, .wood]
    var timings: [Double] = []
    for (index, entry) in entries.enumerated() {
        let scene = try ClassicLevelRenderer.render(entry.level, groundSet: OpenStarterContent.makeGroundSet())
        var game = try ClassicDOSSimulation(level: entry.level, renderedLevel: scene)
        let before = game
        let initial = art.frame(scene, simulation: game, theme: themes[index])
        try check(game == before, "Scene rendering cannot change the simulation")
        try check(initial.width == scene.width * 2 && initial.height == scene.height * 2,
                  "Native frame uses twice the semantic coordinates")
        let sampled = art.frame(scene, simulation: game, theme: themes[index], pixelScale: 1)
        for y in stride(from: 0, to: scene.height, by: 7) { for x in stride(from: 0, to: scene.width, by: 7) {
            try check(colour(sampled, x, y) == colour(initial, x * 2, y * 2), "Deterministic 1× sampling")
        } }
        try check(ClassicSceneFrame.rgba(scene, simulation: game, lixArtwork: art, lixTheme: themes[index]) == sampled.rgba,
                  "Classic 1× seam matches the shared renderer")
        let emptyObjects = bare(scene)
        var steel = [UInt8](scene.steelMask)
        let floor = entry.level.terrain[0].y
        steel[floor * scene.width + 24] = 1
        steel[10 * scene.width + 10] = 1
        let terrainScene = bare(emptyObjects, steel: Data(steel))
        var changed = try ClassicDOSTerrain(renderedLevel: terrainScene)
        try check(changed.removeSolid(x: 5, y: floor), "Remove a terrain pixel")
        try check(changed.addSolid(x: 12, y: floor - 4), "Add a construction pixel")
        let changedGame = try ClassicDOSSimulation(terrain: changed, configuration: game.configuration)
        let changedBefore = changedGame
        let terrainFrame = art.frame(terrainScene, simulation: changedGame, theme: themes[index])
        try check(changedGame == changedBefore, "Terrain and steel masks stay unchanged")
        let mask = changed.solidMask
        for y in 0..<scene.height { for x in 0..<scene.width {
            for dy in 0..<2 { for dx in 0..<2 {
                let alpha = colour(terrainFrame, x * 2 + dx, y * 2 + dy)[3]
                try check(alpha == (mask[y * scene.width + x] == 0 ? 0 : 255), "Source art cannot alter collision geometry")
            } }
        } }
        try check(colour(terrainFrame, 20, 20)[3] == 0, "Empty protected pixels stay empty")
        let sourceOffset = ((floor * 2 % art.steel.height) * art.steel.width + 48 % art.steel.width) * 4
        try check(colour(terrainFrame, 48, floor * 2) == Array(art.steel.rgba[sourceOffset..<(sourceOffset + 4)]),
                  "Steel samples the actual Lix steel tile")
        let hatch = art.hatches[themes[index]]!
        let spawn = game.configuration.entrances[0]
        let originX = spawn.x * 2 - hatch.trigger.centreX
        let originY = spawn.y * 2 - hatch.trigger.centreY
        let source = hatch.first
        let witness = stride(from: 0, to: source.rgba.count, by: 4).first {
            source.rgba[$0 + 3] != 0 && originY + $0 / 4 / source.width >= 0
        }!
        let witnessX = witness / 4 % source.width, witnessY = witness / 4 / source.width
        try check(colour(initial, originX + witnessX, originY + witnessY)
            == Array(source.rgba[witness..<(witness + 4)]), "Hatch artwork aligns to the actual spawn foot")
        let goal = art.goals[themes[index]]!
        let exitBounds = game.configuration.triggers.first { $0.effect == .exit }!.bounds
        let exitX = (exitBounds.x1 + (exitBounds.x2 - exitBounds.x1) / 2) * 2 - goal.trigger.centreX
        let exitY = (exitBounds.y1 + (exitBounds.y2 - exitBounds.y1) / 2) * 2 - goal.trigger.centreY
        let exitWitness = stride(from: 0, to: goal.first.rgba.count, by: 4).first { goal.first.rgba[$0 + 3] != 0 }!
        try check(colour(initial, exitX + exitWitness / 4 % goal.first.width,
            exitY + exitWitness / 4 / goal.first.width) == Array(goal.first.rgba[exitWitness..<(exitWitness + 4)]),
            "Exit artwork aligns to the actual trigger centre")
        for _ in 0..<42 { _ = game.tick() }
        let opened = art.frame(scene, simulation: game, theme: themes[index])
        try check(opened.rgba != initial.rgba, "Hatch and exit animation advances")
        try png(opened, to: output.appendingPathComponent("starter-\(index + 1)-\(themes[index].rawValue).png"))
        let start = Date.timeIntervalSinceReferenceDate
        for _ in 0..<3 { _ = art.frame(scene, simulation: game, theme: themes[index]) }
        timings.append((Date.timeIntervalSinceReferenceDate - start) / 3)
    }
    let fixtureWidth = 352, fixtureHeight = 160
    let draw = ClassicDrawProperties(isUpsideDown: false, noOverwrite: true, onlyOverwrite: false, isErase: false)
    let effects: [ClassicDOSObjectEffect] = [.water, .fire, .triggeredTrap, .exit]
    let bounds = [ClassicDOSRect(x1: 40, y1: 100, x2: 88, y2: 116),
                  .init(x1: 128, y1: 120, x2: 144, y2: 140),
                  .init(x1: 208, y1: 122, x2: 216, y2: 130),
                  .init(x1: 272, y1: 122, x2: 288, y2: 138)]
    let objects = effects.enumerated().map { index, effect -> ClassicRenderedObject in
        let graphic = ClassicObjectGraphic(id: index + 2, width: 1, height: 1,
            frames: Array(repeating: Data([0]), count: 10), animationType: .triggered,
            firstFrameIndex: 0, triggerLeft: 0, triggerTop: 0, triggerWidth: 1,
            triggerHeight: 1, triggerEffect: effect.rawValue, trapSoundEffect: 0)
        return ClassicRenderedObject(placement: .init(slot: index, x: bounds[index].x1, y: bounds[index].y1,
            id: index + 2, draw: draw), graphic: graphic,
            rgbaFrames: Array(repeating: Data([255, 0, 255, 255]), count: 10))
    }
    var fixtureSolid = [UInt8](repeating: 0, count: fixtureWidth * fixtureHeight)
    for y in 130..<146 { for x in 0..<fixtureWidth { fixtureSolid[y * fixtureWidth + x] = 1 } }
    let zones = effects.enumerated().map { index, effect in
        ClassicTriggerZone(effect: effect.rawValue, x1: bounds[index].x1, y1: bounds[index].y1,
            x2: bounds[index].x2, y2: bounds[index].y2)
    }
    let fixture = ClassicRenderedLevel(width: fixtureWidth, height: fixtureHeight,
        rgba: Data(repeating: 0, count: fixtureWidth * fixtureHeight * 4), solidMask: Data(fixtureSolid),
        steelMask: Data(repeating: 0, count: fixtureSolid.count), entrances: [], triggers: zones, objects: objects)
    let configuration = ClassicDOSConfiguration(totalLemmings: 1, requiredToSave: 1,
        timeLimitTicks: nil, initialReleaseRate: 99, entrances: [.init(x: 212, y: 112)],
        triggers: effects.enumerated().map { ClassicDOSTrigger(id: $0.offset, effect: $0.element,
            bounds: bounds[$0.offset], trapResetTicks: 10) }, maximumX: fixtureWidth - 1, maximumY: fixtureHeight - 1)
    var hazardGame = try ClassicDOSSimulation(terrain: .init(renderedLevel: fixture), configuration: configuration)
    let idleHazards = art.frame(fixture, simulation: hazardGame)
    for _ in 0..<150 {
        _ = hazardGame.tick()
        if hazardGame.objectCooldown(at: 2) > 0 { break }
    }
    try check(hazardGame.objectCooldown(at: 2) > 0, "A real trigger starts the trap animation")
    let activeHazards = art.frame(fixture, simulation: hazardGame)
    let crop = { (frame: LixSceneArtwork.Frame) -> Data in
        var bytes = Data()
        for y in 186..<260 {
            let start = (y * frame.width + 400) * 4
            bytes.append(frame.rgba[start..<(start + 48 * 4)])
        }
        return bytes
    }
    try check(crop(idleHazards) != crop(activeHazards), "Triggered trap uses the active source row")
    try check(colour(activeHazards, 100, 250)[3] == 255, "Water uses its source body below the wave")
    try check(colour(activeHazards, 100, 298)[3] == 0, "Water stops above the cavity beneath its floor")
    try png(idleHazards, to: output.appendingPathComponent("hazards-idle.png"))
    try png(activeHazards, to: output.appendingPathComponent("hazards-active.png"))
    let first = try ClassicLevelRenderer.render(entries[0].level, groundSet: OpenStarterContent.makeGroundSet())
    let firstGame = try ClassicDOSSimulation(level: entries[0].level, renderedLevel: first)
    let originalHatch = first.objects.first { $0.placement.id == 1 }!
    let unusedHatches = (0..<4).map { index in
        ClassicRenderedObject(placement: .init(slot: 20 + index, x: 400 + index * 64, y: 60, id: 1, draw: draw),
            graphic: originalHatch.graphic, rgbaFrames: originalHatch.rgbaFrames)
    }
    let extraHatches = ClassicRenderedLevel(width: first.width, height: first.height, rgba: first.rgba,
        solidMask: first.solidMask, steelMask: first.steelMask, entrances: first.entrances,
        triggers: first.triggers, objects: first.objects + unusedHatches)
    let extraFrame = art.frame(extraHatches, simulation: firstGame)
    let closedHatch = art.hatches[.brick]!.first
    let closedWitness = stride(from: 0, to: closedHatch.rgba.count, by: 4).first { closedHatch.rgba[$0 + 3] != 0 }!
    let lastHatch = unusedHatches.last!.placement
    let lastX = (lastHatch.x + 24) * 2 - art.hatches[.brick]!.trigger.centreX
    let lastY = (lastHatch.y + 14) * 2 - art.hatches[.brick]!.trigger.centreY
    try check(colour(extraFrame, lastX + closedWitness / 4 % closedHatch.width,
        lastY + closedWitness / 4 / closedHatch.width)
        == Array(closedHatch.rgba[closedWitness..<(closedWitness + 4)]), "Unused fifth hatch uses closed Lix pixels")
    try check(firstGame.configuration.entrances.count == 1, "Visual hatches cannot add spawn entries")
    let invalid = ClassicRenderedLevel(width: Int.max, height: 1, rgba: Data(), solidMask: Data(),
        steelMask: Data(), entrances: [], triggers: [], objects: [])
    let fallback = art.frame(invalid, simulation: firstGame)
    try check(fallback.width == 1 && fallback.height == 1 && fallback.rgba.count == 4, "Invalid input keeps frame dimensions consistent")
    try check(Set(themes.map { art.frame(first, simulation: firstGame, theme: $0).rgba }).count == 3,
              "Starter themes use distinct real artwork")
    print("PASS source grids, transparency, sidecars, rejection bounds, themes, 1×/2× pixels, spawn anchors and mask geometry")
    print("Sample scene seconds per frame (unoptimised test core): \(timings)")
} catch { print("FAIL \(error)"); exit(1) }
