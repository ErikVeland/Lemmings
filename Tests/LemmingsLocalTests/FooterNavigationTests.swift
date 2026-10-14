#if os(macOS)
import AppKit
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import XCTest
@testable import LemmingsLocal

final class FooterNavigationTests: XCTestCase {
    private func verify(_ layout: GameFrontEnd.Layout, page: GameFrontEnd.Page) throws {
        let footer = layout.targets.filter { page.footer.contains($0.action) }
        XCTAssertEqual(Set(footer.map { $0.action.id }), Set(page.footer.map(\.id)))
        let back = try XCTUnwrap(footer.first { $0.action.isBackNavigation })
        XCTAssertEqual(back.frame.minX, footer.map { $0.frame.minX }.min())
        XCTAssertEqual(back.frame.maxY, footer.map { $0.frame.maxY }.max())
        if let forward = footer.first(where: { $0.action.primary && !$0.action.isBackNavigation }) {
            XCTAssertEqual(forward.frame.maxY, back.frame.maxY)
            XCTAssertGreaterThan(forward.frame.minX, back.frame.maxX)
            XCTAssertEqual(forward.frame.maxX, footer.map { $0.frame.maxX }.max())
        }
        let ordered = footer.sorted { $0.frame.minY == $1.frame.minY ? $0.frame.minX < $1.frame.minX : $0.frame.minY < $1.frame.minY }
        XCTAssertEqual(footer.map(\.action), ordered.map(\.action))
        for (index, target) in layout.targets.enumerated() {
            XCTAssertTrue(CGRect(origin: .zero, size: layout.size).contains(target.frame))
            XCTAssertGreaterThanOrEqual(target.frame.width, 44)
            XCTAssertGreaterThanOrEqual(target.frame.height, 44)
            XCTAssertEqual(layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)),
                           target.action.enabled ? target.action.id : nil)
            XCTAssertTrue(layout.targets.dropFirst(index + 1).allSatisfy { !$0.frame.intersects(target.frame) })
        }
    }

    func testBackKeepsItsCornerAsActionsAndColumnsChange() throws {
        for label in ["Back", "Back to game", "Cancel", "Library", "Close"] {
            for count in 1...8 {
                for columns in 1...3 {
                    for insertion in 0..<count {
                        var footer = (0..<count - 1).map { GameFrontEnd.Action("action.\($0)", "Action \($0)", enabled: $0 != 1) }
                        footer.insert(.init("back", label, enabled: insertion % 2 == 0), at: insertion)
                        if count > 1, let index = footer.lastIndex(where: { !$0.isBackNavigation }) { footer[index].primary = true }
                        let page = GameFrontEnd.Page(title: "Library", rows: [.init("item", "Level")], footer: footer, footerColumns: columns)
                        for width: CGFloat in [320, 900] {
                            try verify(GameFrontEnd.layout(page, width: width, minimumHeight: 620), page: page)
                        }
                    }
                }
            }
        }
    }

    func testResultHomeAndPinnedPauseUseTheSameNavigationRule() throws {
        let actions: [GameFrontEnd.Action] = [.init("retry", "Retry"), .init("hints", "Hints"),
            .init("later", "Try later"), .init("back", "Back"), .init("next", "Continue", primary: true)]
        let summary = MobilePauseSummary(level: .init(index: 0, rank: "Classic", number: 1, title: "Just Dig!"),
            snapshot: .init(tick: 0, released: 0, total: 10, saved: 0, required: 5, remainingSeconds: 120,
                releaseRate: 50, isComplete: false, didWin: false, isEndingRun: false, skills: []),
            activeCount: 0, ticksPerSecond: 17, speed: 1, assignedSkills: 0, supportsRewind: true,
            usedRewind: false, isReplay: false, soundtrack: "Original", track: "Intro", audio: "Music on")
        for width: CGFloat in [320, 390, 900, 1920] {
            var result = GameFrontEnd.Page(title: "Level complete", details: ["Saved 10 / 10"], footer: actions, preview: true)
            result.result = true
            try verify(GameFrontEnd.layout(result, width: width, minimumHeight: 720), page: result)
            let home = GameFrontEnd.Page(title: "Library", home: true, rows: [.init("classic", "Classic")], footer: actions)
            try verify(GameFrontEnd.layout(home, width: width, minimumHeight: 720), page: home)
            let pause = MobilePauseArt.page(summary, actions: actions)
            let base = GameFrontEnd.layout(pause, width: width, minimumHeight: 720)
            try verify(base, page: pause)
            for offset in [CGFloat(0), max(0, base.size.height - 720)] {
                let viewport = CGRect(x: 0, y: offset, width: width, height: 720)
                let pinned = MobilePauseArt.pinningFooter(base, viewport: viewport)
                try verify(pinned, page: pause)
                XCTAssertTrue(pinned.targets.allSatisfy { viewport.contains($0.frame) })
            }
        }
        let tv = TVMenuArt.layout(.init(title: "TV library", footer: actions))
        let back = try XCTUnwrap(tv.targets.first { $0.action.id == "back" })
        XCTAssertEqual(back.frame.minX, tv.targets.map { $0.frame.minX }.min())
    }

    @MainActor func testMacMessagesKeepBackFixedAndRetainKeyboardAndMouseTargets() throws {
        _ = NSApplication.shared
        var renderer: MacInterfaceRenderer?
        if let directory = ProcessInfo.processInfo.environment["LEMMINGS_TEST_MENU_ARTWORK"],
           let interface = ClassicMacUserInterface(artwork: try ClassicMacArtwork(directory: URL(fileURLWithPath: directory))) {
            renderer = MacInterfaceRenderer(interface: interface)
        }
        for size in [CGSize(width: 1120, height: 720), CGSize(width: 900, height: 620)] {
            let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            let page = renderer.map { GameMenuArtwork.withRenderer($0) { GameMenuPage(title: "Return to the game?") } }
                ?? GameMenuPage(title: "Return to the game?")
            window.contentView = page
            page.layoutSubtreeIfNeeded()
            let back = page.controllerBackButton
            let original = back.convert(back.bounds, to: page)
            page.setDetail("Your saved run stays paused until you are ready.")
            XCTAssertEqual(back.convert(back.bounds, to: page), original)
            var forwardPresses = 0, backPresses = 0
            page.onBack = { backPresses += 1 }
            let forward = page.addPrimaryAction("Resume") { forwardPresses += 1 }
            page.layoutSubtreeIfNeeded()
            XCTAssertEqual(back.convert(back.bounds, to: page), original)
            let next = forward.convert(forward.bounds, to: page)
            XCTAssertGreaterThan(next.minX, original.maxX)
            XCTAssertEqual(original.maxY, next.maxY)
            for control in [back, forward] {
                let frame = control.convert(control.bounds, to: page)
                let point = page.convert(CGPoint(x: frame.midX, y: frame.midY), to: page.superview)
                XCTAssertTrue(page.hitTest(point) === control)
            }
            let navigation = DialogKeyboardNavigation()
            XCTAssertEqual(navigation.controls(in: page).compactMap { ($0 as? NSButton)?.title }, ["Back", "Resume"])
            back.performClick(nil); forward.performClick(nil)
            XCTAssertEqual(backPresses, 1); XCTAssertEqual(forwardPresses, 1)
            if let output = ProcessInfo.processInfo.environment["LEMMINGS_FOOTER_CAPTURES"] {
                func capture() throws {
                    let bitmap = try XCTUnwrap(page.bitmapImageRepForCachingDisplay(in: page.bounds))
                    func invalidate(_ view: NSView) { view.needsDisplay = true; view.subviews.forEach(invalidate) }
                    invalidate(page)
                    page.cacheDisplay(in: page.bounds, to: bitmap)
                    try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(
                        to: URL(fileURLWithPath: output).appendingPathComponent("mac-message-\(Int(size.width)).png"))
                }
                if let renderer {
                    try GameMenuArtwork.withRenderer(renderer, capture)
                } else { try capture() }
            }
            window.close()
        }
    }

    @MainActor func testReplayAndMovieReturnControlsLeadTheirRows() throws {
        _ = NSApplication.shared
        let bar = ReplayBar(frame: CGRect(x: 0, y: 0, width: 900, height: 128))
        let window = NSWindow(contentRect: bar.bounds, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = bar
        defer { window.close() }
        var closed = false
        bar.onAction = { if case .close = $0 { closed = true } }
        let controls = try XCTUnwrap(bar.accessibilityChildren()).compactMap { $0 as? GameAccessibleElement }
        let back = try XCTUnwrap(controls.first { $0.accessibilityLabel() == "Back" })
        let play = try XCTUnwrap(controls.first { $0.accessibilityLabel() == "Play" })
        XCTAssertLessThan(back.localFrame.minX, play.localFrame.minX)
        XCTAssertTrue(back.accessibilityPerformPress()); XCTAssertTrue(closed)
        var bytes = Data(repeating: 0, count: 144)
        bytes[4] = 0x11; bytes[5] = 0xAF; bytes[6] = 1
        bytes[8] = 2; bytes[10] = 2; bytes[12] = 8
        bytes[128] = 16; bytes[132] = 0xFA; bytes[133] = 0xF1
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("footer-movie-\(UUID()).fli")
        try bytes.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let movie = try OriginalMoviePlayer(url: url)
        movie.frame = CGRect(x: 0, y: 0, width: 900, height: 620)
        movie.layoutSubtreeIfNeeded()
        let buttons = movie.subviews.compactMap { $0 as? NSButton }
        let movieBack = try XCTUnwrap(buttons.first { $0.title == "Back" })
        XCTAssertEqual(buttons.first?.title, "Back")
        XCTAssertEqual(movieBack.frame.minX, 12)
        XCTAssertTrue(buttons.filter { $0 !== movieBack }.allSatisfy { $0.frame.minX > movieBack.frame.maxX })
    }

    func testRenderedColumnFooters() throws {
        guard let directory = ProcessInfo.processInfo.environment["LEMMINGS_TEST_MENU_ARTWORK"],
              let output = ProcessInfo.processInfo.environment["LEMMINGS_FOOTER_CAPTURES"] else { return }
        let typography = try XCTUnwrap(GameMenuTypography(directory: URL(fileURLWithPath: directory)))
        for width: CGFloat in [390, 900, 1920] {
            for count in [3, 5, 7] {
                var footer = (0..<count - 2).map { GameFrontEnd.Action("action.\($0)", "Option \($0 + 1)", enabled: $0 != 1) }
                footer += [.init("back", "Back"), .init("continue", "Continue", primary: true)]
                let page = GameFrontEnd.Page(title: "Choose your next adventure", footer: footer)
                let layout = GameFrontEnd.layout(page, width: width, minimumHeight: 720)
                try verify(layout, page: page)
                let context = try XCTUnwrap(CGContext(data: nil, width: Int(layout.size.width), height: Int(layout.size.height),
                    bitsPerComponent: 8, bytesPerRow: Int(layout.size.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.translateBy(x: 0, y: layout.size.height); context.scaleBy(x: 1, y: -1)
                GameFrontEnd.draw(page, layout: layout, typography: typography, in: context)
                let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(context.makeImage()))
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(
                    to: URL(fileURLWithPath: output).appendingPathComponent("columns-\(Int(width))-\(count).png"))
            }
        }
    }
}
#endif
