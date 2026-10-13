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
        let configuration = simulation.configuration
        let state = simulation.snapshot()
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
            splitterDirections: state.splitterDirections
        )
        let width = renderedLevel.width
        let height = renderedLevel.height
        guard pixels.count == width * height * 4 else { throw MobileSessionError.invalidFrame }
        let ordered = NeoLemmixRenderOrder.sorted(state.lemmings,
            selectedID: nil, highlightedID: highlight?.id)
        for lemming in ordered where lemming.action != .removed {
            guard let frame = sprites.frame(action: lemming.action, direction: lemming.direction,
                animationFrame: lemming.animationFrame, traits: lemming.traits) else { continue }
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

    private static func composite(_ frame: NeoLemmixMobileSpriteFrame, atX x: Int, y: Int,
                                  width: Int, height: Int, into pixels: inout [UInt8]) {
        for sourceY in 0..<frame.height {
            let targetY = y + sourceY
            guard (0..<height).contains(targetY) else { continue }
            for sourceX in 0..<frame.width {
                let source = (sourceY * frame.width + sourceX) * 4
                let alpha = Int(frame.rgba[source + 3])
                guard alpha > 0 else { continue }
                let targetX = x + sourceX
                guard (0..<width).contains(targetX) else { continue }
                let target = (targetY * width + targetX) * 4
                for channel in 0..<3 {
                    pixels[target + channel] = UInt8((Int(frame.rgba[source + channel]) * alpha
                        + Int(pixels[target + channel]) * (255 - alpha) + 127) / 255)
                }
                pixels[target + 3] = 255
            }
        }
    }

    private static func drawMarker(x: Int, y: Int, width: Int, height: Int, into pixels: inout [UInt8]) {
        for offset in -2...2 {
            for point in [(x + offset, y - 2), (x + offset, y + 2), (x - 2, y + offset), (x + 2, y + offset)] {
                guard (0..<width).contains(point.0), (0..<height).contains(point.1) else { continue }
                let index = (point.1 * width + point.0) * 4
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
