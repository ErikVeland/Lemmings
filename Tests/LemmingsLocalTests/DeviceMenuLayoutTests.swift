#if os(macOS)
import AppKit
import LemmingsGameArt
import NxlvKit
import XCTest
@testable import LemmingsLocal

final class DeviceMenuLayoutTests: XCTestCase {
    func testHomeLibrarySpacingSequelRowAndThreeColumnFooter() {
        let libraries = (0..<6).map { GameFrontEnd.Action("family.\($0)", "Library \($0) 0/120") }
            + [.init("l2", "Lemmings 2", gameLogo: .lemmings2), .init("l3", "Lemmings 3", gameLogo: .lemmings3)]
        for size in [CGSize(width: 1194, height: 834), .init(width: 834, height: 1194), .init(width: 740, height: 430)] {
            let page = MobileHomeArt.page(resume: [.init("journeyResume", "Resume journey"), .init("resume", "Resume level - UVA")],
                journey: .init("journey", "Journey map 33/295 solved"), families: libraries, initials: "UVA v EKV")
            let layout = GameFrontEnd.layout(page, width: size.width, minimumHeight: size.height)
            XCTAssertTrue(page.rows.first { $0.id == "journey" }!.titleRuns.allSatisfy { $0.palette == .blue })
            let grid = layout.targets.filter { $0.action.id.hasPrefix("family.") }
            XCTAssertEqual(grid[1].frame.minX - grid[0].frame.maxX, 12, accuracy: 0.001)
            XCTAssertEqual(grid[2].frame.minY - grid[0].frame.maxY, 12, accuracy: 0.001)
            let sequels = layout.targets.filter { $0.action.gameLogo != nil }
            XCTAssertEqual(sequels.count, 2)
            XCTAssertTrue(sequels.allSatisfy { $0.frame.minY > grid.last!.frame.maxY && $0.frame.height == 112 })
            let footer = layout.targets.filter { ["players", "records", "collections"].contains($0.action.id) }
            XCTAssertEqual(footer.count, 3)
            XCTAssertEqual(Set(footer.map { $0.frame.minY }).count, 1)
            for target in layout.targets {
                XCTAssertEqual(layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)), target.action.id)
            }
        }
    }

    func testPlayerTitleAndQuantityRolesDoNotDependOnSelection() {
        let page = MobileTurnArt.page(.init(title: "Lemmings", home: true), playerName: "UVA", role: .next, sessionName: "UVA v EKV")
        XCTAssertEqual(page.subtitleRuns.filter { $0.palette == .green }.map(\.text), ["UVA", "EKV", "UVA"])
        XCTAssertTrue(page.subtitleRuns.contains { $0.text == " v " && $0.palette == .blue })
        XCTAssertTrue(page.subtitleRuns.contains { $0.text.contains("Next:") && $0.palette == .blue })
        let title = GameSemanticText.title("Classic Lemmings 0/120")
        XCTAssertEqual(title.map(\.palette), [.green, .blue])
        XCTAssertEqual(title.last?.text, "0/120")
        XCTAssertEqual(GameSemanticText.resume("Resume level - AB2").last?.palette, .green)
        XCTAssertEqual(GameSemanticText.named("UVA: next", name: "UVA").first?.palette, .green)
        XCTAssertEqual(GameSemanticText.players("UVA VS EKV").map(\.text), ["UVA", " v ", "EKV"])
    }

    func testPortraitPhoneHomeUsesFullWidthRowsAndOddTabletRowsSpanTheGrid() {
        for width: CGFloat in [320, 390, 430, 540, 834] {
            for count in 1...9 {
                let rows = (0..<count).map { GameFrontEnd.Action("family.\($0)", "Library \($0)") }
                let page = GameFrontEnd.Page(title: "Lemmings", home: true, rows: rows,
                    footer: [.init("players", "Profiles"), .init("records", "Records"), .init("collections", "Collections")])
                let layout = GameFrontEnd.layout(page, width: width, minimumHeight: 900)
                let targets = layout.targets.filter { rows.contains($0.action) }
                if width < 600 {
                    XCTAssertEqual(Set(targets.map { $0.frame.minY }).count, count)
                    XCTAssertTrue(targets.allSatisfy { $0.frame.width == layout.board.width - 24 })
                }
                for row in Dictionary(grouping: targets, by: { $0.frame.minY }).values where row.count == 1 {
                    XCTAssertEqual(row[0].frame.width, layout.board.width - 24)
                }
            }
        }
    }

    func testTwoColumnActionShelvesFillEverySingleButtonRow() {
        for count in 1...9 {
            for back in [false, true] {
                var actions = (0..<count).map { GameFrontEnd.Action("action.\($0)", "Action \($0)", primary: $0 == count - 1) }
                if back { actions[0] = .init("back", "Back") }
                for result in [false, true] {
                    var page = GameFrontEnd.Page(title: "Actions", footer: actions, footerColumns: 2)
                    page.result = result
                    let layout = GameFrontEnd.layout(page, width: 390, minimumHeight: 700)
                    for row in Dictionary(grouping: layout.targets, by: { $0.frame.minY }).values where row.count == 1 {
                        XCTAssertEqual(row[0].frame.minX, layout.board.minX + 20)
                        XCTAssertEqual(row[0].frame.maxX, layout.board.maxX - 20)
                    }
                }
            }
        }
    }

    @MainActor func testMacHomeArtworkMouseTargetsAndCompactScrolling() throws {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let art = try ClassicMacArtwork(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings"))
        let output = root.appendingPathComponent(".build/device-layout-native")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let families = ["CLASSIC LEMMINGS  93/120", "OH NO! MORE LEMMINGS  45/100", "HOLIDAY LEMMINGS  17/72",
            "OH YES! MORE LEMMINGS  20/60", "FAN LEMMINGS  12/15000", "NEOLEMMIX  4/500", "LEMMINGS 2  0/120", "LEMMINGS 3  0/90 - BETA", "COLLECTIONS"]
        for size in [CGSize(width: 640, height: 480), .init(width: 900, height: 600), .init(width: 1120, height: 720),
                     .init(width: 1600, height: 900), .init(width: 2560, height: 1600)] {
            for saved in 0...2 {
                let field = PlayfieldView(frame: CGRect(origin: .zero, size: size))
                field.interfaceArtwork = art; field.macArtwork = art; field.phase = .briefing
                field.overlayTitle = "LEMMINGS"; field.overlayShowsLemmings = true
                field.overlayHomeLeadingCount = saved + 1
                field.overlayLines = Array(["CONTINUE JOURNEY - ALICE v BOB", "RESUME LEVEL - ALICE"].prefix(saved))
                    + ["JOURNEY  29/295 SOLVED"] + families
                field.overlayProfileInitials = saved == 0 ? "LEM" : "ALICE v BOB"
                field.overlaySavedCounts = "LEMMINGS SAVED  1239"
                field.overlayShowsSettingsButton = true; field.overlayAvailableUpdate = "Version 2.0"
                field.overlayHighlight = 0
                var selected: Int?, settings = false, update = false, profiles = false
                field.onSelectOverlayLine = { selected = $0 }; field.onSettings = { settings = true }
                field.onUpdate = { update = true }; field.onProfiles = { profiles = true }
                func capture(_ state: String) throws -> [GameAccessibleElement] {
                    let bitmap = try XCTUnwrap(field.bitmapImageRepForCachingDisplay(in: field.bounds))
                    field.displayIgnoringOpacity(field.bounds, in: try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap)))
                    try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to:
                        output.appendingPathComponent("mac-\(Int(size.width))-\(saved)-\(state).png"))
                    return field.accessibleControls(owner: field).compactMap { $0 as? GameAccessibleElement }
                }
                func click(_ element: GameAccessibleElement) {
                    field.handleClick(at: CGPoint(x: element.localFrame.midX, y: element.localFrame.midY))
                }
                var elements = try capture("home")
                XCTAssertEqual(field.homeSelection(from: saved + 1, direction: "right"), saved + 2)
                XCTAssertEqual(field.homeSelection(from: saved + 2, direction: "left"), saved + 1)
                XCTAssertEqual(field.homeSelection(from: saved + 1, direction: "down"), saved + 3)
                for label in ["Settings", "Version 2.0. Show update and release notes", field.overlayLines[0]] {
                    let element = try XCTUnwrap(elements.first { $0.accessibilityLabel() == label })
                    XCTAssertTrue(field.bounds.contains(element.localFrame)); click(element)
                }
                XCTAssertTrue(settings); XCTAssertTrue(update); XCTAssertEqual(selected, 0)
                field.overlayHighlight = field.overlayLines.count - 1
                elements = try capture("selected-last")
                let last = try XCTUnwrap(elements.first { $0.accessibilityLabel() == "COLLECTIONS" })
                XCTAssertTrue(field.bounds.contains(last.localFrame)); click(last)
                XCTAssertEqual(selected, field.overlayLines.count - 1)
                let footerChoice = try XCTUnwrap(field.homeSelection(from: field.overlayLines.count - 1, direction: "down"))
                XCTAssertGreaterThanOrEqual(footerChoice, field.overlayLines.count)
                XCTAssertTrue(field.activateHomeSelection(field.overlayLines.count)); XCTAssertTrue(profiles)
                XCTAssertTrue(field.activateHomeSelection(field.overlayLines.count + 3)); XCTAssertTrue(settings)
                field.overlayHighlight = footerChoice
                _ = try capture("keyboard-footer")
                let event = try XCTUnwrap(NSEvent(cgEvent: try XCTUnwrap(CGEvent(scrollWheelEvent2Source: nil,
                    units: .pixel, wheelCount: 1, wheel1: -2000, wheel2: 0, wheel3: 0))))
                field.handleScroll(event, at: .init(x: 100, y: 100))
                elements = try capture("footer")
                let profile = try XCTUnwrap(elements.first { $0.accessibilityLabel() == "Player profiles" })
                XCTAssertTrue(field.bounds.contains(profile.localFrame)); click(profile); XCTAssertTrue(profiles)
                let savedCount = try XCTUnwrap(elements.first { $0.accessibilityLabel() == "LEMMINGS SAVED  1239" })
                XCTAssertFalse(savedCount.localFrame.intersects(profile.localFrame))
            }
        }
    }
}
#endif
