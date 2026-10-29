import CoreGraphics
import Foundation
import ImageIO
import LemmingsMobileCore
import NxlvKit

/**
 * Renders supported NeoLemmix scene layers, live terrain and native actor art.
 */
final class NeoLemmixMobileSceneRenderer {
    private let renderedLevel: NxlvRenderedLevel
    private let sprites: NeoLemmixMobileSpriteSet
    private var highlightFrames: [String: MobilePixelFrame] = [:]
    private let ghostCache = MobileGhostSpriteCache()
    private let terrainLease = RuntimePixelCacheLease()
    private var cachedTerrain: NeoLemmixTerrain?
    private var cachedTerrainRGBA: [UInt8]?
    private let stonerRGBA: [UInt8]
    private let stonerWidth: Int
    private let stonerHeight: Int

    init(renderedLevel: NxlvRenderedLevel, sprites: NeoLemmixMobileSpriteSet, stylesRootURL: URL) {
        self.renderedLevel = renderedLevel
        self.sprites = sprites
        let stonerURL = stylesRootURL.deletingLastPathComponent().appendingPathComponent("gfx/mask/stoner.png")
        if let source = CGImageSourceCreateWithURL(stonerURL as CFURL, nil),
           let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
           let data = Self.rgba(image) {
            stonerRGBA = data
            stonerWidth = image.width
            stonerHeight = image.height
        } else {
            stonerRGBA = []
            stonerWidth = 0
            stonerHeight = 0
        }
    }

    func render(_ simulation: NeoLemmixSimulation, highlight: MobileTargetSelection?) throws -> MobilePixelFrame {
        try render(simulation, highlight: highlight, ghosts: [])
    }

    func render(_ simulation: NeoLemmixSimulation, highlight: MobileTargetSelection?,
                ghosts: [MobileReplayGhost<NeoLemmixSimulation>]) throws -> MobilePixelFrame {
        let configuration = simulation.configuration
        let state = simulation.snapshot()
        // Keep one small native terrain image. Huge imports use the uncached
        // conversion so the cache cannot retain another large terrain branch.
        if terrainLease.reserve(bytes: renderedLevel.width * renderedLevel.height * 4) {
            if cachedTerrain != simulation.terrain || cachedTerrainRGBA == nil {
                cachedTerrainRGBA = NeoLemmixSceneFrame.terrainRGBA(renderedLevel, terrain: simulation.terrain,
                    stonerRGBA: stonerRGBA, stonerWidth: stonerWidth, stonerHeight: stonerHeight)
                cachedTerrain = simulation.terrain
            }
        } else { cachedTerrain = nil; cachedTerrainRGBA = nil }
        var pixels = NeoLemmixSceneFrame.rgba(
            renderedLevel,
            terrain: simulation.terrain,
            stonerRGBA: stonerRGBA,
            stonerWidth: stonerWidth,
            stonerHeight: stonerHeight,
            zones: configuration.zones,
            disabledZoneIDs: state.disabledZoneIDs,
            gadgetAnimationFrames: state.gadgetAnimationFrames,
            secondaryAnimationStates: state.secondaryAnimationStates,
            tickCount: state.tickCount,
            entranceOpenTick: configuration.entranceOpenTick,
            splitterDirections: state.splitterDirections,
            preparedTerrainRGBA: cachedTerrainRGBA
        )
        let width = renderedLevel.width
        let height = renderedLevel.height
        guard pixels.count == SceneRasterContext.region(width: width, height: height).byteCount else { throw MobileSessionError.invalidFrame }
        for ghost in ghosts where SceneRasterContext.drawActors.wrappedValue {
            for lemming in ghost.state.lemmings where lemming.action != .removed {
                guard let sprite = spriteHighlight(ghost.state, actor: lemming.id) else { continue }
                guard let frame = ghostCache.ghost(key: sprite.cacheKey, colour: ghost.colour, sprite: {
                    (Array(sprite.frame.rgba), sprite.frame.width, sprite.frame.height)
                }) else { continue }
                MobileGhostSpriteCache.blend(frame, atX: Int(sprite.rect.x), y: Int(sprite.rect.y),
                    into: &pixels, width: width, height: height)
            }
        }
        let ordered = NeoLemmixRenderOrder.sorted(state.lemmings,
            selectedID: nil, highlightedID: highlight?.id)
        var crowd = MobileCrowdShadow()
        for lemming in ordered where lemming.action != .removed && SceneRasterContext.drawActors.wrappedValue {
            guard let frame = sprites.frame(action: lemming.action, direction: lemming.direction,
                animationFrame: lemming.animationFrame, traits: lemming.traits) else { continue }
            if lemming.action != .exploding {
                pixels.withUnsafeMutableBytes { destination in
                    crowd.cast(spriteWidth: frame.width, spriteHeight: frame.height,
                        x: lemming.position.x - frame.footX, y: lemming.position.y - frame.footY,
                        width: width, height: height, pixels: destination,
                        opaque: { sx, sy in frame.rgba[(sy * frame.width + sx) * 4 + 3] >= 128 })
                }
            }
            Self.composite(frame, atX: lemming.position.x - frame.footX,
                           y: lemming.position.y - frame.footY,
                           width: width, height: height, into: &pixels)
        }
        if let highlight, let lemming = state.lemmings.first(where: { $0.id == highlight.id && $0.isActive }) {
            Self.drawMarker(x: lemming.position.x, y: lemming.position.y - 12,
                            width: width, height: height, into: &pixels)
        }
        return try MobilePixelFrame(width: width, height: height, rgba: Data(pixels))
    }

    func spriteHighlight(_ simulation: NeoLemmixSimulation, actor: Int) -> MobileSpriteHighlight? {
        guard let lemming = simulation.lemmings.first(where: { $0.id == actor && $0.canReceiveSkills }),
              let frame = sprites.frame(action: lemming.action, direction: lemming.direction,
                animationFrame: lemming.animationFrame, traits: lemming.traits) else { return nil }
        let traits = lemming.traits.map(\.rawValue).sorted().joined(separator: ",")
        let key = "neo-\(lemming.action)-\(lemming.direction)-\(lemming.animationFrame)-\(traits)"
        let pixels: MobilePixelFrame
        if let cached = highlightFrames[key] { pixels = cached }
        else {
            guard let made = try? MobilePixelFrame(width: frame.width, height: frame.height, rgba: Data(frame.rgba)) else { return nil }
            pixels = made
            if highlightFrames.count >= 512 { highlightFrames.removeAll(keepingCapacity: true) }
            highlightFrames[key] = pixels
        }
        return .init(frame: pixels,
            rect: .init(x: Double(lemming.position.x - frame.footX), y: Double(lemming.position.y - frame.footY),
                width: Double(frame.width), height: Double(frame.height)), cacheKey: key, time: nil)
    }

    private static func composite(_ frame: NeoLemmixMobileSpriteFrame, atX x: Int, y: Int,
                                  width: Int, height: Int, into pixels: inout [UInt8]) {
        let rasterRegion = SceneRasterContext.region(width: width, height: height)
        guard rasterRegion.intersects(x: x, y: y, width: frame.width, height: frame.height) else { return }
        for sourceY in 0..<frame.height {
            let targetY = y + sourceY
            guard (0..<height).contains(targetY) else { continue }
            for sourceX in 0..<frame.width {
                let source = (sourceY * frame.width + sourceX) * 4
                let alpha = Int(frame.rgba[source + 3])
                guard alpha > 0 else { continue }
                let targetX = x + sourceX
                guard (0..<width).contains(targetX) else { continue }
                guard let target = rasterRegion.offset(x: targetX, y: targetY) else { continue }
                for channel in 0..<3 {
                    pixels[target + channel] = UInt8((Int(frame.rgba[source + channel]) * alpha
                        + Int(pixels[target + channel]) * (255 - alpha) + 127) / 255)
                }
                pixels[target + 3] = 255
            }
        }
    }

    private static func drawMarker(x: Int, y: Int, width: Int, height: Int, into pixels: inout [UInt8]) {
        let rasterRegion = SceneRasterContext.region(width: width, height: height)
        for offset in -2...2 {
            for point in [(x + offset, y - 2), (x + offset, y + 2), (x - 2, y + offset), (x + 2, y + offset)] {
                guard (0..<width).contains(point.0), (0..<height).contains(point.1) else { continue }
                guard let index = rasterRegion.offset(x: point.0, y: point.1) else { continue }
                pixels[index] = 255; pixels[index + 1] = 220; pixels[index + 2] = 48; pixels[index + 3] = 255
            }
        }
    }

    private static func rgba(_ image: CGImage) -> [UInt8]? {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        guard let context = CGContext(data: &pixels, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Int(pixels[offset + 3])
            guard alpha > 0, alpha < 255 else { continue }
            for channel in 0..<3 {
                pixels[offset + channel] = UInt8(min(255, (Int(pixels[offset + channel]) * 255 + alpha / 2) / alpha))
            }
        }
        return pixels
    }
}
