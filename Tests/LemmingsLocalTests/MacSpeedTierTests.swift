#if os(macOS)
import AppKit
import XCTest
@testable import LemmingsLocal

final class MacSpeedTierTests: XCTestCase {
    @MainActor func testShiftNumberSelectsAndSurvivesKeyRelease() throws {
        _ = NSApplication.shared
        let speed = GameSpeedControl()
        speed.ridiculousEnabled = true
        let keys: [UInt16] = [18, 19, 20, 21, 23, 22]
        for (index, tier) in speed.state.availableSteps.enumerated() {
            let now = Double(index) + 10
            speed.press(.shift, at: now)
            speed.update(at: now + 0.4, active: true)
            let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.shift],
                timestamp: now + 0.5, windowNumber: 0, context: nil, characters: String(Array("!@#$%^")[index]),
                charactersIgnoringModifiers: String(index + 1), isARepeat: false, keyCode: keys[index]))
            XCTAssertTrue(speed.handleTierShortcut(event))
            speed.release(.shift, at: now + 0.6)
            XCTAssertEqual(speed.target, tier)
        }
        speed.variableEnabled = false
        let digit = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.shift],
            timestamp: 20, windowNumber: 0, context: nil, characters: "@",
            charactersIgnoringModifiers: "2", isARepeat: false, keyCode: 19))
        XCTAssertFalse(speed.handleTierShortcut(digit))
    }

    @MainActor func testNarrowPedalKeepsAccessibleAndPointerTargetsAcrossResize() throws {
        _ = NSApplication.shared
        let panel = PanelView(frame: CGRect(x: 0, y: 0, width: 699, height: 400))
        let window = NSWindow(contentRect: panel.bounds, styleMask: [], backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        window.contentView = panel
        defer { window.close() }
        let speed = GameSpeedControl()
        panel.variableSpeedEnabled = true
        panel.timeline.speedState = { speed.state }
        panel.onSpeedStep = { direction, time in speed.step(direction, at: time) }
        panel.onSpeedPress = { speed.pointerDown(at: $0, clickCount: $1) }
        panel.onSpeedRelease = { time in speed.release(.mouse, at: time) }
        panel.onSpeedClick = { time, _ in speed.tap(at: time) }
        var originalPedal: GameAccessibleElement?
        for width in [699, 1024, 480] {
            panel.setFrameSize(CGSize(width: width, height: 400))
            let targets = panel.accessibleControls(owner: panel).compactMap { $0 as? GameAccessibleElement }
            let pedal = try XCTUnwrap(targets.first { $0.accessibilityLabel() == "Game speed 1×" })
            if let originalPedal { XCTAssertTrue(pedal === originalPedal) }
            originalPedal = pedal
            let down = try XCTUnwrap(targets.first { $0.accessibilityLabel() == "Decrease fast speed" })
            let up = try XCTUnwrap(targets.first { $0.accessibilityLabel() == "Increase fast speed" })
            for button in [down, pedal, up] {
                XCTAssertTrue(panel.bounds.contains(button.localFrame))
                XCTAssertFalse(panel.timeline.tierFrame.intersects(button.localFrame))
            }
            XCTAssertTrue(up.accessibilityPerformPress())
            XCTAssertEqual(speed.target, 2)
            let point = CGPoint(x: pedal.localFrame.midX, y: pedal.localFrame.midY)
            panel.handlePointerDown(at: point, time: 10)
            panel.handlePointerUp(time: 10.05)
            XCTAssertEqual(speed.target, 1)
            XCTAssertTrue(pedal.accessibilityPerformPress())
            XCTAssertEqual(speed.target, 2)
            let arrow = CGPoint(x: down.localFrame.midX, y: down.localFrame.midY)
            panel.handlePointerDown(at: arrow, time: 11)
            panel.handlePointerUp(time: 11.05)
            XCTAssertEqual(speed.target, 1)
        }
        try capture(panel, as: "mac-narrow-speed-pedal.png")
    }

    @MainActor private func capture(_ panel: PanelView, as filename: String) throws {
        let render = try XCTUnwrap(panel.bitmapImageRepForCachingDisplay(in: panel.bounds))
        panel.displayIgnoringOpacity(panel.bounds, in: try XCTUnwrap(NSGraphicsContext(bitmapImageRep: render)))
        let output = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent(".build/status-strip-renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try XCTUnwrap(render.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent(filename))
    }

    @MainActor func testStripTargetsAndRenders() throws {
        _ = NSApplication.shared
        let speed = GameSpeedControl()
        let panel = PanelView(frame: CGRect(x: 0, y: 0, width: 1024, height: 300))
        let window = NSWindow(contentRect: panel.bounds, styleMask: [], backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        window.contentView = panel
        defer { window.close() }
        let timeline = panel.timeline
        timeline.speedState = { speed.state }
        timeline.chooseSpeed = { speed.select($0, at: 1) }
        func elements() -> [GameAccessibleElement] {
            panel.accessibleControls(owner: panel).compactMap { $0 as? GameAccessibleElement }
                .filter { $0.accessibilityLabel()?.hasPrefix("Game speed ") == true && timeline.tierFrame.contains($0.localFrame) }
        }
        for optional in [false, true] {
            speed.ridiculousEnabled = optional
            let targets = elements()
            XCTAssertEqual(targets.count, speed.state.availableSteps.count)
            XCTAssertFalse(panel.minimapBounds.intersects(timeline.tierFrame))
            let original = targets.map(\.localFrame)
            for (tier, button) in zip(speed.state.availableSteps, targets) {
                let rect = button.localFrame
                XCTAssertGreaterThanOrEqual(rect.width, 44)
                for x in [rect.minX + 0.25, rect.midX, rect.maxX - 0.25] {
                    for y in [rect.minY + 0.25, rect.midY, rect.maxY - 0.25] {
                        speed.select(tier == 1 ? 2 : 1, at: 0)
                        panel.handlePointerDown(at: CGPoint(x: x, y: y))
                        panel.handlePointerUp()
                        XCTAssertEqual(speed.target, tier)
                    }
                }
                XCTAssertEqual(elements().map(\.localFrame), original)
                XCTAssertTrue(button.accessibilityLabel()?.contains("selected") == true)
            }
        }
        try capture(panel, as: "mac-speed-tiers.png")
        var enabled = false
        timeline.canChooseSpeed = { enabled }
        let disabled = try XCTUnwrap(elements().first)
        XCTAssertFalse(disabled.isAccessibilityEnabled())
        let point = CGPoint(x: disabled.localFrame.midX, y: disabled.localFrame.midY)
        XCTAssertTrue(timeline.click(at: point))
        XCTAssertEqual(speed.target, 25)
        enabled = true
        let first = try XCTUnwrap(elements().first)
        XCTAssertTrue(first.accessibilityPerformPress())
        XCTAssertEqual(speed.target, 1)
        for width in [699, 700, 1440] {
            timeline.layoutSequelFooter(in: CGRect(x: 0, y: 0, width: width, height: 600))
            XCTAssertEqual(timeline.tierFrame.isEmpty, width < 700)
            XCTAssertFalse(timeline.frame.intersects(timeline.tierFrame))
            if width >= 700 {
                XCTAssertTrue(timeline.click(at: CGPoint(x: timeline.tierFrame.maxX - 1, y: timeline.tierFrame.midY)))
                XCTAssertEqual(speed.target, 25)
            }
            panel.setFrameSize(CGSize(width: width, height: 300))
            XCTAssertEqual(elements().count, width < 700 ? 0 : 6)
        }
        speed.variableEnabled = false
        XCTAssertTrue(elements().isEmpty)
        panel.isCRTSource = true
        speed.variableEnabled = true
        XCTAssertTrue(elements().isEmpty)
    }
}
#endif
