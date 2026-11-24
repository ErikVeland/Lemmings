#if os(macOS)
import AppKit
import NxlvKit
import XCTest
@testable import LemmingsLocal

/// The death counter's skull must not shrink the gameplay status strip.
final class StatusStripRenderTests: XCTestCase {
    private let status = "Out 10/50   Home 0/50 (0%)   Rate 1   1/1 💀   Time 2:28"
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    @MainActor private func inkHeight(artwork: ClassicMacArtwork?, name: String, text: String? = nil) throws -> Int {
        _ = NSApplication.shared
        let panel = PanelView(frame: CGRect(x: 0, y: 0, width: 1280, height: 40))
        panel.interfaceArtwork = artwork
        panel.isMenuMode = true
        panel.statusText = text ?? status
        let bitmap = try XCTUnwrap(panel.bitmapImageRepForCachingDisplay(in: panel.bounds))
        panel.displayIgnoringOpacity(panel.bounds, in: try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap)))
        let output = root.appendingPathComponent(".build/status-strip-renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent("\(name).png"))
        var rows: [Int] = []
        for y in 0..<bitmap.pixelsHigh {
            let inked = (0..<bitmap.pixelsWide).contains { x in
                guard let colour = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return false }
                return colour.blueComponent > 0.6 && colour.redComponent < 0.5
            }
            if inked { rows.append(y) }
        }
        let scale = bitmap.pixelsHigh / Int(panel.bounds.height)
        return ((rows.last ?? 0) - (rows.first ?? 0) + 1) / max(1, scale)
    }

    @MainActor func testSpeedAndRateMouseTargetsStayFixed() throws {
        _ = NSApplication.shared
        let panel = PanelView(frame: CGRect(x: 0, y: 0, width: 1120, height: 150))
        panel.isMenuMode = false
        panel.variableSpeedEnabled = true
        var event = ""
        panel.onButton = { event = String(describing: $0) }
        panel.onSpeedPress = { _, _ in event = "speed" }
        panel.onSpeedStep = { direction, _ in event = String(direction) }
        var reference: [CGRect]?
        for multiplier in ["1×", "10×", "25×"] {
            panel.speedLabel = multiplier
            let elements = panel.accessibleControls(owner: panel).compactMap { $0 as? GameAccessibleElement }
            var frames: [CGRect] = []
            for (name, expected) in [("Game speed " + multiplier, "speed"), ("Decrease fast speed", "-1"), ("Increase fast speed", "1"),
                                     ("Decrease release rate", "rateDown"), ("Increase release rate", "rateUp"), ("Pause", "pause")] {
                let frame = try XCTUnwrap(elements.first { $0.accessibilityLabel() == name }, name).localFrame
                frames.append(frame)
                for x in [frame.minX + 0.25, frame.midX, frame.maxX - 0.25] {
                    for y in [frame.minY + 0.25, frame.midY, frame.maxY - 0.25] {
                        event = ""
                        panel.handlePointerDown(at: CGPoint(x: x, y: y), time: 1)
                        panel.handlePointerUp(time: 1.01)
                        XCTAssertEqual(event, expected, name)
                    }
                }
            }
            if let reference { XCTAssertEqual(frames, reference) } else { reference = frames }
        }
        event = ""
        panel.handlePointerDown(at: CGPoint(x: 1, y: 1))
        panel.handlePointerUp()
        XCTAssertEqual(event, "")
    }

    @MainActor func testPixelFallbackUsesDoubleScaleWhenTheLineFits() throws {
        XCTAssertGreaterThanOrEqual(try inkHeight(artwork: nil, name: "pixel-fallback"), 14)
    }

    @MainActor func testSkullKeepsTheLineInTheMacintoshFont() throws {
        let folder = root.appendingPathComponent(".build/mac-artwork/export/lemmings")
        guard FileManager.default.fileExists(atPath: folder.appendingPathComponent("manifest.json").path) else {
            throw XCTSkip("Local original Macintosh artwork is absent.")
        }
        let artwork = try ClassicMacArtwork(directory: folder)
        let withSkull = try inkHeight(artwork: artwork, name: "mac-font-skull")
        let withoutSkull = try inkHeight(artwork: artwork, name: "mac-font-safe",
            text: status.replacingOccurrences(of: "1/1 💀", with: "SAFE"))
        XCTAssertGreaterThanOrEqual(withSkull, withoutSkull)
    }
}
#endif
