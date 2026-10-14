#if os(macOS)
import AppKit
import LemmingsGameArt
import XCTest
@testable import LemmingsLocal

@MainActor private final class MusicCardCanvas: NSView {
    var usesFlippedCoordinates = false
    override var isFlipped: Bool { usesFlippedCoordinates }
}

final class MusicTitleCardTests: XCTestCase {
    private let title = "A Very Long Song Title That Keeps Every Word of the Original Recording and Its Extended Finale"
    private let source = "Oh No! More Lemmings - Original Macintosh Soundtrack and Orchestral Arrangement"

    func testCompleteCreditsFitEveryPageWithoutShrinkingOrEllipses() {
        for width: CGFloat in [240, 320, 480, 900] {
            for height: CGFloat in [80, 130, 210] {
                let layout = MusicTitleCard.layout(title: title, soundtrack: source, maximumWidth: width, maximumHeight: height)
                XCTAssertFalse(layout.pages.isEmpty)
                XCTAssertLessThanOrEqual(layout.size.width, width)
                XCTAssertLessThanOrEqual(layout.size.height, height)
                let lines = layout.pages.flatMap(\.lines)
                func letters(_ text: String) -> String { GameMenuTypography.menuText(text).filter { !$0.isWhitespace } }
                XCTAssertEqual(letters(lines.filter { $0.palette == .green }.map(\.text).joined()), letters(title))
                XCTAssertEqual(letters(lines.filter { $0.palette == .blue }.map(\.text).joined()), letters(source))
                for line in lines {
                    XCTAssertTrue(CGRect(origin: .zero, size: layout.size).contains(line.frame))
                    XCTAssertFalse(line.text.contains("..."))
                    XCTAssertLessThanOrEqual(CGFloat(line.text.count * (line.face == .large ? 16 : 12)), line.frame.width)
                }
                for page in layout.pages {
                    for pair in zip(page.lines, page.lines.dropFirst()) { XCTAssertFalse(pair.0.frame.intersects(pair.1.frame)) }
                }
                var elapsed: TimeInterval = 0
                for (index, page) in layout.pages.enumerated() {
                    XCTAssertEqual(layout.pageIndex(at: elapsed), index)
                    XCTAssertEqual(layout.nextPageTime(after: elapsed), elapsed + page.duration, accuracy: 0.001)
                    elapsed += page.duration
                }
                XCTAssertGreaterThan(layout.duration, 4.5)
            }
        }
        let unbroken = String(repeating: "LONGTITLE", count: 15)
        let layout = MusicTitleCard.layout(title: unbroken, soundtrack: "", maximumWidth: 240, maximumHeight: 80)
        XCTAssertEqual(layout.pages.flatMap(\.lines).map(\.text).joined(), unbroken)
        XCTAssertTrue(MusicTitleCard.layout(title: title, soundtrack: source, maximumWidth: 40, maximumHeight: 40).pages.isEmpty)
    }

    func testShortCreditsRetainTheirDisplayTimeAndUpperCorner() {
        let layout = MusicTitleCard.layout(title: "Intro", soundtrack: "Lemmings - Amiga", maximumWidth: 600, maximumHeight: 180)
        XCTAssertEqual(layout.pages.count, 1)
        XCTAssertEqual(layout.duration, 4.5)
        let area = CGRect(x: 44, y: 30, width: 800, height: 400)
        for flipped in [false, true] {
            let frame = MusicTitleCard.frame(size: layout.size, in: area, flipped: flipped)
            XCTAssertTrue(area.contains(frame))
            XCTAssertEqual(frame.minX, area.minX + 12)
            XCTAssertEqual(flipped ? frame.minY : frame.maxY, flipped ? area.minY + 12 : area.maxY - 12)
        }
    }

    @MainActor func testNativeNoticeFadesPassesInputAndDoesNotReopenAfterResize() {
        _ = NSApplication.shared
        let root = NSView(frame: CGRect(x: 0, y: 0, width: 900, height: 620))
        let notice = NowPlayingNotice(frame: .zero)
        root.addSubview(notice)
        let area = CGRect(x: 0, y: 120, width: 900, height: 500)
        let track = PlayingTrack(url: URL(fileURLWithPath: "/test/intro.mod"), title: "Intro", soundtrack: "Lemmings - Amiga")
        func update(_ time: TimeInterval, track: PlayingTrack? = track, enabled: Bool = true, reduced: Bool = false, region: CGRect = area) {
            notice.update(track: track, at: time, visible: true, reduceMotion: reduced, enabled: enabled, area: region, flipped: false)
        }
        update(100)
        XCTAssertEqual(notice.artworkOpacity, 0)
        update(100.175)
        XCTAssertEqual(notice.artworkOpacity, 0.5, accuracy: 0.01)
        update(100.35)
        XCTAssertEqual(notice.artworkOpacity, 1)
        XCTAssertTrue(area.contains(notice.frame))
        XCTAssertNil(notice.hitTest(CGPoint(x: notice.bounds.midX, y: notice.bounds.midY)))
        let point = CGPoint(x: notice.frame.midX, y: notice.frame.midY)
        XCTAssertTrue(root.hitTest(point) === root)
        XCTAssertEqual(notice.accessibilityLabel(), "Intro. Lemmings - Amiga")
        update(104.25)
        XCTAssertEqual(notice.artworkOpacity, 0.5, accuracy: 0.01)
        update(105)
        XCTAssertTrue(notice.isHidden)
        update(106, region: CGRect(x: 0, y: 120, width: 220, height: 200))
        XCTAssertTrue(notice.isHidden)
        update(107, enabled: false)
        XCTAssertNil(notice.track)
        XCTAssertFalse(notice.isAccessibilityElement())
        update(108, reduced: true)
        XCTAssertEqual(notice.artworkOpacity, 1)
        XCTAssertFalse(notice.isHidden)
        update(113, reduced: true)
        XCTAssertTrue(notice.isHidden)
        let long = PlayingTrack(url: URL(fileURLWithPath: "/test/long.mod"), title: title, soundtrack: source)
        update(120, track: long, reduced: true)
        XCTAssertGreaterThan(notice.displayDuration, 4.5)
        update(125, track: long, reduced: true)
        XCTAssertFalse(notice.isHidden)
    }

    @MainActor func testKeyboardPlacesCreditsInsidePlayfieldAndKeepsMenuClickable() throws {
        _ = NSApplication.shared
        for (width, flipped) in [CGFloat(600), 900].flatMap({ width in [false, true].map { (width, $0) } }) {
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: width, height: 620),
                                  styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            let root = MusicCardCanvas(frame: CGRect(x: 0, y: 0, width: width, height: 620))
            root.usesFlippedCoordinates = flipped; window.contentView = root
            let area = CGRect(x: 0, y: flipped ? 0 : 200, width: width, height: 420)
            let keyboard = GameplayKeyboard(window: window)
            defer { keyboard.removeNavigationControl(); window.close() }
            keyboard.active = { true }; keyboard.ownsController = { true }
            keyboard.mainMenu = {}; keyboard.navigationAvailable = { true }
            keyboard.musicDisplayArea = { area }
            keyboard.playingTrack = { PlayingTrack(url: URL(fileURLWithPath: "/test/long.mod"), title: self.title, soundtrack: self.source) }
            keyboard.refreshNavigationControl(at: 100)
            keyboard.refreshNavigationControl(at: 100.35)
            let notice = try XCTUnwrap(root.subviews.compactMap { $0 as? NowPlayingNotice }.first)
            let menu = try XCTUnwrap(root.subviews.compactMap { $0 as? GameplayMenuButton }.first)
            func hit(_ point: CGPoint) -> NSView? { root.hitTest(root.convert(point, to: root.superview)) }
            XCTAssertTrue(area.contains(notice.frame))
            XCTAssertFalse(notice.frame.intersects(menu.frame))
            XCTAssertTrue(hit(CGPoint(x: notice.frame.midX, y: notice.frame.midY)) === root)
            XCTAssertTrue(hit(CGPoint(x: menu.frame.midX, y: menu.frame.midY)) === menu)
        }
    }

    func testRenderedCreditsAtMacPhoneTabletAndTVSizes() throws {
        guard let directory = ProcessInfo.processInfo.environment["LEMMINGS_TEST_MENU_ARTWORK"],
              let output = ProcessInfo.processInfo.environment["LEMMINGS_MUSIC_CARD_CAPTURES"] else { return }
        try FileManager.default.createDirectory(at: URL(fileURLWithPath: output), withIntermediateDirectories: true)
        let typography = try XCTUnwrap(GameMenuTypography(directory: URL(fileURLWithPath: directory)))
        for (device, width, height) in [("mac", CGFloat(600), CGFloat(210)), ("phone", 300, 140),
                                       ("landscape-phone", 480, 80), ("tablet", 560, 180), ("tv", 600, 210)] {
            for (state, song, credits) in [("short", "Intro", "Lemmings - Amiga"), ("long", title, source)] {
                let layout = MusicTitleCard.layout(title: song, soundtrack: credits, maximumWidth: width, maximumHeight: height)
                var elapsed: TimeInterval = 0
                for (index, page) in layout.pages.enumerated() {
                    let context = try XCTUnwrap(CGContext(data: nil, width: Int(layout.size.width), height: Int(layout.size.height),
                        bitsPerComponent: 8, bytesPerRow: Int(layout.size.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                    context.translateBy(x: 0, y: layout.size.height); context.scaleBy(x: 1, y: -1)
                    MusicTitleCard.draw(layout, elapsed: elapsed, typography: typography, in: context)
                    let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(context.makeImage()))
                    try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(
                        to: URL(fileURLWithPath: output).appendingPathComponent("\(device)-\(state)-\(index).png"))
                    elapsed += page.duration
                }
            }
        }
    }
}
#endif
