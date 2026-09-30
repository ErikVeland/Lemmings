import AppKit
import XCTest
import NxlvKit
@testable import LemmingsLocal

/// Loads real fan assets without creating an application or a window.
final class JourneySolutionTests: XCTestCase {
    func testMinerIntroductionHasACompleteIntermediateWitness() throws {
        let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let resources = ProcessInfo.processInfo.environment["LEMMINGS_TEST_APP"].map {
            URL(fileURLWithPath: $0).appendingPathComponent("Contents/Resources")
        } ?? project.appendingPathComponent(".build/local/Ultimate Lemmings.app/Contents/Resources")
        let ports = resources.appendingPathComponent("Ports")
        guard FileManager.default.fileExists(atPath: ports.path) else {
            throw XCTSkip("Build the local game resources to validate the miner introduction")
        }
        let journey = try JSONDecoder().decode(LearningJourney.self,
            from: Data(contentsOf: project.appendingPathComponent("Resources/Progression/learning.json")))
        let lesson = try XCTUnwrap(journey.lessons.first { $0.objective == "introduce:miner" })
        let roots = try FileManager.default.contentsOfDirectory(at: ports, includingPropertiesForKeys: nil)
        let root = try XCTUnwrap(roots.first {
            (try? ClassicDataSet.detect(directory: $0))?.identifierKey == lesson.entry.identity.packID
        })
        let set = try ClassicDataSet.detect(directory: root)
        let item = set.campaign.levels[lesson.entry.levelNumberSnapshot - 1]
        XCTAssertEqual(item.level.title, "Honey, I Saved The Lemmings")
        XCTAssertEqual(lesson.stage, .intermediate)
        XCTAssertTrue(lesson.needsSupport)
        let ground = try ClassicGroundSet.load(style: item.level.groundStyle, from: root)
        let rendered = try ClassicLevelRenderer.render(item.level, groundSet: ground)
        let initial = try ClassicDOSSimulation(level: item.level, renderedLevel: rendered,
            mainDATAssets: ClassicMainDATAssets.load(from: root),
            mechanics: ClassicDOSMechanics(title: set.title, rank: item.rank))
        let solution = try XCTUnwrap(VerifiedSolution.load(initial: initial, from: project.appendingPathComponent("Resources")))
        let profile = try ClassicDifficultyAnalysis.analyse(initial: initial, replay: solution.replay,
            key: .init(identity: lesson.entry.identity, levelRevision: "regression"))
        XCTAssertEqual(profile.detectedTechniques, ["miner"])
        XCTAssertEqual(profile.precision?.completed, true)
        XCTAssertLessThanOrEqual(profile.components.executionPrecision, 300)
        XCTAssertEqual(solution.replay.expected?.saved, solution.replay.expected?.released)
    }

    @MainActor func testIntermediateIntroductionRendersWithUsableTargets() throws {
        _ = NSApplication.shared
        let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let journey = try JSONDecoder().decode(LearningJourney.self,
            from: Data(contentsOf: project.appendingPathComponent("Resources/Progression/learning.json")))
        let lesson = try XCTUnwrap(journey.lessons.first { $0.objective == "introduce:miner" })
        var started = false
        let page = LearningJourneyMenu.hub(next: lesson, solved: 7, total: journey.lessons.count,
            later: 0, resume: false, play: { started = true }, revisit: {})
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 720),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 1120, height: 720))
        GameScreen.shared.gameWindow = window
        defer { GameScreen.shared.dismissAll(); GameScreen.shared.gameWindow = nil }
        GameScreen.shared.present(page, owner: window)
        window.contentView?.layoutSubtreeIfNeeded(); page.layoutSubtreeIfNeeded()
        func controls(_ view: NSView) -> [NSButton] {
            (view as? NSButton).map { [$0] } ?? view.subviews.flatMap(controls)
        }
        for button in controls(page) where button.isEnabled && !button.isHidden {
            let rect = button.convert(button.bounds, to: page)
            XCTAssertTrue(page.bounds.contains(rect), button.title)
            let hit = page.hitTest(NSPoint(x: rect.midX, y: rect.midY))
            XCTAssertTrue(hit === button || hit?.isDescendant(of: button) == true)
            XCTAssertTrue(window.makeFirstResponder(button))
        }
        let bitmap = try XCTUnwrap(page.bitmapImageRepForCachingDisplay(in: page.bounds))
        page.cacheDisplay(in: page.bounds, to: bitmap)
        let output = project.appendingPathComponent(".build/journey-review")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            .write(to: output.appendingPathComponent("miner-introduction.png"))
        try XCTUnwrap(controls(page).first { $0.title == "Let's play" }).performClick(nil)
        XCTAssertTrue(started)
    }

    func testEarlyFanLessonsHavePlayableSolutionReplays() throws {
        let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let resources = ProcessInfo.processInfo.environment["LEMMINGS_TEST_APP"].map {
            URL(fileURLWithPath: $0).appendingPathComponent("Contents/Resources")
        } ?? project.appendingPathComponent(".build/local/Ultimate Lemmings.app/Contents/Resources")
        guard FileManager.default.fileExists(atPath: resources.appendingPathComponent("LevelPacks").path) else {
            throw XCTSkip("Build the local game resources to validate the real Journey replays")
        }
        let ports = resources.appendingPathComponent("Ports")
        let packs = FanLevelLibrary.packs(in: [resources.appendingPathComponent("LevelPacks")])
        let assets = try ClassicMainDATAssets.load(from: ports.appendingPathComponent("lemmings_dos_1991-07-30"))
        for (packID, file, section) in [("lldb-302", "TWPAK00.dat", 1), ("lldb-547", "Ji Hoon Heaven 1.DAT", 6)] {
            let pack = try XCTUnwrap(packs.first { FanLevelLibrary.catalogueID($0) == packID })
            let item = try XCTUnwrap(FanLevelLibrary.validatedEntries(in: pack).first {
                $0.file == file && $0.section == section
            })
            let (level, style) = try FanLevelLibrary.level(item, in: pack)
            let ground = try FanLevelLibrary.groundSet(for: level, styleName: style, portsRoot: ports, pack: pack, entry: item)
            let special = try FanLevelLibrary.specialGraphic(for: level, entry: item, pack: pack, portsRoot: ports)
            let rendered = try ClassicLevelRenderer.render(level, groundSet: ground, specialGraphic: special,
                objectSemantics: .forFanLevel(level, groundSet: ground))
            let initial = try ClassicDOSSimulation(level: level, renderedLevel: rendered, mainDATAssets: assets, clock: .golems)
            let solution = try XCTUnwrap(VerifiedSolution.load(initial: initial, from: project.appendingPathComponent("Resources")),
                "No usable hints replay for \(level.title)")
            if packID == "lldb-547" {
                let profile = try ClassicDifficultyAnalysis.analyse(initial: initial, replay: solution.replay,
                    key: .init(identity: .init(engine: .classic, packID: "fan:" + packID, levelID: file + "#6"),
                        levelRevision: "regression"), maximumProbeRuns: 10)
                XCTAssertEqual(profile.precision?.assignmentCount, 1)
                XCTAssertEqual(profile.precision?.completed, true)
                XCTAssertGreaterThan(profile.components.executionPrecision, 180)
                XCTAssertTrue(profile.detectedTechniques.contains("release-rate-manipulation"))
            }
        }
    }
}
