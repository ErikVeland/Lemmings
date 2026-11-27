#if os(macOS)
import AppKit
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit
import XCTest

final class DestinationLocalisationTests: XCTestCase {
    @MainActor func testTranslatedDestinationsKeepNamesBackRolesAndTargets() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let typography = try XCTUnwrap(GameMenuTypography(directory: root.appendingPathComponent(".build/mac-artwork/export/lemmings")))
        let output = root.appendingPathComponent(".build/ux-terms/renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let original = GameLocalisation.currentLanguagePreference
        defer { GameLocalisation.setLanguage(original) }
        let profiles = MobileProfiles()
        let host = profiles.activeID
        for language in InterfaceLanguage.allCases where language != .english && language != .system {
            GameLocalisation.setLanguage(language)
            XCTAssertEqual(GameLocalisation.interface.language, language.rawValue)
            let journey = MobileHomeArt.journeyAction(run: nil)
            XCTAssertNotEqual(journey.title, "Start journey")
            let home = MobileHomeArt.page(continueAction: journey, initials: "UVA")
            let play = MobileHomeArt.playPage(journey: journey, families: [])
            let profile = MobileCareerArt.progressPage(records: ArcadeRecords(), profileID: host, profileName: "UVA", subtitle: "")
            let community = MobileCareerArt.leaderboards(world: false, category: .stars, rows: [], busy: false, status: "", sharing: nil, gameCenter: false)
            let seat = MobileCareerArt.hotSeat(profiles, subtitle: "", roster: .init(host: host), policy: .everyLevel, active: false, hasSaved: true)
            let settings = MobileSettingsArt.groups()
            XCTAssertEqual(home.rows.map(\.title), [journey.title, seat.title, play.title, profile.title, community.title])
            XCTAssertEqual(home.footer.first?.title, settings.title)
            XCTAssertNil(home.backAction)
            let pages = [("home", home), ("play", play), ("profile", profile), ("community", community), ("seat", seat), ("settings", settings)]
            for (name, page) in pages {
                if !page.home { XCTAssertEqual(page.backAction?.title, GameLocalisation.text("Back")) }
                let layout = GameFrontEnd.layout(page, width: 390, minimumHeight: 650)
                if page.home || page.gameLibrary {
                    var loadingPage = page
                    loadingPage.subtitle = GameLocalisation.text("Loading...")
                    let loadingLayout = GameFrontEnd.layout(loadingPage, width: 390, minimumHeight: 650)
                    XCTAssertEqual(layout.targets.map(\.frame), loadingLayout.targets.map(\.frame))
                    if page.gameLibrary {
                        XCTAssertGreaterThanOrEqual(layout.heading.width, GameTextLayout.width(of: page.title, face: .large))
                    }
                }
                for target in layout.targets {
                    XCTAssertFalse(target.action.title.isEmpty)
                    XCTAssertEqual(layout.action(at: .init(x: target.frame.midX, y: target.frame.midY)),
                                   target.action.enabled ? target.action.id : nil, "\(language.rawValue) \(name) \(target.action.id)")
                }
                let context = try XCTUnwrap(CGContext(data: nil, width: Int(ceil(layout.size.width)), height: Int(ceil(layout.size.height)), bitsPerComponent: 8,
                    bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.translateBy(x: 0, y: layout.size.height)
                context.scaleBy(x: 1, y: -1)
                GameFrontEnd.draw(page, layout: layout, typography: typography, highlighted: page.rows.first(where: \.enabled)?.id, in: context)
                let bitmap = try XCTUnwrap(context.makeImage())
                try XCTUnwrap(NSBitmapImageRep(cgImage: bitmap).representation(using: .png, properties: [:]))
                    .write(to: output.appendingPathComponent("\(language.rawValue)-\(name).png"))
            }
        }
    }
}
#endif
