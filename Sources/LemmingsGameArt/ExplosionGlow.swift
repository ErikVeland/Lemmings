import CoreGraphics
import Foundation
import NxlvKit

/// The original hot core and HDR mask used by the native playfield.
public enum ExplosionGlow {
    public static func drawSpray(_ burst: PixelExplosion, at tick: Int, origin: CGPoint,
        pixel: CGSize, context: CGContext) {
        guard pixel.width > 0, pixel.height > 0 else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.setShouldAntialias(false)
        for dot in ExplosionPixelSpray.pixels(for: burst, at: tick) {
            context.setFillColor(CGColor(srgbRed: Double(dot.red) / 255,
                green: Double(dot.green) / 255, blue: Double(dot.blue) / 255, alpha: 1))
            context.fill(CGRect(x: floor(origin.x + CGFloat(dot.x - burst.x) * pixel.width),
                y: floor(origin.y + CGFloat(dot.y - burst.y) * pixel.height),
                width: pixel.width, height: pixel.height))
        }
    }
    public struct Flash {
        public let rect: CGRect
        public let strength: Float
        public init(rect: CGRect, strength: Float) { self.rect = rect; self.strength = strength }
    }
    public static func drawCore(at point: CGPoint, pixel: CGSize, phase: Int, context: CGContext) {
        guard (0..<2).contains(phase), pixel.width > 0, pixel.height > 0 else { return }
        let x = floor(point.x / pixel.width) * pixel.width, y = floor(point.y / pixel.height) * pixel.height
        context.saveGState()
        defer { context.restoreGState() }
        context.setFillColor(CGColor(srgbRed: 1, green: 0.32, blue: 0.04, alpha: 1))
        context.fill(CGRect(x: x - 5 * pixel.width, y: y - 2 * pixel.height, width: 10 * pixel.width, height: 4 * pixel.height))
        context.fill(CGRect(x: x - 2 * pixel.width, y: y - 5 * pixel.height, width: 4 * pixel.width, height: 10 * pixel.height))
        context.setFillColor(phase == 0 ? CGColor(gray: 1, alpha: 1) : CGColor(srgbRed: 1, green: 1, blue: 0, alpha: 1))
        context.fill(CGRect(x: x - 3 * pixel.width, y: y - pixel.height, width: 6 * pixel.width, height: 2 * pixel.height))
        context.fill(CGRect(x: x - pixel.width, y: y - 3 * pixel.height, width: 2 * pixel.width, height: 6 * pixel.height))
    }
    public static func textureMask(width: Int, height: Int, flashes: [Flash]) -> [UInt8] {
        guard width > 0, height > 0 else { return [] }
        var bytes = [UInt8](repeating: 0, count: width * height * 2)
        for flash in flashes where flash.strength.isFinite && flash.strength > 0 && !flash.rect.isInfinite && !flash.rect.isNull {
            guard flash.rect.minX.isFinite, flash.rect.minY.isFinite, flash.rect.maxX.isFinite, flash.rect.maxY.isFinite else { continue }
            let rect = flash.rect.intersection(CGRect(x: 0, y: 0, width: width, height: height))
            guard !rect.isEmpty else { continue }
            let value = UInt8((min(1, flash.strength) * 255).rounded())
            for y in max(0, Int(floor(rect.minY)))..<min(height, Int(ceil(rect.maxY))) {
                for x in max(0, Int(floor(rect.minX)))..<min(width, Int(ceil(rect.maxX))) {
                    bytes[(y * width + x) * 2] = max(bytes[(y * width + x) * 2], value)
                }
            }
        }
        return bytes
    }
}
