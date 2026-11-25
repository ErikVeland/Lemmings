#if os(macOS)
import AppKit
import NxlvKit
import XCTest
@testable import LemmingsLocal

final class MacSpeedTierTests: XCTestCase {
    @MainActor func testFastMovieBatchComposesOnceAndKeepsEachTick() {
        let movie = RunMovie()
        movie.begin(ticksPerSecond: 17, title: "Fast-forward fixture")
        defer { movie.discard() }
        var draws = 0
        func frame() -> CGImage? {
            draws += 1
            return ReplayFrameCapture.image(size: CGSize(width: 16, height: 16)) {
                NSColor.black.setFill()
                CGRect(x: 0, y: 0, width: 16, height: 16).fill()
            }
        }

        movie.beginCaptureBatch(reuseFrames: true)
        for _ in 0..<24 { movie.capture(frame()) }
        XCTAssertEqual(draws, 1)
        XCTAssertEqual(movie.captureProfile.frames, 24)
        XCTAssertGreaterThan(movie.batchCompositionSeconds, 0)
        movie.capture(frame(), finalTick: true)
        XCTAssertEqual(draws, 2)
        movie.endCaptureBatch()
        XCTAssertEqual(movie.batchCompositionSeconds, 0)
        movie.capture(frame())
        XCTAssertEqual(draws, 3)
        XCTAssertEqual(movie.recorder?.encodingProfile.submittedFrames, 26)
    }

    @MainActor func testWideDeckFillsTheWindowWithoutReducingControlTargets() throws {
        let terrain = try ClassicDOSTerrain(width: 320, height: 96, solidMask: Data(repeating: 0, count: 30_720),
            steelMask: Data(repeating: 0, count: 30_720))
        let classic = ClassicSession(simulation: try ClassicDOSSimulation(terrain: terrain,
            configuration: .init(totalLemmings: 10, requiredToSave: 10, timeLimitTicks: nil, initialReleaseRate: 50,
                entrances: [.init(x: 40, y: 20)], initialSkills: [:], maximumX: 319, maximumY: 95)), width: 320, height: 96)
        let neo = NeoLemmixSession(simulation: try NeoLemmixSimulation(terrain: NeoLemmixTerrain(width: 320, height: 96),
            configuration: .init(totalLemmings: 10, requiredToSave: 10, spawnInterval: 50,
                entrances: [.init(id: 0, position: .init(x: 40, y: 20))],
                skills: Dictionary(uniqueKeysWithValues: NeoLemmixSkill.allCases.map { ($0, .finite(2)) }))), width: 320, height: 96)
        let panel = PanelView(frame: .zero)
        let speed = GameSpeedControl()
        panel.timeline.speedState = { speed.state }
        for (name, session) in [("classic", classic as any GameSession), ("neo", neo as any GameSession)] {
            panel.session = session
            var previousSkill = CGRect.zero
            var previousRewind = CGRect.zero
            for width in [CGFloat(1600), 2558, 3440] {
                panel.setFrameSize(CGSize(width: width, height: panel.height(for: width, maximumScale: 3)))
                let targets = panel.accessibleControls(owner: panel).compactMap { $0 as? GameAccessibleElement }
                let pause = try XCTUnwrap(targets.first { $0.accessibilityLabel() == "Pause" })
                let rewind = panel.timeline.rect(for: .rewind)
                let skill = panel.controlBounds
                XCTAssertEqual(skill.minX, 8, accuracy: 0.01)
                XCTAssertEqual(pause.localFrame.maxX, width - 8, accuracy: 0.01)
                XCTAssertEqual(panel.timeline.tierFrame.maxX, width - 8, accuracy: 0.01)
                XCTAssertFalse(panel.minimapBounds.intersects(panel.timeline.tierFrame))
                XCTAssertGreaterThanOrEqual(skill.width, previousSkill.width)
                XCTAssertGreaterThanOrEqual(skill.height, previousSkill.height)
                XCTAssertGreaterThanOrEqual(rewind.width, previousRewind.width)
                previousSkill = skill
                previousRewind = rewind

                var buttons: [PanelButton] = []
                panel.onButton = { buttons.append($0) }
                for (frame, x) in [(skill, skill.minX + 1), (pause.localFrame, pause.localFrame.maxX - 1)] {
                    panel.handlePointerDown(at: CGPoint(x: x, y: frame.midY))
                    panel.handlePointerUp()
                }
                XCTAssertEqual(buttons, [.skill(0), .pause])
                var rewound = false
                panel.timeline.enabled = { $0 == .rewind }
                panel.timeline.perform = { rewound = $0 == .rewind }
                panel.handlePointerDown(at: CGPoint(x: rewind.maxX - 1, y: rewind.midY))
                panel.handlePointerUp()
                XCTAssertTrue(rewound)
            }
            try capture(panel, as: "mac-wide-\(name)-controls.png")
        }
    }

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
        panel.isCRTSource = false
        speed.select(25, at: 1)
        speed.update(at: 2, active: true)
        for _ in 0..<4 {
            speed.observeThroughput(elapsed: 0.25, ticks: 31, ticksPerSecond: 17)
        }
        XCTAssertEqual(speed.target, 5)
        let cappedTargets = elements()
        XCTAssertEqual(cappedTargets.count, 4)
        let fastest = try XCTUnwrap(cappedTargets.last)
        XCTAssertTrue(fastest.accessibilityLabel()?.contains("5×") == true)
        try capture(panel, as: "mac-speed-cap.png")
        speed.reset(at: 3)
        panel.handlePointerDown(at: CGPoint(x: fastest.localFrame.midX, y: fastest.localFrame.midY))
        panel.handlePointerUp()
        XCTAssertEqual(speed.target, 5)
    }
}
#endif
