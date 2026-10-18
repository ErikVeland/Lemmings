import Foundation
import Testing
@testable import NxlvKit

struct MacArrowWrapTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// One-way arrows follow the drawn Mac terrain, not the DOS collision
    /// cells, and keep a bare rim of terrain at each edge.
    @Test func arrowsStayInsideTheDrawnTerrain() throws {
        let directory = root.appendingPathComponent("Sources/Ports/lemmings_dos_1991-07-30")
        let artwork = try ClassicMacArtwork(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings"))
        let campaign = try ClassicDataSet.detect(directory: directory).campaign
        let assets = try ClassicMainDATAssets.load(from: directory)
        let arrowEffects = [ClassicDOSObjectEffect.oneWayLeft.rawValue, ClassicDOSObjectEffect.oneWayRight.rawValue]
        var checked = Set<Int>()
        for entry in campaign.levels where entry.level.specialStyle == 0
            && !checked.contains(entry.level.groundStyle) {
            let level = entry.level
            let ground = try ClassicGroundSet.load(style: level.groundStyle, from: directory)
            let rendered = try ClassicLevelRenderer.render(level, groundSet: ground, specialGraphic: nil)
            guard let arrow = rendered.objects.first(where: { arrowEffects.contains($0.graphic.triggerEffect) })
            else { continue }
            let scene = try ClassicMacScene(level: level, rendered: rendered, artwork: artwork, groundSet: ground)
            let simulation = try ClassicDOSSimulation(level: level, renderedLevel: rendered, mainDATAssets: assets)
            let terrain = [UInt8](scene.terrainFrame(terrain: simulation.terrain))
            let frame = [UInt8](scene.rgba(simulation: simulation))
            var changed = 0
            for y in arrow.placement.y * 2..<min(scene.height, (arrow.placement.y + arrow.graphic.height) * 2) {
                for x in arrow.placement.x * 2..<min(scene.width, (arrow.placement.x + arrow.graphic.width) * 2) {
                    let p = (y * scene.width + x) * 4
                    let edge = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)].contains { nx, ny in
                        (0..<scene.width).contains(nx) && (0..<scene.height).contains(ny)
                            && terrain[(ny * scene.width + nx) * 4 + 3] == 0
                    }
                    if terrain[p + 3] == 0 || edge {
                        #expect(frame[p..<p + 4] == terrain[p..<p + 4], "style \(level.groundStyle) at \(x),\(y)")
                    } else if frame[p..<p + 4] != terrain[p..<p + 4] {
                        changed += 1
                    }
                }
            }
            #expect(changed > 0, "style \(level.groundStyle) drew no arrows")
            checked.insert(level.groundStyle)
        }
        #expect(checked.count >= 3)
    }

    /// HDR glints sit only on lit arrow pixels and leave the SDR frame unchanged.
    /// Monochrome art has no glints.
    @Test func arrowGlintsAddHDRLightWithoutChangingTheFrame() throws {
        let directory = root.appendingPathComponent("Sources/Ports/lemmings_dos_1991-07-30")
        let export = root.appendingPathComponent(".build/mac-artwork/export")
        let colour = try ClassicMacArtwork(directory: export.appendingPathComponent("lemmings"))
        let monochrome = try ClassicMacArtwork(directory: export.appendingPathComponent("monochrome/lemmings"))
        #expect(monochrome.monochrome)
        let campaign = try ClassicDataSet.detect(directory: directory).campaign
        let assets = try ClassicMainDATAssets.load(from: directory)
        let arrowEffects = [ClassicDOSObjectEffect.oneWayLeft.rawValue, ClassicDOSObjectEffect.oneWayRight.rawValue]
        var checked = Set<Int>()
        for entry in campaign.levels where entry.level.specialStyle == 0
            && !checked.contains(entry.level.groundStyle) {
            let level = entry.level
            let ground = try ClassicGroundSet.load(style: level.groundStyle, from: directory)
            let rendered = try ClassicLevelRenderer.render(level, groundSet: ground, specialGraphic: nil)
            guard rendered.objects.contains(where: { arrowEffects.contains($0.graphic.triggerEffect) }) else { continue }
            let simulation = try ClassicDOSSimulation(level: level, renderedLevel: rendered, mainDATAssets: assets)

            let scene = try ClassicMacScene(level: level, rendered: rendered, artwork: colour, groundSet: ground)
            let terrain = [UInt8](scene.terrainFrame(terrain: simulation.terrain))
            let sdr = scene.rgba(simulation: simulation)
            let hdr = scene.rgbaWithArrowGlints(simulation: simulation)
            #expect(hdr.rgba == sdr, "style \(level.groundStyle) changed the SDR frame")
            let glints = try #require(hdr.glints, "style \(level.groundStyle) has no glints")
            #expect(glints.x >= 0 && glints.y >= 0 && glints.width > 0 && glints.height > 0
                && glints.x + glints.width <= scene.width && glints.y + glints.height <= scene.height)
            #expect(glints.strength.count == glints.width * glints.height)
            let frame = [UInt8](sdr), strength = [UInt8](glints.strength)
            var lit = 0
            for gy in 0..<glints.height { for gx in 0..<glints.width where strength[gy * glints.width + gx] > 0 {
                let p = ((glints.y + gy) * scene.width + glints.x + gx) * 4
                // A glint pixel is an arrow pixel: drawn over terrain and changed by the decal.
                #expect(terrain[p + 3] != 0 && frame[p..<p + 3] != terrain[p..<p + 3],
                    "style \(level.groundStyle) glint off the arrow at \(glints.x + gx),\(glints.y + gy)")
                lit += 1
            } }
            #expect(lit > 0)

            let plain = try ClassicMacScene(level: level, rendered: rendered, artwork: monochrome, groundSet: ground)
            #expect(plain.rgbaWithArrowGlints(simulation: simulation).glints == nil)
            #expect(plain.rgbaWithArrowGlints(simulation: simulation).rgba == plain.rgba(simulation: simulation))
            checked.insert(level.groundStyle)
        }
        #expect(checked.count >= 3)
    }
}
