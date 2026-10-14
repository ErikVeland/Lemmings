#if os(macOS)
import AppKit
import NxlvKit
import XCTest
@testable import LemmingsLocal

final class DJParityUITests: XCTestCase {
    @MainActor func testAudioScopeInputTargetsAndControllerDispatch() throws {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let art = try ClassicMacArtwork(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings"))
        let renderer = MacInterfaceRenderer(interface: try XCTUnwrap(ClassicMacUserInterface(artwork: art)))
        try GameMenuArtwork.withRenderer(renderer) {
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1280, height: 800), styleMask: [], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = NSView(frame: CGRect(x: 0, y: 0, width: 1280, height: 800))
            let previous = GameScreen.shared.gameWindow
            GameScreen.shared.gameWindow = window
            defer { GameScreen.shared.dismissAll(); GameScreen.shared.gameWindow = previous; window.close() }
            let page = SettingsWindow(settings: ClassicSettings(), options: .available(hasDOSData: true,
                hasAmigaDisk: true, hasMacintoshDisk: true, moduleCount: 1))
            page.show()
            let host = try XCTUnwrap(window.contentView)
            @MainActor func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
            host.layoutSubtreeIfNeeded()
            let audio = try XCTUnwrap(descendants(host).compactMap { $0 as? GameTabButton }.first { $0.title == "Audio" })
            audio.performClick(nil)
            host.layoutSubtreeIfNeeded()
            let picker = try XCTUnwrap(descendants(host).compactMap { $0 as? GamePopUpButton }
                .first { $0.itemTitles == SoundtrackCatalogue.ShuffleScope.allCases.map(\.title) })
            picker.scrollToVisible(picker.bounds)
            host.layoutSubtreeIfNeeded()
            XCTAssertGreaterThanOrEqual(picker.bounds.height, 28)
            let centre = picker.convert(CGPoint(x: picker.bounds.midX, y: picker.bounds.midY), to: host)
            XCTAssertTrue(host.hitTest(centre) === picker)
            try capture(host, root: root, name: "audio-same-track")
            picker.performClick(nil)
            host.layoutSubtreeIfNeeded()
            let choice = try XCTUnwrap(descendants(host).compactMap { $0 as? GameActionButton }.first { $0.title == "All tracks" })
            XCTAssertTrue(host.hitTest(choice.convert(CGPoint(x: choice.bounds.midX, y: choice.bounds.midY), to: host)) === choice)
            choice.performClick(nil)
            XCTAssertEqual(page.current.djShuffleScope, .allTracks)
            host.layoutSubtreeIfNeeded()
            try capture(host, root: root, name: "audio-all-tracks")
            GameScreen.shared.dismissAll()
            let keyboard = GameplayKeyboard(window: window)
            keyboard.active = { true }
            var shuffles = 0
            keyboard.djShuffle = { shuffles += 1 }
            let controller = GameplayController(keyboard: keyboard, pollsAutomatically: false)
            controller.processButtons([], at: 0, playing: true)
            controller.processButtons([.leftTrigger, .leftStick], at: 1, playing: true)
            controller.processButtons([.leftTrigger, .leftStick], at: 2, playing: true)
            XCTAssertEqual(shuffles, 1)
            controller.processButtons([], at: 3, playing: false)
            controller.processButtons([.leftTrigger, .leftStick], at: 4, playing: false)
            XCTAssertEqual(shuffles, 1)
            keyboard.removeNavigationControl()
        }
    }
    @MainActor private func capture(_ view: NSView, root: URL, name: String) throws {
        let output = root.appendingPathComponent(".build/dj-parity-ui")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent(name + ".png"))
    }
}
#endif
