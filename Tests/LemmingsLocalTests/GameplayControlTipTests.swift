#if os(macOS)
import AppKit
import XCTest
import LemmingsGameArt
import NxlvKit
@testable import LemmingsLocal

@MainActor private final class TipTestWindow: NSWindow {
    override var isKeyWindow: Bool { true }
}

final class GameplayControlTipTests: XCTestCase {
    @MainActor func testGameplayTipsDismissWithoutChangingFocusOrSpeedAndStayDismissed() throws {
        _ = NSApplication.shared
        let suite = "control-tip-test-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let window = TipTestWindow(contentRect: CGRect(x: 0, y: 0, width: 850, height: 560),
                                   styleMask: [], backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let root = try XCTUnwrap(window.contentView)
        let keyboard = GameplayKeyboard(window: window)
        let tips = GameplayControlTips(profileID: "new", defaults: defaults, previouslyPlayed: false)
        keyboard.controlTips = { tips }
        keyboard.active = { true }
        let speed = GameSpeedControl()
        speed.select(3, at: 12)
        keyboard.speedControl = speed
        let responder = window.firstResponder
        for topic in GameplayControlTip.allCases {
            keyboard.showControlTip(topic)
            let panel = try XCTUnwrap(root.subviews.compactMap { $0 as? GameSettingsHelpPanel }.first)
            XCTAssertTrue(root.bounds.contains(panel.frame))
            XCTAssertNil(panel.hitTest(CGPoint(x: panel.bounds.midX, y: panel.bounds.midY)))
            let bitmap = try XCTUnwrap(panel.bitmapImageRepForCachingDisplay(in: panel.bounds))
            panel.cacheDisplay(in: panel.bounds, to: bitmap)
            try saveCapture(bitmap, name: "tip-" + String(topic.rawValue))
            XCTAssertTrue(window.firstResponder === responder)
            XCTAssertEqual(speed.target, 3)
            keyboard.controllerAction(.focusLast)
            XCTAssertTrue(window.firstResponder === responder)
            XCTAssertEqual(speed.target, 3)
            keyboard.showControlTip(topic)
            XCTAssertFalse(root.subviews.contains { $0 is GameSettingsHelpPanel })
        }
        let reopened = GameplayControlTips(profileID: "new", defaults: defaults, previouslyPlayed: true)
        XCTAssertTrue(reopened.enabled)
        XCTAssertTrue(GameplayControlTip.allCases.allSatisfy { !reopened.needs($0) })
        let returning = GameplayControlTips(profileID: "experienced", defaults: defaults, previouslyPlayed: true)
        XCTAssertFalse(returning.needs(.assignment))
        returning.enabled = true
        XCTAssertTrue(returning.needs(.assignment))
        returning.enabled = false
        XCTAssertFalse(GameplayControlTips(profileID: "experienced", defaults: defaults, previouslyPlayed: false).enabled)
        XCTAssertTrue(GameplayControlTips(profileID: "guest", defaults: defaults, previouslyPlayed: false).needs(.speed))
    }

    @MainActor func testSequelMapRendersAndSeeksWithoutActivatingTransport() throws {
        let timeline = TimelinePanelControls()
        let speed = GameSpeedControl()
        speed.ridiculousEnabled = true
        timeline.speedState = { speed.state }
        timeline.mapSize = CGSize(width: 200, height: 400)
        timeline.visibleMapRect = CGRect(x: 80, y: 180, width: 40, height: 60)
        var positions: [CGPoint] = []
        timeline.onMap = { positions.append($0) }
        let owner = NSView(frame: .zero)
        for width in [640, 700, 850, 1024] {
            let bounds = CGRect(x: 0, y: 0, width: width, height: 540)
            timeline.layoutSequelFooter(in: bounds)
            XCTAssertFalse(timeline.mapFrame.isEmpty)
            XCTAssertTrue(bounds.contains(timeline.mapFrame))
            XCTAssertFalse(timeline.mapFrame.intersects(timeline.frame))
            XCTAssertFalse(timeline.mapFrame.intersects(timeline.tierFrame))
            let map = timeline.mapFrame
            XCTAssertTrue(timeline.beginMapDrag(at: CGPoint(x: map.minX + 1, y: map.midY)))
            XCTAssertFalse(timeline.draggingMap)
            XCTAssertTrue(timeline.beginMapDrag(at: CGPoint(x: map.midX, y: map.midY)))
            XCTAssertEqual(positions.last, CGPoint(x: 100, y: 200))
            timeline.dragMap(to: CGPoint(x: map.midX, y: map.maxY + 20))
            XCTAssertEqual(positions.last, CGPoint(x: 100, y: 400))
            timeline.endMapDrag()
            let controls = timeline.accessibleControls(owner: owner).compactMap { $0 as? GameAccessibleElement }
            let element = try XCTUnwrap(controls.first { $0.accessibilityLabel() == "Level map" })
            XCTAssertTrue(element.accessibilityPerformIncrement())
            XCTAssertEqual(positions.last, CGPoint(x: 120, y: 210))
            let image = NSImage(size: bounds.size, flipped: true) { _ in
                let terrain = NSImage(size: CGSize(width: 20, height: 40), flipped: true) { rect in
                    NSColor.black.setFill()
                    rect.fill()
                    NSColor.green.setFill()
                    CGRect(x: 0, y: 24, width: 20, height: 16).fill()
                    return true
                }
                timeline.draw()
                timeline.drawMap(image: terrain.cgImage(forProposedRect: nil, context: nil, hints: nil))
                return true
            }
            let render = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
            let pixels = NSBitmapImageRep(cgImage: render)
            let painted = [Int(map.midY), Int(bounds.height - map.midY)].contains { y in
                (pixels.colorAt(x: Int(map.midX), y: y)?.alphaComponent ?? 0) > 0
            }
            XCTAssertTrue(painted)
            XCTAssertEqual(speed.target, 1)
            try saveCapture(pixels, name: "map-" + String(width))
        }
    }

    private func saveCapture(_ bitmap: NSBitmapImageRep, name: String) throws {
        guard let directory = ProcessInfo.processInfo.environment["LEMMINGS_TIP_CAPTURES"] else { return }
        let output = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent(name + ".png"))
    }
}
#endif
