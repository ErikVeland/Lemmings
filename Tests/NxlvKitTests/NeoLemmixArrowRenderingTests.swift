import Foundation
import CoreGraphics
import ImageIO
import Testing
@testable import NxlvKit

struct NeoLemmixArrowRenderingTests {
    private func fixture(effect: NxlvObjectEffect = .oneWayLeft) throws -> (NxlvRenderedLevel, NeoLemmixTerrain) {
        let width = 32, height = 24
        var solid = [UInt8](repeating: 0, count: width * height)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 4..<20 { for x in 4..<28 {
            solid[y * width + x] = 1
            pixels[(y * width + x) * 4..<(y * width + x) * 4 + 4] = [90, 70, 60, 255]
        } }
        var high = NeoLemmixMacArtwork.doubled(pixels, width: width, height: height)
        // An authored half-cell rim differs from the physics mask.
        for x in 8..<56 { high[(8 * width * 2 + x) * 4 + 3] = 0 }
        let arrow = Array(repeating: [UInt8](arrayLiteral: 64, 64, 255, 255), count: 24 * 16).flatMap { $0 }
        let zero = [UInt8](repeating: 0, count: width * height)
        let rendered = NxlvRenderedLevel(width: width, height: height, rgba: pixels,
            solidMask: solid, steelMask: zero, oneWayMask: solid, oneWayEligibleMask: solid,
            gadgets: [.init(style: "test", piece: "arrows", effect: effect, x: 4, y: 4,
                width: 24, height: 16, triggerX: 4, triggerY: 4, triggerWidth: 24, triggerHeight: 16,
                animationRGBA: [arrow], macAnimationRGBA: [NeoLemmixMacArtwork.doubled(arrow, width: 24, height: 16)])],
            backgroundRGBA: Array(repeating: 0, count: pixels.count), terrainRGBA: pixels,
            macTerrainRGBA: high, foregroundRGBA: Array(repeating: 0, count: pixels.count))
        let terrain = try NeoLemmixTerrain(width: width, height: height,
            solidMask: solid, steelMask: zero, oneWayMask: solid)
        return (rendered, terrain)
    }

    @Test func viewportCompositesMatchFullFramesAtNativeAndMacResolution() throws {
        let (rendered, terrain) = try fixture()
        for mac in [false, true] {
            let scale = mac ? 2 : 1
            let full = NeoLemmixSceneFrame.rgba(rendered, terrain: terrain, useMacArtwork: mac)
            for x in [0, 7, 22] {
                let request = SceneRasterContext.Viewport(levelWidth: rendered.width, levelHeight: rendered.height,
                    x: x, y: 7, width: 8, height: 9)
                SceneRasterContext.request.withValue(request) {
                    let cropped = NeoLemmixSceneFrame.rgba(rendered, terrain: terrain, useMacArtwork: mac)
                    let expected = SceneRasterContext.crop(full, width: rendered.width * scale, height: rendered.height * scale)
                    #expect(cropped == expected)
                }
            }
        }
    }

    @Test func preparedTerrainMatchesFreshSceneAcrossRemovalConstructionAndRewind() throws {
        let (rendered, initial) = try fixture()
        var removed = initial
        removed.setSolid(false, x: 8, y: 8)
        var constructed = removed
        constructed.setSolid(true, x: 2, y: 2)
        for terrain in [initial, removed, constructed, initial] {
            let prepared = NeoLemmixSceneFrame.terrainRGBA(rendered, terrain: terrain)
            for mac in [false, true] {
                let fresh = NeoLemmixSceneFrame.rgba(rendered, terrain: terrain, useMacArtwork: mac)
                #expect(NeoLemmixSceneFrame.rgba(rendered, terrain: terrain, useMacArtwork: mac,
                    preparedTerrainRGBA: prepared) == fresh)
            }
        }
    }

    @Test func removedTerrainClipsLiveArrowsAtBothResolutions() throws {
        for effect in [NxlvObjectEffect.oneWayLeft, .oneWayRight, .oneWayUp, .oneWayDown] {
            let (rendered, initial) = try fixture(effect: effect)
            var terrain = initial
            for y in 4..<10 { for x in 4..<28 { terrain.setSolid(false, x: x, y: y) } }
            for y in 10..<14 { for x in 12..<16 { terrain.setSolid(false, x: x, y: y) } }
            let before = terrain
            for mac in [false, true] {
                let scale = mac ? 2 : 1
                let frame = NeoLemmixSceneFrame.frame(rendered, terrain: terrain, useMacArtwork: mac, includeArrowGlints: true)
                if effect == .oneWayLeft {
                    try capture(frame.rgba, width: rendered.width * scale, height: rendered.height * scale,
                        name: mac ? "mac-dug" : "pc-dug")
                }
                var arrowPixels = 0
                for y in 0..<rendered.height * scale { for x in 0..<rendered.width * scale {
                    let p = (y * rendered.width * scale + x) * 4
                    if terrain.solidMask[(y / scale) * rendered.width + x / scale] == 0 {
                        #expect(frame.rgba[p + 3] == 0, "Arrow escaped live terrain at \(x),\(y)")
                    } else if frame.rgba[p + 2] > frame.rgba[p] { arrowPixels += 1 }
                } }
                #expect(arrowPixels > 0)
                if mac {
                    let glints = try #require(frame.glints)
                    for y in 0..<glints.height { for x in 0..<glints.width
                        where glints.strength[y * glints.width + x] > 0 {
                        #expect(terrain.solidMask[((y + glints.y) / 2) * rendered.width + (x + glints.x) / 2] != 0)
                    } }
                    #expect(frame.rgba == NeoLemmixSceneFrame.rgba(rendered, terrain: terrain, useMacArtwork: true))
                } else { #expect(frame.glints == nil) }
            }
            #expect(terrain == before)
            #expect(NeoLemmixSceneFrame.rgba(rendered, terrain: initial, useMacArtwork: true)
                == NeoLemmixSceneFrame.frame(rendered, terrain: initial, useMacArtwork: true, includeArrowGlints: true).rgba)
        }
    }

    @Test func macArrowsAndGlintsRespectAuthoredSubpixels() throws {
        let (rendered, terrain) = try fixture()
        let result = NeoLemmixSceneFrame.frame(rendered, terrain: terrain, useMacArtwork: true, includeArrowGlints: true)
        try capture(result.rgba, width: rendered.width * 2, height: rendered.height * 2, name: "mac-initial")
        for x in 8..<56 { #expect(result.rgba[(8 * rendered.width * 2 + x) * 4 + 3] == 0) }
        let glints = try #require(result.glints)
        for y in 0..<glints.height { for x in 0..<glints.width where glints.strength[y * glints.width + x] > 0 {
            let p = ((y + glints.y) * rendered.width * 2 + x + glints.x) * 4
            #expect(rendered.macTerrainRGBA[p + 3] != 0)
            #expect(result.rgba[p..<p + 3] != rendered.macTerrainRGBA[p..<p + 3])
        } }
    }
    private func capture(_ rgba: [UInt8], width: Int, height: Int, name: String) throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let output = root.appendingPathComponent(".build/arrow-renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let provider = try #require(CGDataProvider(data: Data(rgba) as CFData))
        let image = try #require(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let target = try #require(CGImageDestinationCreateWithURL(output.appendingPathComponent(name + ".png") as CFURL,
            "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(target, image, nil)
        #expect(CGImageDestinationFinalize(target))
    }

}
