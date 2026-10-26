#if os(macOS)
import AppKit
import ImageIO
import LemmingsAppCore
import LemmingsGameArt
import NxlvKit
import XCTest
@testable import LemmingsLocal

final class LemmingAssessmentRenderingTests: XCTestCase {
    @MainActor func testEntireCatalogueInNarrowInspectionPages() throws {
        _ = NSApplication.shared
        var attributes = [UInt16](repeating: 0, count: 512 * 64)
        for y in 48..<64 { for x in 0..<512 { attributes[y * 512 + x] = 0x20 } }
        let initial = try Lemmings3Runtime(configuration: .init(width: 512, height: 64,
            attributes: attributes, entrance: .init(x: 20, y: 20),
            exits: [.init(x: 480, y: 46)], total: 10, releaseInterval: 1, releaseDelay: 0,
            // L3 releases ten hatch actors; preplaced actors complete the catalogue.
            extras: (0..<118).map { .init(x: 20 + $0, y: 46, direction: 1) }))
        var current = initial
        for _ in 0..<150 { current.step() }
        let snapshot = try LemmingInspection(initial: .lemmings3(initial), current: .lemmings3(current), commands: [])
        XCTAssertEqual(snapshot.individuals.count, 128)
        XCTAssertEqual(Set(snapshot.individuals.map { $0.preference + " " + $0.want }).count, 128)
        let path = TestMenuArtwork.path
        let artworkURL = URL(fileURLWithPath: path)
        let typography = try XCTUnwrap(GameMenuTypography(directory: artworkURL))
        let renderer = MacInterfaceRenderer(interface: try XCTUnwrap(
            ClassicMacUserInterface(artwork: try ClassicMacArtwork(directory: artworkURL))))
        let output = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent(".build/assessment-renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        for index in snapshot.individuals.indices {
            let page = LemmingInspectionArt.page(snapshot, index: index)
            let layout = GameFrontEnd.layout(page, width: 320, minimumHeight: 568)
            let bounds = CGRect(origin: .zero, size: layout.size)
            for target in layout.targets {
                XCTAssertTrue(bounds.contains(target.frame))
                XCTAssertEqual(layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)),
                    target.action.enabled ? target.action.id : nil)
                for detail in layout.details { XCTAssertFalse(detail.intersects(target.frame)) }
            }
            for detail in layout.details { XCTAssertTrue(bounds.contains(detail)) }
            let context = try XCTUnwrap(CGContext(data: nil, width: Int(layout.size.width), height: Int(layout.size.height),
                bitsPerComponent: 8, bytesPerRow: Int(layout.size.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.translateBy(x: 0, y: layout.size.height); context.scaleBy(x: 1, y: -1)
            GameFrontEnd.draw(page, layout: layout, typography: typography, highlighted: "0", in: context)
            let native = GameMenuArtwork.withRenderer(renderer) {
                LemmingInspectionPage(snapshot: snapshot, selectedID: snapshot.individuals[index].id)
            }
            window.contentView = native
            native.layoutSubtreeIfNeeded()
            let navigator = DialogKeyboardNavigation()
            for button in navigator.controls(in: native).compactMap({ $0 as? NSButton }) where button.isEnabled && !button.isHidden {
                let rect = button.convert(button.bounds, to: native)
                XCTAssertTrue(native.bounds.contains(rect))
                let point = native.convert(CGPoint(x: rect.midX, y: rect.midY), to: native.superview)
                XCTAssertTrue(native.hitTest(point) === button, "\(button.title), actor \(index)")
            }
            let bitmap = try XCTUnwrap(native.bitmapImageRepForCachingDisplay(in: native.bounds))
            GameMenuArtwork.withRenderer(renderer) { native.cacheDisplay(in: native.bounds, to: bitmap) }
            let hoverRoot = NSView(frame: CGRect(x: 0, y: 0, width: 640, height: 480))
            let hover = LemmingInspectionHover(frame: .zero)
            GameMenuArtwork.withRenderer(renderer) {
                hover.show(snapshot.individuals[index], in: hoverRoot, area: hoverRoot.bounds,
                    pointer: CGPoint(x: 24, y: 240))
            }
            XCTAssertFalse(hover.isHidden)
            XCTAssertTrue(hoverRoot.bounds.contains(hover.frame))
            XCTAssertNil(hover.hitTest(.zero))
            for label in hover.subviews { XCTAssertTrue(hover.bounds.contains(label.frame)) }
            let hoverBitmap = try XCTUnwrap(hover.bitmapImageRepForCachingDisplay(in: hover.bounds))
            GameMenuArtwork.withRenderer(renderer) { hover.cacheDisplay(in: hover.bounds, to: hoverBitmap) }
            if [0, 31, 63, 95, 127].contains(index) {
                try XCTUnwrap(hoverBitmap.representation(using: .png, properties: [:]))
                    .write(to: output.appendingPathComponent("hover-\(index).png"))
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    .write(to: output.appendingPathComponent("mac-\(index).png"))
                let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(
                    output.appendingPathComponent("phone-\(index).png") as CFURL, "public.png" as CFString, 1, nil))
                CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()), nil)
                XCTAssertTrue(CGImageDestinationFinalize(destination))
            }
        }
    }
}
#endif
