import Foundation
import CoreGraphics
import ImageIO
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

@main struct MenuAudit {
    static func invalidTargets(line: Int) -> Failure {
        FileHandle.standardError.write(Data("Invalid menu targets at line \(line)\n".utf8))
        return .invalidTargets
    }
    @MainActor static func main() async throws {
        let sharing = CommandLine.arguments.last == "--sharing"
        let muteSetting = CommandLine.arguments.last == "--mute-setting"
        let tableResult = ["--table-result", "--book-result"].contains(CommandLine.arguments.last ?? "")
        let extraSkill = CommandLine.arguments.last == "--extra-skill"
        let roundedHUD = CommandLine.arguments.last == "--rounded-hud"
        let bookHome = CommandLine.arguments.last == "--book-home"
        let support = CommandLine.arguments.last == "--support"
        let duo = CommandLine.arguments.last == "--duo"
        let staticHome = CommandLine.arguments.last == "--static-home"
        let hierarchy = CommandLine.arguments.last == "--hierarchy"
        let pause = CommandLine.arguments.last == "--pause"
        let ghostSolution = CommandLine.arguments.last == "--ghost-solution"
        let solutionSwitch = CommandLine.arguments.last == "--solution-switch"
        let skillPause = CommandLine.arguments.last == "--skill-pause"
        let latestFixes = ["--current-fixes", "--rescue-budget"].contains(CommandLine.arguments.last ?? "")
        let hotSeat = CommandLine.arguments.last == "--hot-seat"
        let hotSeatFlow = CommandLine.arguments.last == "--hot-seat-flow"
        let hotSeatHUD = CommandLine.arguments.last == "--hot-seat-hud"
        let bundledGames = CommandLine.arguments.last == "--bundled-games"
        let buildChanges = CommandLine.arguments.last == "--build-changes"
        let navigation = CommandLine.arguments.last == "--navigation"
        let homeScenery = CommandLine.arguments.last == "--home-scenery"
        let regionalBrand = CommandLine.arguments.last == "--regional-brand"
        guard CommandLine.arguments.count == (sharing || muteSetting || extraSkill || tableResult || roundedHUD || bookHome || support || duo || staticHome || hierarchy || pause || ghostSolution || solutionSwitch || skillPause || latestFixes || hotSeat || hotSeatHUD || hotSeatFlow || bundledGames || buildChanges || navigation || homeScenery || regionalBrand ? 5 : 4) else { throw Failure.invalidArguments }
        let artwork = URL(fileURLWithPath: CommandLine.arguments[1])
        let content = URL(fileURLWithPath: CommandLine.arguments[2])
        let output = URL(fileURLWithPath: CommandLine.arguments[3])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        guard let typography = GameMenuTypography(directory: artwork),
              typography.interface.logo != nil,
              typography.font(.small) != nil, typography.font(.large) != nil else { throw Failure.missingArtwork }
        if sharing { try checkSharingPrivacy(typography: typography, output: output); return }
        if muteSetting { try checkMuteSetting(typography: typography, output: output); return }
        if tableResult { try checkTableResult(typography: typography, content: content, output: output); return }
        if extraSkill { try checkExtraSkill(typography: typography, output: output); return }
        if roundedHUD { try checkRoundedHUD(typography: typography, content: content, output: output); return }
        if bookHome { try checkBookHome(typography: typography, content: content, output: output); return }
        if support { try checkSupport(typography: typography, output: output); return }
        if duo { try checkDuo(typography: typography, content: content, output: output); return }
        if staticHome { try checkStaticHome(typography: typography, output: output); return }
        if regionalBrand { try checkRegionalBrand(typography: typography, resources: content, output: output); return }
        if homeScenery { try await checkHomeScenery(typography: typography, content: content, output: output); return }
        if buildChanges { try checkBuildChanges(typography: typography, manifest: content, output: output); return }
        if navigation { try checkNavigation(typography: typography, output: output); return }
        if skillPause { try checkSkillPause(typography: typography, output: output); return }
        let library = try ClassicMobileLibrary(directory: content)
        guard try library.checkpointLevelIdentifier(at: 0) == library.loadLevel(at: 0).session.levelIdentifier
        else { throw invalidTargets(line: #line) }
        if hierarchy { try checkHierarchy(library: library, typography: typography, output: output); return }
        if pause { try checkPause(library: library, typography: typography, output: output); return }
        if ghostSolution { try checkGhostSolution(library: library, typography: typography,
            resources: artwork.deletingLastPathComponent().deletingLastPathComponent(), output: output); return }
        if solutionSwitch { try checkSolutionSwitch(library: library, typography: typography,
            resources: artwork.deletingLastPathComponent().deletingLastPathComponent(), output: output); return }
        if hotSeatFlow { try await checkHotSeatFlow(typography: typography, output: output); return }
        if hotSeatHUD { try checkHotSeatHUD(library: library, typography: typography, portraits: GamePortraitArt(directory: artwork), output: output); return }
        if hotSeat { try checkHotSeat(typography: typography, portraits: GamePortraitArt(directory: artwork), output: output); return }
        if latestFixes { try await checkCurrentFixes(library: library, typography: typography, output: output); return }
        let session = try library.loadLevel(at: 0).session
        let bitmap = try session.render(highlight: nil)
        guard let image = MobileBitmapRenderer.image(bitmap) else { throw Failure.missingArtwork }
        let previewSource = CGRect(x: session.initialCameraOrigin.x, y: 0, width: 320, height: 160)
        typealias Action = GameFrontEnd.Action
        let homeFamilies: [Action] = [.init("family.classic", "Classic Lemmings  0/120"),
            .init("family.ohNo", "Oh No! More Lemmings  0/100"),
            .init("family.holiday", "Holiday Lemmings  0/72"),
            .init("family.ohYes", "Oh Yes! More Lemmings  0/60"),
            .init("family.fan", "Fan Lemmings  0/15000"),
            .init("neolemmix", "NeoLemmix Preview"),
            .init("l2", "Lemmings 2  120 levels"),
            .init("l3", "Lemmings 3 Preview  90 levels")]
        let journey = Action("journey", "Journey  29/295 solved")
        let home = MobileHomeArt.page(journey: journey, families: homeFamilies, initials: "LEM")
        let resumedHome = MobileHomeArt.page(resume: [.init("resume", "Resume - AB v CD")],
            journey: journey, families: homeFamilies, initials: "AB v CD")
        guard home.rows.map(\.id) == ["journey", "family.classic", "family.ohNo", "family.holiday",
            "family.ohYes", "family.fan", "neolemmix", "l2", "l3"],
            home.footer.map(\.id) == ["players", "records", "collections", "donate", "settings", "whatsNew"],
            home.footer.prefix(3).map(\.title) == ["Players", "Progress", "Playlists"]
            else { throw Failure.invalidTargets }
        var pages: [(String, GameFrontEnd.Page)] = [
            ("long-title", .init(title: library.levels.max(by: { $0.title.count < $1.title.count })!.title,
                                subtitle: "Mayhem", footer: [.init("home", "Back"), .init("play", "Play again", primary: true)], preview: true)),
            ("home", home),
            ("journey-resume", MobileHomeArt.page(resume: [.init("learningRunResume", "Resume journey")],
                journey: journey, families: homeFamilies, initials: "UVA")),
            ("journey-separate-level", MobileHomeArt.page(resume: [.init("learningRunResume", "Resume journey"),
                .init("resume", "Resume level - UVA")], journey: journey, families: homeFamilies, initials: "UVA")),
            ("resume", resumedHome),
            ("levels", .init(title: "Just Dig!", subtitle: "Fun 1/30", details: ["10 Lemmings   Save 10", "Time 5:00"],
                             footer: [.init("rankPrevious", "< Rank"), .init("rankNext", "Rank >"),
                                      .init("previous", "< Level", enabled: false), .init("next", "Level >"),
                                      .init("home", "Back"), .init("play", "Play", primary: true)], preview: true, footerColumns: 2)),
            ("briefing", .init(title: "Just Dig!", subtitle: "Fun 1", details: ["10 Lemmings   Save 10", "Time 5:00"],
                               footer: [.init("0", "Start", primary: true), .init("1", "Library")], preview: true)),
            ("pause", .init(title: "Paused", subtitle: "Fun 1  Just Dig!",
                            footer: [.init("0", "Resume", primary: true), .init("1", "Library")])),
            ("win", .init(title: "Level complete", subtitle: "Fun 1  Just Dig!", details: ["Saved 10 of 10", "Required 10"],
                          footer: [.init("0", "Next level", primary: true), .init("1", "Retry"), .init("2", "Library")], preview: true)),
            ("loss", .init(title: "Try again", subtitle: "Fun 1  Just Dig!", details: ["Saved 4 of 10", "Required 10"],
                           footer: [.init("0", "Retry", primary: true), .init("1", "Library")], preview: true)),
            ("settings", MobileSettingsArt.groups()),
            ("data", .init(title: "Game Data", details: ["Lemmings", "120 levels"],
                           footer: [.init("home", "Back"), .init("import", "Import")])),
            ("empty", .init(title: "Game Data", footer: [.init("home", "Back"), .init("import", "Import", primary: true)])),
        ]
        pages += MobileSettingsGroup.allCases.map {
            ("settings-" + $0.rawValue, MobileSettingsArt.page($0, settings: MobileSettings()))
        }
        pages.append(("settings-controller-remap", MobileSettingsArt.controllerMappings(MobileSettings())))
        let insightCounts = ["starts": 120, "wins": 80, "fails": 30, "abandoned": 10,
                             "saved": 560, "solo": 70, "hotSeat": 50, "music": 1, "downloads": 1]
        pages += [("effects-welcome", MobileInformationArt.effectsWelcome()),
                  ("whats-new", MobileInformationArt.whatsNew(version: "2.0")),
                  ("telemetry-consent", MobileInformationArt.telemetryConsent()),
                  ("insights-local", MobileInformationArt.insights(counts: insightCounts, shared: false, days: 30, sharingAvailable: false)),
                  ("insights-shared", MobileInformationArt.insights(counts: insightCounts, shared: true, days: 7, sharingAvailable: true)),
                  ("insights-token", MobileInformationArt.insightsToken(length: 12)),
                  ("insights-clear", MobileInformationArt.insightsClear())]
        for index in pages.indices where ["win", "loss"].contains(pages[index].0) { pages[index].1.result = true }
        var crowdedResult = GameFrontEnd.Page(title: "Level complete", subtitle: "Played: ALICE  Fun 1",
            rows: [.init("resultAward", "Every lemming counts  (1/8)")],
            details: ["A long level title with room to breathe", "Saved 80/80   Goal 40", "New time record  2:13.42"],
            footer: [.init("next", "Next: BOB", primary: true), .init("retry", "Retry: ALICE"),
                     .init("retryNext", "Retry: BOB"), .init("library", "Library"),
                     .init("review", "Review"), .init("share", "Share movie")], preview: true)
        crowdedResult.result = true
        pages.append(("result-all-awards", crowdedResult))
        pages += try careerPages()
        let portraits = GamePortraitArt(directory: artwork)
        guard (0..<8).allSatisfy({ portraits?.image($0) != nil }) else { throw Failure.missingArtwork }
        if bundledGames {
            let missingFamilies = homeFamilies.map { action -> Action in
                switch action.id {
                case "l2": .init(action.id, "Import Lemmings 2 data")
                case "l3": .init(action.id, "Import Lemmings 3 data")
                case "neolemmix": .init(action.id, "Import NeoLemmix data")
                default: action
                }
            }
            pages = [("bundled-home", home),
                     ("missing-home", MobileHomeArt.page(journey: journey, families: missingFamilies, initials: "LEM"))]
        }
        var evidence: [[String: Any]] = []
        let devices = [("ipad-8-portrait", CGSize(width: 810, height: 1040)),
                               ("ipad-8-landscape", CGSize(width: 1080, height: 770)),
                               ("ipad-8-large", CGSize(width: 720, height: 513)),
                               ("ipad-portrait", CGSize(width: 834, height: 1092)),
                               ("ipad-landscape", CGSize(width: 1112, height: 814)),
                               ("iphone-portrait", CGSize(width: 390, height: 763)),
                               ("iphone-landscape", CGSize(width: 756, height: 369)),
                               ("iphone-narrow-portrait", CGSize(width: 320, height: 548)),
                       ("iphone-narrow-landscape", CGSize(width: 568, height: 300))]
            + (bundledGames ? [("tv", CGSize(width: 1920, height: 1080))] : [])
        for (device, size) in devices {
            for (state, page) in pages {
                let layout = GameFrontEnd.layout(page, width: size.width, minimumHeight: size.height)
                guard Set(layout.targets.map { $0.action.id }).count == layout.targets.count,
                      layout.targets.filter({ $0.action.primary && $0.action.enabled }).count <= 1 else { throw Failure.invalidTargets }
                if !page.home, let primary = layout.targets.first(where: {
                    $0.action.primary && !["BACK", "CANCEL"].contains($0.action.title.uppercased())
                        && page.footer.contains($0.action)
                }) {
                    guard layout.targets.allSatisfy({ $0.frame.maxY <= primary.frame.maxY }),
                          abs(primary.frame.maxX - (layout.board.maxX - (page.pause != nil ? 16 : 20))) < 1.01,
                          footerNavigationIsValid(page, layout: layout)
                    else { throw Failure.invalidTargets }
                }
                for target in layout.targets {
                    let scrollY = min(max(0, layout.size.height - size.height), max(0, target.frame.midY - size.height / 2))
                    let viewport = CGRect(x: 0, y: scrollY, width: size.width, height: size.height)
                    guard target.frame.width >= 44, target.frame.height >= 44,
                          CGRect(origin: .zero, size: layout.size).contains(target.frame),
                          viewport.contains(target.frame),
                          layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == (target.action.enabled ? target.action.id : nil)
                    else { throw Failure.invalidTargets }
                }
                if page.home {
                    let settings = layout.targets.first { $0.action.id == "settings" }!.frame
                    let first = layout.targets.first!.frame
                    let profiles = layout.targets.first { $0.action.id == "players" }!.frame
                    guard settings.maxY <= first.minY, profiles.minY >= layout.targets[page.rows.count - 1].frame.maxY,
                          layout.heading.intersection(settings).isEmpty else { throw Failure.invalidTargets }
                    for target in layout.targets where ["players", "records", "playlists"].contains(target.action.id) {
                        guard typography.width(of: target.action.title.uppercased(), face: .small, scale: 1) <= target.frame.width - 24
                            else { throw Failure.invalidTargets }
                    }
                }
                guard layout.action(at: CGPoint(x: layout.board.minX + 1, y: layout.board.midY)) == nil else { throw Failure.invalidTargets }
                for (index, target) in layout.targets.enumerated() {
                    for other in layout.targets.dropFirst(index + 1) where target.frame.intersects(other.frame) { throw Failure.invalidTargets }
                }
                guard let context = CGContext(data: nil, width: Int(layout.size.width), height: Int(layout.size.height),
                                               bitsPerComponent: 8, bytesPerRow: Int(layout.size.width) * 4,
                                               space: CGColorSpaceCreateDeviceRGB(),
                                               bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.missingArtwork }
                context.translateBy(x: 0, y: layout.size.height); context.scaleBy(x: 1, y: -1)
                GameFrontEnd.draw(page, layout: layout, typography: typography, preview: image,
                                 previewSource: previewSource, portraits: portraits, in: context)
                guard let result = context.makeImage() else { throw Failure.missingArtwork }
                let file = output.appendingPathComponent("\(device)-\(state).png")
                guard let destination = CGImageDestinationCreateWithURL(file as CFURL, "public.png" as CFString, 1, nil) else { throw Failure.missingArtwork }
                CGImageDestinationAddImage(destination, result, nil)
                guard CGImageDestinationFinalize(destination) else { throw Failure.missingArtwork }
                evidence.append(["device": device, "state": state, "viewportWidth": size.width, "viewportHeight": size.height,
                                 "contentHeight": layout.size.height, "targets": layout.targets.count,
                                 "needsVerticalScroll": layout.size.height > size.height, "file": file.lastPathComponent,
                                 "minimumTouchExtent": 44, "disabledAndGapTargetsBlocked": true])
            }
        }
        if bundledGames {
            try JSONSerialization.data(withJSONObject: evidence, options: [.prettyPrinted, .sortedKeys])
                .write(to: output.appendingPathComponent("report.json"), options: .atomic)
            print("PASS: \(evidence.count) bundled/missing home renders and input targets; windowless and muted.")
            return
        }
        let adaptive = try auditAdaptive(session: session, typography: typography, artwork: artwork, output: output)
        let nativeHUD = try auditNativeArtwork(library: library, typography: typography, artwork: artwork, output: output)
        let covers = try auditBrowser(typography: typography, preview: image, output: output)
        let settingsSizes = try auditSettingsSizes(typography: typography, output: output)
        let report: [String: Any] = ["renderedStates": evidence.count, "originalMacGlyphsAndLogo": true,
                                    "targetsValidated": true, "audio": "muted", "windows": "none",
                                    "physicalUIKitAcceptance": "pending", "captures": evidence, "adaptiveHUD": adaptive,
                                    "coverArtwork": covers, "settingsSizes": settingsSizes, "nativeArtworkHUD": nativeHUD]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("report.json"), options: .atomic)
        print("PASS: \(evidence.count) pages, \(adaptive.count) HUD states, \(nativeHUD.count) native art states, \(covers.count) cover states and 3 unfold frames; touch targets, reserved regions and scroll reachability.")
    }
    static func careerPages() throws -> [(String, GameFrontEnd.Page)] {
        var profiles = MobileProfiles()
        profiles.rename(MobileProfiles.defaultID, to: "AB")
        for index in 1..<8 {
            _ = profiles.add(name: "AB", id: "player-\(index)")
            profiles.setPortrait("player-\(index)", to: index)
        }
        var records = ArcadeRecords()
        try records.importProfiles(profiles.players.map { .init(id: $0.id, initials: $0.name, portrait: $0.portrait) }, activeID: profiles.activeID)
        let empty = records
        let conditions = TrolleyConditions(gameID: ClassicTitle.lemmings.rawValue, packID: "classic",
            levelID: "level-0", levelFingerprint: String(repeating: "a", count: 64),
            rulesetVersion: "classic-dos-v1", physicsMode: "classic-dos-v1", population: 10,
            rescueRequirement: 5, startingSkills: ["digger": 1], timeLimitSeconds: 300)
        let level = ArcadeLevel(id: "fun-1", title: "Just Dig!", game: "Lemmings", rules: "DOS", total: 10, required: 5, conditions: conditions)
        let direct = records.record(.init(profileID: profiles.activeID, level: level, saved: 10, didWin: true, skills: [:], seconds: 12.34, telemetry: .init(released: 10)))
        let assisted = records.record(.init(profileID: profiles.activeID, level: level, saved: 8, didWin: true, skills: ["digger": 1], seconds: 18, assisted: true, telemetry: .init(released: 10, rewindCount: 1)))
        guard direct != nil, assisted != nil else { throw invalidTargets(line: #line) }
        let campaign = MobileCareerArt.campaignProgress(records: records, profileID: profiles.activeID,
            levelCounts: [ClassicTitle.lemmings.rawValue: 120])
        guard campaign.isUnlocked(.firstRescue), !campaign.isUnlocked(.lemmingsComplete),
              MobileCareerArt.campaignProgress(records: records, profileID: "player-1",
                levelCounts: [ClassicTitle.lemmings.rawValue: 120]).unlocked.isEmpty else { throw invalidTargets(line: #line) }
        let fanConditions = TrolleyConditions(gameID: "fan", packID: "community", levelID: "fan-level-0",
            levelFingerprint: String(repeating: "b", count: 64), rulesetVersion: "classic-dos-v1", physicsMode: "classic-dos-v1",
            population: 10, rescueRequirement: 5, startingSkills: ["digger": 1], timeLimitSeconds: 300)
        let fanLevel = ArcadeLevel(id: "fan-level-0", title: "A long fan-made level title that wraps", game: "Community", rules: "DOS", total: 10, required: 5, conditions: fanConditions)
        var mixed = records
        _ = mixed.record(.init(profileID: profiles.activeID, level: fanLevel, saved: 8, didWin: true, skills: [:], seconds: 15))
        let fanRecord = MobileCareerArt.recordLevelPage("direct|" + fanLevel.boardID, records: mixed, profileID: profiles.activeID, profileName: "AB", subtitle: "", replayAvailable: false)
        let officialRecord = MobileCareerArt.recordLevelPage("direct|" + level.boardID, records: mixed, profileID: profiles.activeID, profileName: "AB", subtitle: "", replayAvailable: false)
        guard fanRecord.subtitle.contains("Fan-made"), officialRecord.subtitle.contains("Official") else { throw invalidTargets(line: #line) }
        typealias Action = GameFrontEnd.Action
        let communityRows: [Action] = [.init("rankCategory", "Career stars"), .init("rankShare", "Share records", selected: true)]
        let boards: [Action] = ["Career stars", "Levels cleared", "Three-star levels", "This level", "Fastest clear", "Fastest 100%"].enumerated().map {
            .init("rankBoard.board-\($0.offset)", $0.element, selected: $0.offset == 0)
        }
        let progress = MobileCareerArt.progressPage(records: records, profileID: profiles.activeID, profileName: "AB",
                                                    subtitle: "", campaign: campaign)
        let replayRecord = MobileCareerArt.recordLevelPage("direct|" + level.boardID, records: records, profileID: profiles.activeID,
                                                           profileName: "AB", subtitle: "", replayAvailable: true)
        let recordCard = MobileCareerArt.recordLevelPage("direct|" + level.boardID, records: records, profileID: profiles.activeID,
            profileName: "AB", subtitle: "", replayAvailable: true, hintAvailable: true, playable: true, preview: true)
        let hintDeck = LevelHintDeck(title: level.title, checked: true, stages: [
            .init(title: "A gentle nudge", body: "Check the floor."),
            .init(title: "Dig straight down", body: "Give the first lemming the digger.\nThe crowd follows it into the tunnel."),
            .init(title: "Opening moves", body: "Study the checked example.")])
        let hintCard = MobileCareerArt.recordHintPage(level: level.title, deck: hintDeck, stage: 1,
            solution: true, playable: true, preview: true)
        let savedSeats = MobileCareerArt.players(profiles, subtitle: "", canDelete: true, hasSavedHotSeats: true)
        // Progress is the one hub for records, awards, rankings and counts. Each child page returns to it.
        guard progress.rows.map(\.id) == ["recordList", "achievements", "worldwide", "playInsights"],
              progress.footer.map(\.id) == ["home"],
              MobileCareerArt.recordsPage(records: records, profileID: profiles.activeID, profileName: "AB", subtitle: "").footer.map(\.id) == ["records"],
              MobileCareerArt.achievementsPage(records: records, profileID: profiles.activeID, profileName: "AB", subtitle: "").footer.map(\.id) == ["records"],
              replayRecord.orderedFooter.map(\.id) == ["recordList", "recordReplay"], replayRecord.footer.last?.primary == true,
              recordCard.orderedFooter.map(\.id) == ["recordList", "recordHint", "recordReplay", "recordPlay"],
              recordCard.footer.filter(\.primary).map(\.id) == ["recordPlay"], recordCard.stars == 3,
              hintCard.orderedFooter.map(\.id) == ["recordHintBack", "recordHintPrevious", "recordHintNext", "recordSolution", "recordPlay"],
              officialRecord.footer.map(\.id) == ["recordList"],
              savedSeats.rows.suffix(2).map(\.id) == ["hotSeat", "seatSaved"] else {
            let actual: [String: String] = [
                "progress rows": String(describing: progress.rows.map(\.id)),
                "progress footer": String(describing: progress.footer.map(\.id)),
                "records footer": String(describing: MobileCareerArt.recordsPage(records: records, profileID: profiles.activeID, profileName: "AB", subtitle: "").footer.map(\.id)),
                "achievements footer": String(describing: MobileCareerArt.achievementsPage(records: records, profileID: profiles.activeID, profileName: "AB", subtitle: "").footer.map(\.id)),
                "replay footer": String(describing: replayRecord.orderedFooter.map(\.id)),
                "record footer": String(describing: recordCard.orderedFooter.map(\.id)),
                "record primary": String(describing: recordCard.footer.filter(\.primary).map(\.id)),
                "record stars": String(describing: recordCard.stars),
                "hint footer": String(describing: hintCard.orderedFooter.map(\.id)),
                "official footer": String(describing: officialRecord.footer.map(\.id)),
                "saved seats": String(describing: savedSeats.rows.suffix(2).map(\.id))]
            for key in actual.keys.sorted() { FileHandle.standardError.write(Data("Career \(key): \(actual[key]!)\n".utf8)) }
            throw invalidTargets(line: #line)
        }
        return [
            ("progress-empty", MobileCareerArt.progressPage(records: empty, profileID: profiles.activeID, profileName: "AB", subtitle: "")),
            ("progress-earned", progress),
            ("records-replay", replayRecord),
            ("records-card", recordCard),
            ("records-hint", hintCard),
            ("players-saved-hot-seats", savedSeats),
            ("players-full", MobileCareerArt.players(profiles, subtitle: "", canDelete: true)),
            ("players-protected", MobileCareerArt.players(profiles, subtitle: "", canDelete: false)),
            ("players-delete", MobileCareerArt.players(profiles, subtitle: "", canDelete: true, confirmingDelete: true)),
            ("players-new", MobileCareerArt.players(profiles, subtitle: "", draft: "", creating: true, portrait: 7)),
            ("players-edit", MobileCareerArt.players(profiles, subtitle: "", draft: "AB", portrait: 3)),
            ("records-empty", MobileCareerArt.recordsPage(records: empty, profileID: profiles.activeID, profileName: "AB", subtitle: "")),
            ("records-fan", fanRecord),
            ("records-mixed", MobileCareerArt.recordsPage(records: mixed, profileID: profiles.activeID, profileName: "AB", subtitle: "")),
            ("records-levels", MobileCareerArt.recordsPage(records: records, profileID: profiles.activeID, profileName: "AB", subtitle: "")),
            ("records-direct", MobileCareerArt.recordLevelPage("direct|" + level.boardID, records: records, profileID: profiles.activeID, profileName: "AB", subtitle: "", replayAvailable: false)),
            ("records-assisted", MobileCareerArt.recordLevelPage("assisted|" + level.boardID, records: records, profileID: profiles.activeID, profileName: "AB", subtitle: "", replayAvailable: false)),
            ("achievements-empty", MobileCareerArt.achievementsPage(records: empty, profileID: profiles.activeID, profileName: "AB", subtitle: "")),
            ("achievements-earned", MobileCareerArt.achievementsPage(records: records, profileID: profiles.activeID, profileName: "AB", subtitle: "", campaign: campaign)),
            ("rankings-loading", MobileCareerArt.rankings(community: true, subtitle: "", busy: true, status: "", rows: communityRows, connected: false, available: true)),
            ("rankings-empty", MobileCareerArt.rankings(community: true, subtitle: "", busy: false, status: "No scores", rows: communityRows, connected: false, available: true)),
            ("rankings-offline", MobileCareerArt.rankings(community: true, subtitle: "", busy: false, status: "Connection unavailable", rows: communityRows, connected: false, available: true)),
            ("rankings-replays", MobileCareerArt.rankings(community: true, subtitle: "", busy: false, status: "", rows: communityRows + [.init("rankReplay.1", "#1 AB 12:34", enabled: true), .init("rankReplay.2", "#2 CD 12:56", enabled: false)], connected: false, available: true)),
            ("gamecenter-unavailable", MobileCareerArt.rankings(community: false, subtitle: "", busy: false, status: "Unavailable", rows: boards.map { .init($0.id, $0.title, enabled: false) }, connected: false, available: false)),
            ("gamecenter-connect", MobileCareerArt.rankings(community: false, subtitle: "", busy: false, status: "", rows: boards, connected: false, available: true)),
            ("gamecenter-scores", MobileCareerArt.rankings(community: false, subtitle: "", busy: false, status: "", rows: boards + [.init("rankRow.1", "#1 AB 120", enabled: false)], connected: true, available: true))
        ]
    }
    static func auditSettingsSizes(typography: GameMenuTypography, output: URL) throws -> [[String: Any]] {
        var evidence: [[String: Any]] = []
        for (device, size) in [("ipad-portrait", CGSize(width: 834, height: 1092)),
                               ("ipad-landscape", CGSize(width: 1112, height: 814)),
                               ("iphone-portrait", CGSize(width: 390, height: 763)),
                               ("iphone-landscape", CGSize(width: 756, height: 369)),
                               ("iphone-narrow-portrait", CGSize(width: 320, height: 548)),
                               ("iphone-narrow-landscape", CGSize(width: 568, height: 300))] {
            for interfaceSize in [ClassicInterfaceSize.large, .extraLarge] {
                var settings = MobileSettings(); settings.classic.interfaceSize = interfaceSize
                let scale = MobileSettingsArt.interfaceScale(interfaceSize, width: size.width)
                for group in MobileSettingsGroup.allCases {
                    let page = MobileSettingsArt.page(group, settings: settings)
                    let layout = GameFrontEnd.layout(page, width: size.width / scale, minimumHeight: size.height / scale)
                    let transform = CGAffineTransform(scaleX: scale, y: scale)
                    let content = CGSize(width: layout.size.width * scale, height: layout.size.height * scale)
                    guard abs(content.width - size.width) < 0.01 else { throw Failure.invalidTargets }
                    for target in layout.targets {
                        let actual = target.frame.applying(transform)
                        guard actual.width >= 44, actual.height >= 44,
                              CGRect(origin: .zero, size: content).contains(actual),
                              layout.action(at: CGPoint(x: actual.midX / scale, y: actual.midY / scale))
                                == (target.action.enabled ? target.action.id : nil) else { throw Failure.invalidTargets }
                    }
                    let context = try bitmapContext(size: content)
                    context.scaleBy(x: scale, y: scale)
                    GameFrontEnd.draw(page, layout: layout, typography: typography, in: context)
                    let file = "\(device)-settings-\(group.rawValue)-\(interfaceSize.rawValue).png"
                    try save(context: context, to: output.appendingPathComponent(file))
                    evidence.append(["device": device, "group": group.rawValue, "size": interfaceSize.rawValue,
                                     "scale": scale, "targets": layout.targets.count, "file": file,
                                     "minimumTouchExtent": 44, "contentFitsWidth": true])
                }
            }
        }
        return evidence
    }
    @MainActor static func auditAdaptive(session: any MobileGameSession, typography: GameMenuTypography,
                              artwork: URL, output: URL) throws -> [[String: Any]] {
        let vertical = MobileReservedRegion(kind: .division, frame: .init(x: 589, y: 0, width: 16, height: 834))
        let horizontal = MobileReservedRegion(kind: .division, frame: .init(x: 0, y: 405, width: 1194, height: 24))
        let poses: [(String, MobileSize, [MobileReservedRegion])] = [
            ("phone-landscape", .init(width: 844, height: 390), []),
            ("ipad-landscape", .init(width: 1112, height: 834), []),
            ("ipad-portrait", .init(width: 834, height: 1112), []),
            ("pocket", .init(width: 390, height: 844), []),
            ("narrow-portrait", .init(width: 320, height: 568), []),
            ("open", .init(width: 1194, height: 834), [vertical]),
            ("diorama", .init(width: 1194, height: 834), [horizontal]),
            ("camera", .init(width: 1194, height: 834), [vertical, .init(kind: .occlusion, frame: .init(x: 1120, y: 740, width: 74, height: 94))]),
            ("resized", .init(width: 568, height: 320), []),
            ("unavailable", .init(width: 280, height: 160), []),
        ]
        let image = MobileBitmapRenderer.image(try session.render(highlight: nil))
        let panel = session.panelFrame.flatMap(MobileBitmapRenderer.image)
        var evidence: [[String: Any]] = []
        for (pose, size, regions) in poses {
            for (state, paused, ending, selected, speed) in [
                ("ready", true, false, 0, 1.0), ("running", false, false, 1, 1.0),
                ("fast", false, false, 3, 5.0), ("armed", true, false, 2, 1.0),
                ("undo", true, true, 7, 1.0),
                ("ticks", true, false, 7, 1.0),
            ] {
                let original = session.snapshot
                let snapshot = MobileGameSnapshot(tick: original.tick, released: original.released, total: original.total,
                    saved: original.saved, required: original.required, remainingSeconds: original.remainingSeconds,
                    releaseRate: original.releaseRate, isComplete: false, didWin: false, isEndingRun: ending, skills: original.skills)
                let insets: MobileInsets = pose == "phone-landscape" ? .init(left: 47, bottom: 21, right: 47) : .init(top: 20, bottom: 20)
                let layout = MobileHUDLayout.make(container: size, safeArea: insets,
                    hasRate: true, skillCount: snapshot.skills.count, reservedRegions: regions, supportsRewind: true)
                let targets = MobileHUDRenderer.targets(layout: layout, snapshot: snapshot, selectedSkill: selected,
                    paused: paused, speed: speed, endRunArmed: state == "armed")
                if layout.canPlay {
                    guard targets[0].action == .releaseRate(-1), targets[1].action == .releaseRate(1),
                          targets[0].frame.minY == targets[1].frame.minY,
                          targets[0].frame.maxX <= targets[1].frame.minX else { throw Failure.invalidTargets }
                    if let portrait = layout.portrait {
                        let deck = cg(layout.interface.controlsFrame)
                        guard deck.contains(portrait.minimap),
                              portrait.minimap.height >= 44,
                              targets.allSatisfy({ !portrait.minimap.intersects($0.inputFrame) }) else { throw Failure.invalidTargets }
                    }
                }
                for (index, target) in targets.enumerated() {
                    let frame = target.inputFrame
                    guard frame.width >= 44 - 0.001, frame.height >= 44, hudTargetFits(target, layout: layout),
                          !target.accessibilityLabel.isEmpty, hudScrollTargetIsReachable(target, layout: layout),
                          regions.allSatisfy({ !frame.intersects(cg($0.frame)) }) else { throw Failure.invalidTargets }
                    let visible = hudVisibleInputFrame(target, layout: layout)
                    for other in targets.dropFirst(index + 1) where visible.intersection(hudVisibleInputFrame(other, layout: layout)).width > 0.001
                        && visible.intersection(hudVisibleInputFrame(other, layout: layout)).height > 0.001 { throw Failure.invalidTargets }
                    let hit = targets.first {
                        if case .skill = target.action { if case .skill = $0.action { return $0.inputFrame.contains(CGPoint(x: frame.midX, y: frame.midY)) }; return false }
                        return hudVisibleInputFrame($0, layout: layout).contains(CGPoint(x: frame.midX, y: frame.midY))
                    }
                    guard hit?.action == target.action else { throw Failure.invalidTargets }
                }
                let context = try bitmapContext(size: CGSize(width: size.width, height: size.height))
                context.setFillColor(CGColor(gray: 0, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
                if let image {
                    let field = cg(layout.interface.playfieldFrame)
                    var viewport = MobileViewport(levelSize: session.levelSize, viewSize: .init(width: field.width, height: field.height),
                        pixelAspect: 1.2)
                    viewport.fitGameplay(in: .init(width: field.width, height: field.height), centring: session.entrancePoint)
                    context.saveGState(); context.translateBy(x: field.minX, y: field.minY)
                    context.clip(to: CGRect(origin: .zero, size: field.size))
                    MobileBitmapRenderer.draw(image, viewport: viewport, in: context); context.restoreGState()
                }
                MobileHUDRenderer(layout: layout, snapshot: snapshot, selectedSkill: selected, paused: paused, speed: speed,
                    endRunArmed: state == "armed", panelImage: panel, typography: typography)
                    .draw(in: context, bounds: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                if let minimap = layout.minimapFrame {
                    let field = layout.interface.playfieldFrame
                    var camera = MobileViewport(levelSize: session.levelSize, viewSize: field.size,
                                                pixelAspect: 1.2)
                    camera.fitGameplay(in: field.size, centring: session.entrancePoint)
                    GameMinimapArt.draw(in: context, bounds: minimap, image: image,
                                       visible: cg(camera.visibleLevelRect), levelSize: CGSize(width: session.levelSize.width, height: session.levelSize.height), overlay: layout.portrait != nil)
                }
                if !layout.canPlay {
                    let page = GameFrontEnd.Page(title: "Paused", footer: [.init("library", "Library", primary: true)])
                    let menu = GameFrontEnd.layout(page, width: size.width, minimumHeight: size.height)
                    GameFrontEnd.draw(page, layout: menu, typography: typography, in: context)
                }
                let file = "hud-\(pose)-\(state).png"
                try save(context: context, to: output.appendingPathComponent(file))
                evidence.append(["pose": pose, "state": state, "targets": targets.count, "canPlay": layout.canPlay,
                                 "diorama": layout.isDiorama, "file": file])
            }
        }
        guard let unfold = GameUnfoldArt(directory: artwork) else { throw Failure.missingArtwork }
        for progress in [CGFloat(0), 0.5, 1] {
            let context = try bitmapContext(size: .init(width: 600, height: 400))
            let page = GameFrontEnd.Page(title: "Lemmings", home: true, rows: [.init("play", "Lemmings", primary: true)])
            let layout = GameFrontEnd.layout(page, width: 600, minimumHeight: 400)
            GameFrontEnd.draw(page, layout: layout, typography: typography, in: context)
            let region = CGRect(x: 0, y: 0, width: 600, height: 400)
            guard region.contains(unfold.frame(in: region, progress: progress)),
                  layout.targets.allSatisfy({ !$0.frame.intersects(unfold.frame(in: region, progress: progress)) })
            else { throw Failure.invalidTargets }
            unfold.draw(in: context, region: region, progress: progress)
            try save(context: context, to: output.appendingPathComponent("unfold-\(Int(progress * 100)).png"))
        }
        return evidence
    }

    static func auditBrowser(typography: GameMenuTypography, preview: CGImage, output: URL) throws -> [[String: Any]] {
        var evidence: [[String: Any]] = []
        for (pose, size) in [("portrait", CGSize(width: 834, height: 1112)), ("landscape", CGSize(width: 1112, height: 834))] {
            let safe = CGRect(x: 0, y: 20, width: size.width, height: size.height - 40)
            let layout = LevelBrowserGeometry(safe: safe)
            for (index, frame) in layout.actions.enumerated() {
                guard frame.width >= 44, frame.height >= 44, safe.contains(frame),
                      layout.actions.dropFirst(index + 1).allSatisfy({ !frame.intersects($0) }) else { throw Failure.invalidTargets }
            }
            let geometry = LevelCoverArt.geometry(for: layout.stage.size)
            let card = CGRect(x: layout.stage.midX - geometry.cardSize.width * 0.75,
                              y: layout.stage.midY - geometry.cardSize.height * 0.75,
                              width: geometry.cardSize.width * 1.5, height: geometry.cardSize.height * 1.5)
            guard layout.stage.contains(card), !layout.actions.contains(where: { $0.intersects(card) }) else { throw Failure.invalidTargets }
            for (state, selected, image) in [("selected", true, preview as CGImage?), ("inactive", false, preview as CGImage?), ("loading", true, nil)] {
                let context = try bitmapContext(size: size)
                context.setFillColor(CGColor(gray: 0, alpha: 1)); context.fill(CGRect(origin: .zero, size: size))
                GameMenuFrameArt.draw(in: context, board: layout.board)
                GamePixelTypography.draw("Just Dig!", in: layout.title, context: context, typography: typography, palette: .green, face: .large)
                GamePixelTypography.draw("Fun 1/30", in: layout.subtitle, context: context, typography: typography)
                LevelCoverArt.draw(in: context, bounds: card, title: "1  Just Dig!", artwork: image, selected: selected, typography: typography)
                for (index, frame) in layout.actions.enumerated() {
                    GameStoneArt.draw(in: context, frame: frame, selected: index == 3, pixel: 1)
                    GamePixelTypography.draw(["Back", "< Rank", "Rank >", "Play"][index], in: frame.insetBy(dx: 12, dy: 2),
                                             context: context, typography: typography, palette: index == 3 ? .green : .blue)
                }
                let file = "cover-\(pose)-\(state).png"
                try save(context: context, to: output.appendingPathComponent(file))
                evidence.append(["pose": pose, "state": state, "file": file, "targets": layout.actions.count,
                                 "perspectiveLayersAndUIKitHitDispatch": "pending"])
            }
        }
        return evidence
    }

    @MainActor static func auditNativeArtwork(library: ClassicMobileLibrary, typography: GameMenuTypography, artwork: URL, output: URL) throws -> [[String: Any]] {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("native-art-audit-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let amigaCandidates = [artwork.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("AmigaArtwork/lemmings"),
            artwork.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("amiga-artwork/export/lemmings")]
        guard let amiga = amigaCandidates.first(where: { FileManager.default.fileExists(atPath: $0.appendingPathComponent("manifest.json").path) }) else { throw Failure.missingArtwork }
        for (kind, source) in [("MacArtwork", artwork), ("AmigaArtwork", amiga)] {
            let parent = temporary.appendingPathComponent(kind)
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            try FileManager.default.createSymbolicLink(at: parent.appendingPathComponent("lemmings"), withDestinationURL: source)
        }
        let level = library.dataSet.campaign.levels[0].level
        let ground = try ClassicGroundSet.load(style: level.groundStyle, from: library.directory)
        let assets = try ClassicMainDATAssets.load(from: library.directory)
        let rendered = try ClassicLevelRenderer.render(level, groundSet: ground, specialGraphic: nil)
        let initial = try ClassicDOSSimulation(level: level, renderedLevel: rendered, mainDATAssets: assets)
        let palette = try ClassicLemmingPalette.inLevelVGA(terrainPalette: ground.terrainPalette)
        var evidence: [[String: Any]] = []
        for (source, name) in [(ClassicGraphicsSource.macintosh, "macintosh"), (.amiga, "amiga")] {
            let game = ClassicMobileSession(simulation: initial, renderedLevel: rendered, assets: assets, palette: palette,
                levelIdentifier: "native-audit", levelIndex: 0, startX: level.startX, authoredLevel: level, ground: ground,
                artworkFamily: "lemmings", artworkRoot: temporary)
            var settings = ClassicSettings(); settings.graphics = source; settings.colorDepth = .full
            game.applySettings(settings)
            for _ in 0..<60 { game.tick() }
            let bitmap = try game.render(highlight: nil)
            guard game.renderScale == 2, let image = MobileBitmapRenderer.image(bitmap) else { throw Failure.missingArtwork }
            for (pose, size) in [("landscape", MobileSize(width: 1194, height: 834)),
                                  ("portrait", MobileSize(width: 834, height: 1112)),
                                  ("phone", MobileSize(width: 390, height: 844))] {
                let layout = MobileHUDLayout.make(container: size, safeArea: .init(top: 20, bottom: 20), hasRate: true,
                    skillCount: game.snapshot.skills.count, supportsRewind: true)
                for state in ["running", "paused", "review"] {
                    let context = try bitmapContext(size: CGSize(width: size.width, height: size.height))
                    context.setFillColor(CGColor(gray: 0, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
                    let field = cg(layout.interface.playfieldFrame)
                    let viewport = MobileViewport(levelSize: game.levelSize, viewSize: .init(width: field.width, height: field.height),
                        origin: game.initialCameraOrigin, zoom: 2, pixelAspect: 1.2)
                    context.saveGState(); context.translateBy(x: field.minX, y: field.minY)
                    context.clip(to: CGRect(origin: .zero, size: field.size))
                    MobileBitmapRenderer.draw(image, viewport: viewport, in: context)
                    RescueCelebration.draw(in: CGRect(origin: .zero, size: field.size), amount: state == "review" ? 1 : 0, context: context)
                    context.restoreGState()
                    let icons = game.snapshot.skills.indices.map { game.skillCursorFrame(control: $0).flatMap(MobileBitmapRenderer.image) }
                    MobileHUDRenderer(layout: layout, snapshot: game.snapshot, selectedSkill: 7, paused: state != "running", speed: 1,
                        endRunArmed: false, panelImage: game.panelFrame.flatMap(MobileBitmapRenderer.image), typography: typography,
                        counterStyle: .macintosh, skillIcons: icons, readOnly: state == "review").draw(in: context, bounds: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                    if let minimap = layout.minimapFrame {
                        GameMinimapArt.draw(in: context, bounds: minimap, image: image, visible: cg(viewport.visibleLevelRect),
                            levelSize: CGSize(width: game.levelSize.width, height: game.levelSize.height), overlay: layout.portrait != nil)
                    }
                    if state == "review" {
                        for star in 0..<3 { GameStarArt.draw(at: CGPoint(x: field.midX - 51 + CGFloat(star * 38), y: field.minY + 16), earned: star < 2, size: 3, context: context) }
                    }
                    let file = "hud-native-" + name + "-" + pose + "-" + state + ".png"
                    try save(context: context, to: output.appendingPathComponent(file))
                    evidence.append(["source": name, "state": state, "file": file, "nativeScale": 2, "readOnly": state == "review"])
                }
            }
        }
        return evidence
    }

    static func cg(_ rect: MobileRect) -> CGRect { CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height) }
    @MainActor static func checkSharingPrivacy(typography: GameMenuTypography, output: URL) throws {
        var captures = 0
        let pages: [(String, GameFrontEnd.Page)] = [
            ("consent", MobileInformationArt.telemetryConsent()),
            ("on", MobileSettingsArt.page(.privacy, settings: .init(), sharing: true, sharingAvailable: true)),
            ("off", MobileSettingsArt.page(.privacy, settings: .init(), sharing: false, sharingAvailable: true)),
            ("unavailable", MobileSettingsArt.page(.privacy, settings: .init(), sharingAvailable: false))]
        for (device, size) in [("phone", CGSize(width: 320, height: 568)), ("ipad", CGSize(width: 768, height: 1024)), ("tv", CGSize(width: 1920, height: 1080))] {
            for interfaceSize in ClassicInterfaceSize.allCases {
                let scale = MobileSettingsArt.interfaceScale(interfaceSize, width: size.width, television: device == "tv")
                let logical = CGSize(width: floor(size.width / scale), height: floor(size.height / scale))
                for (state, page) in pages {
                    let layout = GameFrontEnd.layout(page, width: logical.width, minimumHeight: logical.height)
                    guard let sharing = layout.targets.first(where: { ["telemetryYes", "setting.telemetry"].contains($0.action.id) }),
                          sharing.action.title == (state == "consent" ? "Share" : "Share counts and records"),
                          sharing.action.enabled == (state != "unavailable"),
                          page.backAction != nil,
                          state != "consent" || page.details.contains("Public: initials, scores and action replays.") else { throw invalidTargets(line: #line) }
                    for target in layout.targets {
                        if state == "consent" {
                            guard typography.width(of: target.action.title.uppercased(), face: .large, scale: 1) <= target.frame.width - 24 else { throw invalidTargets(line: #line) }
                        }
                        guard target.frame.width >= 44, target.frame.height >= 44,
                              CGRect(origin: .zero, size: layout.size).contains(target.frame),
                              layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)) == (target.action.enabled ? target.action.id : nil)
                        else { throw invalidTargets(line: #line) }
                    }
                    for (index, target) in layout.targets.enumerated() {
                        guard layout.targets.dropFirst(index + 1).allSatisfy({ !target.frame.intersects($0.frame) }) else { throw invalidTargets(line: #line) }
                    }
                    let imageSize = CGSize(width: ceil(layout.size.width * scale), height: ceil(layout.size.height * scale))
                    let context = try bitmapContext(size: imageSize)
                    context.scaleBy(x: scale, y: scale)
                    GameFrontEnd.draw(page, layout: layout, typography: typography, in: context)
                    try save(context: context, to: output.appendingPathComponent("sharing-\(device)-\(interfaceSize.rawValue)-\(state).png"))
                    captures += 1
                }
            }
        }
        print("PASS \(captures) phone, iPad and TV sharing consent/on/off/unavailable renders, captions and input targets")
    }

    static func bitmapContext(size: CGSize) throws -> CGContext {
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
            bytesPerRow: Int(size.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.missingArtwork }
        context.translateBy(x: 0, y: size.height); context.scaleBy(x: 1, y: -1)
        return context
    }
    static func save(context: CGContext, to file: URL) throws {
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(file as CFURL, "public.png" as CFString, 1, nil)
        else { throw Failure.missingArtwork }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw Failure.missingArtwork }
    }
    enum Failure: Error { case invalidArguments, missingArtwork, invalidTargets }
}
