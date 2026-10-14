#if os(macOS)
import AppKit
import LemmingsGameArt
import NxlvKit
import XCTest

final class LocalisationLayoutTests: XCTestCase {
    func testExpandedSharedPagesRetainStatesAndInputTargets() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let typography = try XCTUnwrap(GameMenuTypography(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings")))
        let expanded = InterfaceLocalisation(bundle: nil, expandsText: true)
        let output = root.appendingPathComponent(".build/localisation-renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for width: CGFloat in [390, 834, 1280] {
            for result in [false, true] {
                let actions: [GameFrontEnd.Action] = [
                    .init("back", expanded.text("Back"), backNavigation: true),
                    .init("retry", expanded.text("Try again"), selected: true),
                    .init("unavailable", expanded.text("Continue"), enabled: false),
                    .init("ready", expanded.text("Ready, \("ALICE")"), primary: true),
                ]
                var page = GameFrontEnd.Page(title: expanded.text("Level complete"), subtitle: expanded.text("Played: \("ALICE")"),
                    details: [expanded.text("Saved \(60) of \(80)"), expanded.text("No time limit")], footer: actions, footerColumns: 2)
                page.result = result
                let layout = GameFrontEnd.layout(page, width: width, minimumHeight: 700)
                let back = try XCTUnwrap(layout.targets.first { $0.action.id == "back" })
                let forward = try XCTUnwrap(layout.targets.first { $0.action.id == "ready" })
                XCTAssertLessThanOrEqual(back.frame.minX, forward.frame.minX)
                for target in layout.targets {
                    let point = CGPoint(x: target.frame.midX, y: target.frame.midY)
                    XCTAssertEqual(layout.action(at: point), target.action.enabled ? target.action.id : nil)
                    XCTAssertTrue(CGRect(origin: .zero, size: layout.size).contains(target.frame))
                }
                let colour = CGColorSpaceCreateDeviceRGB()
                let context = try XCTUnwrap(CGContext(data: nil, width: Int(layout.size.width), height: Int(layout.size.height), bitsPerComponent: 8,
                    bytesPerRow: 0, space: colour, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.translateBy(x: 0, y: layout.size.height)
                context.scaleBy(x: 1, y: -1)
                GameFrontEnd.draw(page, layout: layout, typography: typography, highlighted: "retry", in: context)
                let image = try XCTUnwrap(context.makeImage())
                let bitmap = NSBitmapImageRep(cgImage: image)
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent("expanded-\(Int(width))-\(result ? "result" : "menu").png"))
            }
        }
    }
}
#endif
