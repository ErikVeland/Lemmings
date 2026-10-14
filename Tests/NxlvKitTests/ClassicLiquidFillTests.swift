import Foundation
import Testing
@testable import NxlvKit
#if canImport(ImageIO)
import ImageIO
import CoreGraphics
#endif

struct ClassicLiquidFillTests {
    @Test(arguments: [1, 2])
    func bridgesMaskLiquidWithoutTruncatingItsTile(scale: Int) {
        let width = 6 * scale, height = 10 * scale
        for colour: [UInt8] in [[32, 64, 192, 255], [192, 48, 0, 255], [48, 160, 48, 255]] {
            var pixels = [UInt8](repeating: 0, count: width * height * 4)
            var solid = [UInt8](repeating: 0, count: 60)
            // Bridge across the surface; one support continues into the body.
            for x in 1...3 { solid[2 * 6 + x] = 1 }
            solid[3 * 6 + 2] = 1
            // A floor at the tile's bottom must seal the cavity below it.
            solid[6 * 6 + 1] = 1
            for y in 0..<height {
                for x in 0..<width where solid[(y / scale) * 6 + x / scale] != 0 {
                    pixels.replaceSubrange((y * width + x) * 4..<(y * width + x) * 4 + 4,
                                           with: [200, 180, 80, 255])
                }
            }
            let original = pixels
            let source = Array(repeating: colour, count: 3 * scale * scale).flatMap { $0 }
            ClassicLiquidFill.draw(source: source, sourceWidth: 3 * scale, sourceHeight: scale,
                x: scale, y: 2 * scale, into: &pixels, width: width, height: height,
                solid: solid, scale: scale, minimumBottom: 7 * scale)
            for y in 3 * scale..<height {
                for x in 0..<width {
                    let offset = (y * width + x) * 4
                    if solid[(y / scale) * 6 + x / scale] != 0 {
                        #expect(pixels[offset..<offset + 4] == original[offset..<offset + 4])
                    } else if x >= scale && x < 4 * scale && !(x < 2 * scale && y >= 7 * scale) {
                        #expect(Array(pixels[offset..<offset + 4]) == colour)
                    } else {
                        #expect(pixels[offset + 3] == 0)
                    }
                }
            }
        }
    }

    @Test func floorBelowTileStillStopsExtension() {
        let colour: [UInt8] = [32, 64, 192, 255]
        var pixels = [UInt8](repeating: 0, count: 8 * 4)
        let solid: [UInt8] = [0, 0, 0, 0, 0, 1, 0, 0]
        ClassicLiquidFill.draw(source: colour, sourceWidth: 1, sourceHeight: 1,
            x: 0, y: 0, into: &pixels, width: 1, height: 8,
            solid: solid, scale: 1, minimumBottom: 3)
        #expect(pixels[4 * 4 + 3] == 255)
        #expect(pixels[6 * 4 + 3] == 0)
    }

    @Test func macLiquidUsesIndividualArtworkPixelsInsteadOfCollisionCells() {
        let colour: [UInt8] = [32, 64, 192, 255]
        var terrain = [UInt8](repeating: 0, count: 4 * 8 * 4)
        // Two different single-pixel edges inside the same low-resolution grid.
        for (x, y) in [(0, 3), (1, 4)] {
            terrain.replaceSubrange((y * 4 + x) * 4..<(y * 4 + x) * 4 + 4,
                                    with: [200, 180, 80, 255])
        }
        var pixels = terrain
        ClassicLiquidFill.draw(source: colour + colour, sourceWidth: 2, sourceHeight: 1,
            x: 0, y: 0, into: &pixels, width: 4, height: 8,
            solid: Array(repeating: 1, count: 8), scale: 2,
            minimumBottom: 2, visualTerrain: Data(terrain))
        #expect(Array(pixels[(2 * 4) * 4..<(2 * 4) * 4 + 4]) == colour)
        #expect(Array(pixels[(3 * 4 + 1) * 4..<(3 * 4 + 1) * 4 + 4]) == colour)
        #expect(pixels[(3 * 4) * 4] == 200)
        #expect(pixels[(4 * 4 + 1) * 4] == 200)
        #expect(pixels[(4 * 4) * 4 + 3] == 0)
        #expect(pixels[(5 * 4 + 1) * 4 + 3] == 0)
    }

    // Optional asset-backed coverage keeps ordinary unit tests independent of owned game data.
    @Test func campaignLiquidTiles() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let path = environment["LEMMINGS_CLASSIC_TEST_DATA"],
              let artworkPath = environment["LEMMINGS_MAC_TEST_ART"] else { return }
        let root = URL(fileURLWithPath: path)
        let assets = try ClassicMainDATAssets.load(from: root)
        let artwork = try ClassicMacArtwork(directory: URL(fileURLWithPath: artworkPath))
        let campaign = try ClassicCampaignDefinition.originalDOSLemmings.load(from: root)
        var styles = Set<Int>()
        var checkedPixels = 0
        var checkedReportedLevel = false
        for entry in campaign.levels {
            let ground = try ClassicGroundSet.load(style: entry.level.groundStyle, from: root)
            guard entry.level.objects.contains(where: {
                ground.objects[$0.id]?.triggerEffect == ClassicDOSObjectEffect.water.rawValue
            }) else { continue }
            let scene = try ClassicLevelRenderer.render(entry.level, groundSet: ground)
            let water = scene.objects.filter {
                $0.graphic.triggerEffect == ClassicDOSObjectEffect.water.rawValue
                    && !$0.placement.draw.isUpsideDown && !$0.placement.draw.onlyOverwrite
            }
            guard !water.isEmpty else { continue }
            let simulation = try ClassicDOSSimulation(level: entry.level, renderedLevel: scene, mainDATAssets: assets)
            let mac = try ClassicMacScene(level: entry.level, rendered: scene, artwork: artwork, groundSet: ground)
            let rgba = mac.rgba(simulation: simulation)
            for object in water {
                let sequence = try #require(artwork.objects[entry.level.groundStyle]?[object.placement.id])
                let frame = try #require(artwork.frame(1600 + entry.level.groundStyle, sequence.base + sequence.first))
                // Wave pixels must also fit the Macintosh terrain, even inside solid DOS cells.
                for y in 0..<frame.height {
                    for x in 0..<frame.width where frame.rgba[(y * frame.width + x) * 4 + 3] != 0 {
                        let targetX = object.placement.x * 2 + frame.x + x
                        let targetY = object.placement.y * 2 + frame.y + y
                        guard (0..<mac.width).contains(targetX), (0..<mac.height).contains(targetY) else { continue }
                        let index = targetY * mac.width + targetX
                        guard mac.terrainRGBA[index * 4 + 3] == 0 else { continue }
                        #expect(rgba[index * 4 + 3] != 0,
                            "Missing wave: \(entry.level.title), pixel \(targetX),\(targetY)")
                    }
                }
                let bottom = try #require((0..<frame.height).last { y in
                    (0..<frame.width).contains { frame.rgba[(y * frame.width + $0) * 4 + 3] == 255 }
                })
                let left = max(0, object.placement.x * 2 + frame.x)
                let right = min(mac.width, object.placement.x * 2 + frame.x + frame.width)
                let top = max(0, object.placement.y * 2 + frame.y + bottom + 1)
                let end = min(mac.height, (object.placement.y + object.graphic.height) * 2)
                guard left < right, top < end else { continue }
                styles.insert(entry.level.groundStyle)
                for y in top..<end {
                    for x in left..<right {
                        let index = y * mac.width + x
                        guard mac.terrainRGBA[index * 4 + 3] == 0 else { continue }
                        #expect(rgba[index * 4 + 3] != 0,
                            "Missing liquid: \(entry.level.title), style \(entry.level.groundStyle), pixel \(x),\(y)")
                        checkedPixels += 1
                    }
                }
            }
            if entry.level.title.lowercased().contains("live and lem") {
                checkedReportedLevel = true
                #if canImport(ImageIO)
                if let output = environment["LEMMINGS_LIQUID_RENDER_OUTPUT"] {
                    let provider = try #require(CGDataProvider(data: rgba as CFData))
                    let image = try #require(CGImage(width: mac.width, height: mac.height,
                        bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: mac.width * 4,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
                    let url = URL(fileURLWithPath: output)
                    let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL,
                        "public.png" as CFString, 1, nil))
                    CGImageDestinationAddImage(destination, image, nil)
                    #expect(CGImageDestinationFinalize(destination))
                }
                #endif
            }
        }
        #expect(checkedReportedLevel)
        #expect(styles.contains(4), "Crystal-style liquid must be covered")
        #expect(checkedPixels > 0)
        print("Verified \(checkedPixels) liquid-body pixels across styles \(styles.sorted())")
    }
}
