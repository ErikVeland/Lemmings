#if canImport(CoreGraphics)
import CoreGraphics
import Foundation
import Testing
@testable import LemmingsMobileCore

struct MobileBitmapTests {
    @Test func bitmapCameraMatchesTouchAfterPanZoomAndRotation() throws {
        let width = 640, height = 160
        let red: [UInt8] = [255, 0, 0, 255]
        let green: [UInt8] = [0, 255, 0, 255]
        let blue: [UInt8] = [0, 0, 255, 255]
        var bytes = Data()
        for y in 0..<height {
            for x in 0..<width {
                bytes.append(contentsOf: y < 40 ? red : (x < 320 ? green : blue))
            }
        }
        let frame = try MobilePixelFrame(width: width, height: height, rgba: bytes)
        let image = try #require(MobileBitmapRenderer.image(frame))
        var viewport = MobileViewport(levelSize: MobileSize(width: 640, height: 160),
                                      viewSize: MobileSize(width: 1, height: 1),
                                      origin: MobilePoint(x: 300, y: 0), pixelAspect: 1.2)
        for size in [MobileSize(width: 834, height: 944), MobileSize(width: 1112, height: 650)] {
            viewport.fitGameplay(in: size)
            try check(image, viewport: viewport, red: red, green: green, blue: blue)
            viewport.pan(viewDelta: MobilePoint(x: 90, y: 0))
            viewport.magnify(by: 1.4, around: MobilePoint(x: size.width / 2, y: size.height / 2))
            try check(image, viewport: viewport, red: red, green: green, blue: blue)
            viewport.resize(size)
            try check(image, viewport: viewport, red: red, green: green, blue: blue)
        }
    }

    private func check(_ image: CGImage, viewport: MobileViewport,
                       red: [UInt8], green: [UInt8], blue: [UInt8]) throws {
        let width = Int(viewport.viewSize.width), height = Int(viewport.viewSize.height)
        let context = try #require(CGContext(data: nil, width: width, height: height,
                                            bitsPerComponent: 8, bytesPerRow: width * 4,
                                            space: CGColorSpaceCreateDeviceRGB(),
                                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        MobileBitmapRenderer.draw(image, viewport: viewport, in: context)
        let pixels = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        var coloured = 0
        for y in stride(from: 1, to: height, by: 11) {
            for x in stride(from: 1, to: width, by: 11) {
                let offset = (y * width + x) * 4
                let actual = Array(UnsafeBufferPointer(start: pixels + offset, count: 4))
                let point = MobilePoint(x: Double(x) + 0.5, y: Double(y) + 0.5)
                if !viewport.contentFrame.contains(point) {
                    #expect(actual == [0, 0, 0, 0])
                    continue
                }
                let level = viewport.levelPoint(fromView: point)
                // Avoid a sample exactly on a colour boundary.
                if abs(level.y - 40) < 1 || abs(level.x - 320) < 1 { continue }
                let expected = level.y < 40 ? red : (level.x < 320 ? green : blue)
                #expect(actual == expected)
                coloured += 1
            }
        }
        #expect(coloured > 100)
    }
}
#endif
