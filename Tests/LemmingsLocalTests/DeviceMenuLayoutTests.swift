#if os(macOS)
import AppKit
import ImageIO
import LemmingsGameArt
import NxlvKit
import XCTest
@testable import LemmingsLocal

final class DeviceMenuLayoutTests: XCTestCase {
    @MainActor func testAmigaVersusWarningFitsBriefingAndLevelSelection() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let art = try ClassicMacArtwork(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings"))
        let typography = try XCTUnwrap(GameMenuTypography(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings")))
        let warning = try XCTUnwrap(AmigaVersusCampaign.controllerRequirement(rank: "Lemmings Versus"))
        let output = root.appendingPathComponent(".build/versus-warning-ui")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for width in [640, 1120] {
            let field = PlayfieldView(frame: .init(x: 0, y: 0, width: width, height: 720))
            field.interfaceArtwork = art; field.macArtwork = art; field.phase = .briefing
            field.overlayTitle = "The Rubbish Dump"
            field.overlayLines = ["80 Lemmings", "Save 40 (50%)", "Release rate 50", "Time 5:00"] + AmigaVersusCampaign.controllerRequirementLines(rank: "Lemmings Versus")
            field.overlayFooter = "Lemmings Versus 1  -  Click or space to begin"
            let bitmap = try XCTUnwrap(field.bitmapImageRepForCachingDisplay(in: field.bounds))
            field.displayIgnoringOpacity(field.bounds, in: try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap)))
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent("mac-\(width).png"))
            let controls = field.accessibleControls(owner: field).compactMap { $0 as? GameAccessibleElement }
            for line in AmigaVersusCampaign.controllerRequirementLines(rank: "Lemmings Versus") {
                let target = try XCTUnwrap(controls.first { $0.accessibilityLabel() == line })
                XCTAssertTrue(field.bounds.contains(target.localFrame))
            }
        }
        for width in [390, 1120] {
            let page = GameFrontEnd.Page(title: "The Rubbish Dump", subtitle: "Lemmings Versus 1",
                details: ["80 Lemmings   Save 40", "Time 5:00", warning],
                footer: [.init("back", "Back"), .init("play", "Play", primary: true)], preview: true, footerColumns: 2)
            let layout = GameFrontEnd.layout(page, width: CGFloat(width), minimumHeight: 720)
            for target in layout.targets {
                XCTAssertEqual(layout.action(at: .init(x: target.frame.midX, y: target.frame.midY)), target.action.id)
            }
            let image = try XCTUnwrap(CGContext(data: nil, width: Int(layout.size.width), height: Int(layout.size.height),
                bitsPerComponent: 8, bytesPerRow: Int(layout.size.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            image.translateBy(x: 0, y: layout.size.height); image.scaleBy(x: 1, y: -1)
            GameFrontEnd.draw(page, layout: layout, typography: typography, highlighted: "play", in: image)
            let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(output.appendingPathComponent("shared-\(width).png") as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(destination, try XCTUnwrap(image.makeImage()), nil)
            XCTAssertTrue(CGImageDestinationFinalize(destination))
        }
    }

    @MainActor func testHomeWithoutJourneyHasOnlyCurrentSessionTargets() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let typography = try XCTUnwrap(GameMenuTypography(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings")))
        let art = try ClassicMacArtwork(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings"))
        let output = root.appendingPathComponent(".build/journey-session-ui")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for width in [390, 1120] {
            let page = MobileHomeArt.page(journey: nil, families: [.init("classic", "Classic"), .init("l2", "Lemmings 2"), .init("l3", "Lemmings 3")], initials: "ALICE v BOB")
            let layout = GameFrontEnd.layout(page, width: CGFloat(width), minimumHeight: 720)
            XCTAssertFalse(layout.targets.contains { $0.action.id == "journey" })
            for target in layout.targets where target.action.enabled {
                XCTAssertEqual(layout.action(at: .init(x: target.frame.midX, y: target.frame.midY)), target.action.id)
            }
            let image = try XCTUnwrap(CGContext(data: nil, width: Int(layout.size.width), height: Int(layout.size.height), bitsPerComponent: 8, bytesPerRow: Int(layout.size.width) * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            image.translateBy(x: 0, y: layout.size.height); image.scaleBy(x: 1, y: -1)
            GameFrontEnd.draw(page, layout: layout, typography: typography, highlighted: "classic", in: image)
            let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(output.appendingPathComponent("shared-\(width).png") as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(destination, try XCTUnwrap(image.makeImage()), nil)
            XCTAssertTrue(CGImageDestinationFinalize(destination))
        }
        let field = PlayfieldView(frame: .init(x: 0, y: 0, width: 1120, height: 720))
        field.interfaceArtwork = art; field.macArtwork = art; field.phase = .briefing
        field.overlayTitle = "LEMMINGS"; field.overlayShowsLemmings = true
        field.overlayHomeLeadingCount = 0
        field.overlayLines = ["CLASSIC LEMMINGS", "LEMMINGS 2", "LEMMINGS 3"]
        field.overlayProfileInitials = "ALICE v BOB"
        let bitmap = try XCTUnwrap(field.bitmapImageRepForCachingDisplay(in: field.bounds))
        field.displayIgnoringOpacity(field.bounds, in: try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap)))
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent("native.png"))
        let controls = field.accessibleControls(owner: field).compactMap { $0 as? GameAccessibleElement }
        XCTAssertFalse(controls.contains { ($0.accessibilityLabel() ?? "").contains("JOURNEY") })
        for label in field.overlayLines {
            let target = try XCTUnwrap(controls.first { $0.accessibilityLabel() == label })
            XCTAssertTrue(field.bounds.contains(target.localFrame))
        }
    }

    func testBookResultKeepsActionsLeftAndFullAchievementTextRight() {
        var page = GameFrontEnd.Page(title: "Level complete", subtitle: "Played: ALICE Fan-made / Ji Hoots Lemmings Remake Heaven Level 2",
            details: ["Cellbash", "Saved 10/10 Goal 1", "New time record 2:41.12"],
            footer: [.init("next", "Next: PLAYER TWO", primary: true), .init("retry", "Retry"), .init("back", "Back"),
                     .init("review", "Review"), .init("share", "Share movie"), .init("menu", "Menu")], preview: true)
        page.result = true
        let awards = MobileResultAchievementsArt.page([
            .init("First clear", detail: "First clear of this level. Rescued 10; target 1."),
            .init("+1 SUPERZOOM", detail: String(repeating: "Complete reward details. ", count: 10))])
        for setting in ClassicInterfaceSize.allCases {
            let pane = CGSize(width: 589, height: 786)
            let scale = MobileResultAchievementsArt.resultScale(MobileSettingsArt.interfaceScale(setting, width: pane.width),
                page: page, width: pane.width, height: pane.height)
            let result = GameFrontEnd.layout(page, width: pane.width / scale, minimumHeight: pane.height / scale, fillsResultPane: true)
            XCTAssertLessThanOrEqual(result.size.height * scale, pane.height + 0.5)
            XCTAssertEqual(Set(result.targets.map { $0.action.id }), Set(page.footer.map(\.id)))
            for target in result.targets {
                XCTAssertEqual(result.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)), target.action.id)
                XCTAssertGreaterThanOrEqual(target.frame.height * scale, 44)
            }
            let back = result.targets.first { $0.action.id == "back" }!.frame
            let next = result.targets.first { $0.action.id == "next" }!.frame
            XCTAssertEqual(back.minY, next.minY)
            XCTAssertLessThan(back.maxX, next.minX)
            let awardScale = MobileSettingsArt.interfaceScale(setting, width: pane.width)
            let right = GameFrontEnd.layout(awards, width: pane.width / awardScale, minimumHeight: pane.height / awardScale)
            XCTAssertEqual(right.details.count, awards.details.count)
            XCTAssertTrue(right.targets.isEmpty)
            for (index, frame) in right.details.enumerated() {
                XCTAssertTrue(right.board.contains(frame))
                XCTAssertGreaterThanOrEqual(frame.height, GameTextLayout.height(awards.details[index], width: frame.width))
            }
        }
    }

    func testTableResultKeepsPrimaryAndBackInsideUpperPaneAtEveryTextSize() {
        var page = GameFrontEnd.Page(title: "Level complete", subtitle: "Played: PLA Fan-made / Ji Hoots Lemmings Remake Heaven Level 2",
            details: ["Cellbash", "Saved 10/10 Goal 1", "New time record 2:41.12"],
            footer: [.init("next", "Next level", primary: true), .init("retry", "Retry"), .init("back", "Back"),
                     .init("review", "Review"), .init("share", "Share movie"), .init("menu", "Menu")], preview: true)
        page.result = true
        for setting in ClassicInterfaceSize.allCases {
            let width: CGFloat = 834, height: CGFloat = 565
            let scale = MobileResultAchievementsArt.resultScale(MobileSettingsArt.interfaceScale(setting, width: width),
                page: page, width: width, height: height)
            let layout = GameFrontEnd.layout(page, width: width / scale, minimumHeight: height / scale, fillsResultPane: true)
            XCTAssertLessThanOrEqual(layout.size.height * scale, height + 0.5)
            let back = layout.targets.first { $0.action.id == "back" }!.frame
            let next = layout.targets.first { $0.action.id == "next" }!.frame
            XCTAssertEqual(back.minY, next.minY)
            XCTAssertLessThan(back.maxX, next.minX)
            XCTAssertTrue(layout.targets.allSatisfy { $0.frame.maxY * scale <= height })
            XCTAssertEqual(layout.action(at: CGPoint(x: next.midX, y: next.midY)), "next")
        }
    }

    func testTableAchievementsPreserveFullTextAndStarStatesAtAllSizes() {
        let level = ArcadeLevel(id: "goal", title: "Test", game: "Classic", rules: "test", total: 10, required: 5)
        for (saved, won, expected) in [(0, false, [0, 0, 2]), (5, true, [1, 0, 2]),
                                      (6, true, [1, 1, 2]), (10, true, [1, 1, 1])] {
            let run = ArcadeRun(profileID: "PLA", level: level, saved: saved, didWin: won, skills: [:], seconds: 42)
            let items = MobileResultAchievementsArt.goals(.init(run: run, maximum: .init()))
                + [.init("A long earned achievement title", detail: String(repeating: "Full achievement description. ", count: 6))]
            XCTAssertEqual(items.prefix(3).compactMap(\.star), expected)
            let page = MobileResultAchievementsArt.page(items)
            for width: CGFloat in [280, 465, 596, 834, 1194] {
                let layout = GameFrontEnd.layout(page, width: width, minimumHeight: 549)
                XCTAssertTrue(layout.targets.isEmpty)
                XCTAssertEqual(layout.details.count, items.count * 2)
                for (index, frame) in layout.details.enumerated() {
                    XCTAssertTrue(layout.board.contains(frame))
                    XCTAssertGreaterThanOrEqual(frame.height, GameTextLayout.height(page.details[index], width: frame.width))
                    XCTAssertFalse(layout.details.dropFirst(index + 1).contains { frame.intersects($0) })
                }
            }
        }
    }

    func testLevelPreviewKeepsLibraryAndStartVisibleOnDuoPanes() {
        let page = GameFrontEnd.Page(title: "Just Dig!", subtitle: "Fun 1/30",
            details: ["10 Lemmings save 1", "Time 5:01"],
            footer: [.init("back", "Library"), .init("start", "Start", primary: true)], preview: true)
        for size in [CGSize(width: 589, height: 794), .init(width: 834, height: 549),
                     .init(width: 650, height: 425), .init(width: 465, height: 610)] {
            let layout = GameFrontEnd.layout(page, width: size.width, minimumHeight: size.height)
            XCTAssertEqual(layout.size.height, size.height)
            XCTAssertTrue(layout.targets.allSatisfy { CGRect(origin: .zero, size: size).contains($0.frame) })
            XCTAssertGreaterThanOrEqual(layout.preview.height, 80)
            let back = layout.targets.first { $0.action.id == "back" }!.frame
            let start = layout.targets.first { $0.action.id == "start" }!.frame
            XCTAssertLessThan(back.maxX, start.minX)
            XCTAssertEqual(back.minY, start.minY)
            XCTAssertEqual(layout.action(at: CGPoint(x: start.midX, y: start.midY)), "start")
        }
    }

    func testBookHomeUsesBothListsAndRetainsEveryAction() {
        let families = (0..<6).map { GameFrontEnd.Action("family.\($0)", "Classic Lemmings 0/120") }
            + [.init("l2", "Lemmings 2", gameLogo: .lemmings2), .init("l3", "Lemmings 3", gameLogo: .lemmings3)]
        for width: CGFloat in [650, 1194] {
            let hinge = CGRect(x: width / 2 - 8, y: 0, width: 16, height: 834)
            let panes = [CGRect(x: 0, y: 0, width: hinge.minX, height: 834),
                         CGRect(x: hinge.maxX, y: 0, width: width - hinge.maxX, height: 834)]
            let page = MobileHomeArt.page(resume: [.init("resume", "Resume Journey")],
                journey: .init("journey", "Journey map 1/227 solved"), families: families, initials: "ALICE v BOB")
            let layout = GameFrontEnd.layout(page, width: width, minimumHeight: 834, bookHomePanes: panes)
            XCTAssertNotNil(layout.secondaryBoard)
            XCTAssertNotNil(layout.libraryHeading)
            XCTAssertEqual(Set(layout.targets.map { $0.action.id }), Set((page.rows + page.footer).map(\.id)))
            XCTAssertEqual(layout.targets.filter { $0.action.primary }.count, 1)
            for pane in panes {
                XCTAssertTrue(layout.targets.contains { page.rows.contains($0.action) && pane.contains($0.frame) })
            }
            for (index, target) in layout.targets.enumerated() {
                XCTAssertFalse(target.frame.intersects(hinge))
                XCTAssertGreaterThanOrEqual(target.frame.width, 44)
                XCTAssertGreaterThanOrEqual(target.frame.height, 44)
                XCTAssertTrue(CGRect(origin: .zero, size: layout.size).contains(target.frame))
                XCTAssertEqual(layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)), target.action.id)
                XCTAssertFalse(layout.targets.dropFirst(index + 1).contains { target.frame.intersects($0.frame) })
            }
            XCTAssertNil(layout.action(at: CGPoint(x: hinge.midX, y: 400)))
        }
    }

    func testHomeLibrarySpacingSequelRowAndBalancedFooter() {
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
            // Four footer actions balance as two full rows of two, not three over one.
            let footer = layout.targets.filter { ["players", "records", "collections", "donate"].contains($0.action.id) }
            XCTAssertEqual(footer.count, 4)
            let footerRows = Dictionary(grouping: footer, by: { $0.frame.minY })
            XCTAssertEqual(footerRows.count, 2)
            XCTAssertTrue(footerRows.values.allSatisfy { $0.count == 2 && abs($0[0].frame.width - $0[1].frame.width) < 0.01 })
            for target in layout.targets {
                XCTAssertEqual(layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)), target.action.id)
            }
        }
    }

    func testPlayerTitleAndQuantityRolesDoNotDependOnSelection() {
        let page = MobileTurnArt.page(.init(title: "Lemmings", home: true), playerName: "UVA", role: .next, sessionName: "UVA v EKV")
        XCTAssertEqual(page.subtitle, "")
        XCTAssertEqual(page.homeNextPlayerIndex, 0)
        XCTAssertEqual(page.homeNextPlayerName, "UVA")
        XCTAssertEqual(GameSemanticText.players(page.homeInitials, nextPlayerIndex: page.homeNextPlayerIndex).map(\.palette),
            [.gold, .blue, .green])
        let otherTurn = MobileHomeArt.page(journey: nil, families: [.init("classic", "Classic")], initials: "EKV v UVA",
            nextPlayerIndex: 1, subtitle: "Saved")
        XCTAssertEqual(otherTurn.subtitle, "Saved")
        XCTAssertEqual(otherTurn.homeNextPlayerName, "UVA")
        XCTAssertEqual(GameSemanticText.players(otherTurn.homeInitials,
            nextPlayerIndex: otherTurn.homeNextPlayerIndex).map(\.palette), [.green, .blue, .gold])
        let phone = GameFrontEnd.layout(otherTurn, width: 390, minimumHeight: 763)
        XCTAssertLessThan(phone.initials.maxY, phone.targets.first { $0.action.id == "classic" }!.frame.minY)
        let book = MobileBookHomeArt.layout(otherTurn, width: 650, height: 465,
            panes: [CGRect(x: 0, y: 0, width: 318, height: 465),
                    CGRect(x: 332, y: 0, width: 318, height: 465)])
        XCTAssertLessThan(book.initials.maxY, book.targets.first { $0.action.id == "classic" }!.frame.minY)
        XCTAssertLessThan(book.initials.maxY, 465)
        let solo = MobileHomeArt.page(journey: nil, families: [], initials: "EKV", subtitle: "Saved")
        XCTAssertEqual(solo.subtitle, "Saved")
        XCTAssertNil(solo.homeNextPlayerName)
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
                XCTAssertTrue(field.activateHomeSelection(field.overlayLines.count + 4)); XCTAssertTrue(settings)
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
