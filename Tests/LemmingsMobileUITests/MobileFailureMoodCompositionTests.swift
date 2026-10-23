#if os(iOS) || os(tvOS)
import CoreGraphics
import Foundation
import Testing
import UIKit
import LemmingsMobileCore
@testable import LemmingsMobileUI

@MainActor struct MobileFailureMoodCompositionTests {
    /// Capture the real layer tree. A single CGContext misses blends against a transparent sibling.
    private func capture(_ view: UIView) throws -> [UInt8] {
        view.layoutIfNeeded()
        func display(_ layer: CALayer) {
            layer.displayIfNeeded()
            for child in layer.sublayers ?? [] where !child.isHidden { display(child) }
        }
        display(view.layer)
        let width = Int(view.bounds.width), height = Int(view.bounds.height)
        let context = try #require(CGContext(data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        view.layer.render(in: context)
        let pixels = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        return Array(UnsafeBufferPointer(start: pixels, count: width * height * 4))
    }

    @Test func flatFuneralBlendsWithScenePixelsAndRecoversWithoutChangingInput() throws {
        var pixels = Data()
        let colors: [[UInt8]] = [[0, 0, 0, 255], [128, 128, 128, 255],
                                  [0, 204, 0, 255], [204, 0, 0, 255]]
        for _ in 0..<32 {
            for x in 0..<64 { pixels.append(contentsOf: colors[x / 16]) }
        }
        let frame = try MobilePixelFrame(width: 64, height: 32, rgba: pixels)
        for size in [CGSize(width: 320, height: 160), CGSize(width: 320, height: 240),
                     CGSize(width: 1920, height: 1080)] {
            let view = MobilePlayfieldView(viewport: .init(levelSize: .init(width: 64, height: 32),
                viewSize: .init(width: size.width, height: size.height)), automaticallyFitsViewport: false)
            view.frame = CGRect(origin: .zero, size: size)
            view.displaySettings.display = .flat
            view.displaySettings.reduceMotion = true
            view.displaySettings.hdEffectsEnabled = false
            try view.update(frame: frame)
            let normal = try capture(view)
            let viewport = view.gameViewport
            let target = CGPoint(x: size.width / 2, y: size.height / 2)
            let originalTarget = view.hitTest(target, with: nil)
            view.failed = true
            let funeral = try capture(view)
            func pixel(_ data: [UInt8], _ patch: Int) -> [Int] {
                let point = viewport.viewPoint(fromLevel: .init(x: Double(patch * 16 + 8), y: 16))
                let offset = (Int(point.y) * Int(size.width) + Int(point.x)) * 4
                return data[offset..<offset + 3].map(Int.init)
            }
            #expect(pixel(funeral, 0) == [0, 0, 0], "Funeral must preserve black in the composited view")
            #expect(pixel(funeral, 1)[0] < pixel(normal, 1)[0])
            for patch in [2, 3] {
                let before = pixel(normal, patch), after = pixel(funeral, patch)
                #expect(after.max()! - after.min()! < before.max()! - before.min()!)
            }
            #expect(view.gameViewport == viewport)
            #expect(view.hitTest(target, with: nil) === originalTarget)
            view.failed = false
            #expect(try capture(view) == normal, "Recovery must restore the original layer output exactly")
        }
    }
}
#endif
