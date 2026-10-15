#if os(macOS)
import AppKit
import NxlvKit
import XCTest
@testable import LemmingsLocal

final class CursorCameraTests: XCTestCase {
    func testAnchoredZoomCanReachEveryLevelEdgeAtEachEngineScale() {
        for aspect in [1.0, 1.2] {
            let field = CGRect(x: 20, y: 36, width: 960, height: 480 * aspect)
            for anchor in [field.origin, CGPoint(x: field.midX, y: field.midY),
                           CGPoint(x: field.maxX - 1, y: field.maxY - 1)] {
                for magnification in [1.25, 1.5, 2.0] {
                    var lens = AnimatedPrecisionZoomLens()
                    _ = lens.transition(toMagnification: magnification, at: anchor, scaleX: 3, scaleY: 3 * aspect)
                    let level = CGRect(x: 0, y: 0, width: 640, height: 160)
                    let first = lens.source(field.origin)
                    let last = lens.source(CGPoint(x: field.maxX, y: field.maxY))
                    let top = lens.clampedCamera(CGPoint(x: -10_000, y: -10_000),
                        playfield: field, scaleX: 3, scaleY: 3 * aspect, level: level)
                    let bottom = lens.clampedCamera(CGPoint(x: 10_000, y: 10_000),
                        playfield: field, scaleX: 3, scaleY: 3 * aspect, level: level)
                    XCTAssertEqual(top.x + (first.x - field.minX) / 3, 0, accuracy: 0.0001)
                    XCTAssertEqual(top.y + (first.y - field.minY) / (3 * aspect), 0, accuracy: 0.0001)
                    XCTAssertEqual(bottom.x + (last.x - field.minX) / 3, 640, accuracy: 0.0001)
                    XCTAssertEqual(bottom.y + (last.y - field.minY) / (3 * aspect), 160, accuracy: 0.0001)
                }
            }
        }
    }

    @MainActor func testClassicRenderedZoomScrollsVerticallyAndKeepsPointerAtInput() throws {
        _ = NSApplication.shared
        let field = PlayfieldView(frame: CGRect(x: 0, y: 0, width: 960, height: 480))
        field.reduceMotion = true
        field.viewport = Viewport(scrollX: 100, zoom: 3,
            levelSize: CGSize(width: 640, height: 160), viewSize: field.bounds.size)
        let pixels = try XCTUnwrap(CGContext(data: nil, width: 640, height: 160,
            bitsPerComponent: 8, bytesPerRow: 640 * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        for y in 0..<160 {
            pixels.setFillColor(CGColor(srgbRed: CGFloat(y) / 160, green: 0.5, blue: 0.2, alpha: 1))
            pixels.fill(CGRect(x: 0, y: y, width: 640, height: 1))
        }
        field.levelImage = try XCTUnwrap(pixels.makeImage())
        field.setPrecisionZoom(true, at: CGPoint(x: 480, y: 240))
        let output = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/cursor-camera-captures")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var images: [Data] = []
        for (name, pointer, delta) in [
            ("top", CGPoint(x: 480, y: 1), -10_000.0),
            ("bottom", CGPoint(x: 480, y: 479), 10_000.0)
        ] {
            field.handleMove(to: pointer)
            let scroll = try XCTUnwrap(field.edgeScrollVector)
            XCTAssertEqual(scroll.x, 0)
            XCTAssertEqual(scroll.y.sign, delta.sign)
            field.viewport.scroll(dx: 0, dy: delta)
            let visible = field.precisionVisibleLevelRect
            XCTAssertEqual(name == "top" ? visible.minY : visible.maxY,
                name == "top" ? 0 : 160, accuracy: 0.0001)
            let bitmap = try XCTUnwrap(field.bitmapImageRepForCachingDisplay(in: field.bounds))
            field.cacheDisplay(in: field.bounds, to: bitmap)
            let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            images.append(data)
            try data.write(to: output.appendingPathComponent("classic-\(name).png"))
            XCTAssertEqual(field.edgeScrollVector, scroll)
        }
        XCTAssertNotEqual(images[0], images[1])
        field.setPrecisionZoom(false)
        XCTAssertEqual(field.viewport.scrollY, 0)
        XCTAssertEqual(field.viewport.cameraMagnification, 1)
    }
}
#endif
