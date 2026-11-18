import CoreGraphics
import Foundation
import ImageIO
import LemmingsMobileCore
import NxlvKit
#if !MOBILE_CLEAN_CONTENT_STANDALONE
import Testing
#endif

private enum CleanContentFailure: Error {
    case failed(String)
    case invalidImport
}

private func requireClean(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    guard try condition() else { throw CleanContentFailure.failed(message) }
}

private func sameCleanCheckpoint(_ first: Data, _ second: Data) throws -> Bool {
    let left = try JSONSerialization.jsonObject(with: first) as? NSDictionary
    let right = try JSONSerialization.jsonObject(with: second) as? NSDictionary
    return left?.isEqual(right) == true
}

/**
 * Uses authored test pixels instead of commercial data or a downloaded asset pack.
 */
private func cleanArtworkFixture() throws -> LixArtwork {
    func png(width: Int, height: Int, pixels: [UInt8]) throws -> Data {
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                  bytesPerRow: width * 4, space: space, bitmapInfo: .init(rawValue: CGImageAlphaInfo.last.rawValue),
                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            throw CleanContentFailure.failed("Cannot create the authored sprite fixture.")
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil) else {
            throw CleanContentFailure.failed("Cannot encode the authored sprite fixture.")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CleanContentFailure.failed("Cannot finish the authored sprite fixture.")
        }
        return output as Data
    }
    var sprites = [UInt8](repeating: 0, count: 913 * 946 * 4)
    var rows: [[String: Any]] = []
    for (row, activity) in LixArtwork.Activity.allCases.enumerated() {
        let top = 1 + row * 35
        for y in 13..<24 {
            for x in 15..<19 {
                let offset = ((top + y) * 913 + 1 + x) * 4
                sprites.replaceSubrange(offset..<(offset + 4), with: [220, 30, 30, 255])
            }
        }
        rows.append(["activity": activity.rawValue, "row": row,
                     "frames": [["x": 1, "y": top, "width": 34, "height": 34]]])
    }
    let metadata = try JSONSerialization.data(withJSONObject: [
        "frameWidth": 34, "frameHeight": 34, "upstreamRightFacingFootAnchor": [16, 26], "rows": rows,
    ])
    return try LixArtwork(spritePNG: png(width: 913, height: 946, pixels: sprites),
                         recolourPNG: png(width: 15, height: 2, pixels: [UInt8](repeating: 0, count: 15 * 2 * 4)),
                         metadata: metadata)
}

private enum MobileCleanContentChecks {
    static func starterIsAvailableWithoutFilesAndDrawsLix() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CleanStarter-\(UUID().uuidString)")
        let store = MobileContentStore(root: root, cleanEdition: true, lixArtwork: try cleanArtworkFixture())
        guard let library = try store.loadLibrary() else {
            throw CleanContentFailure.failed("The clean edition did not supply its starter.")
        }
        try requireClean(library.isStarter && !library.hasOriginalCharacters && library.usesLixArtwork,
                         "The starter unexpectedly depends on original characters.")
        try requireClean(library.levels.count == 3, "The starter campaign is incomplete.")
        try requireClean(try store.loadOwnedLibrary() == nil, "An empty store reported imported content.")
        try requireClean(!FileManager.default.fileExists(atPath: root.path), "Starter loading created game-data files.")
        let session = try library.loadLevel(at: 0).session
        for _ in 0..<100 where session.targetCandidates(for: 0).isEmpty { session.tick() }
        guard let target = session.targetCandidates(for: 0).first else {
            throw CleanContentFailure.failed("The starter did not release a character.")
        }
        let frame = try session.render(highlight: nil)
        let pixels = [UInt8](frame.rgba)
        var redPixels = 0
        for y in max(0, Int(target.point.y) - 10)..<min(frame.height, Int(target.point.y) + 8) {
            for x in max(0, Int(target.point.x) - 10)..<min(frame.width, Int(target.point.x) + 10) {
                let offset = (y * frame.width + x) * 4
                if pixels[offset] > 180 && pixels[offset + 1] < 80 && pixels[offset + 2] < 80 {
                    redPixels += 1
                }
            }
        }
        try requireClean(redPixels > 0, "The starter did not draw Lix pixels at the actor's foot point.")
        try requireClean(session.levelIdentifier.hasPrefix(ClassicMobileLibrary.starterLevelIdentifierPrefix),
                         "The starter checkpoint cannot be routed to its own library.")
        try requireClean(try MobileContentStore(root: root).loadLibrary() == nil,
                         "The preservation edition changed its empty-library behaviour.")
    }

    static func allStarterPuzzlesWinThroughNormalCommands() throws {
        let library = try ClassicMobileLibrary.openStarter(directory: URL(fileURLWithPath: "/unused-starter"),
                                                          lixArtwork: cleanArtworkFixture())
        for index in 0..<3 {
            let session = try library.loadLevel(at: index).session
            let control: Int? = index == 1 ? 1 : index == 2 ? 0 : nil
            while !session.snapshot.isComplete && session.snapshot.tick < 4_000 {
                session.tick()
                if let control {
                    for target in session.targetCandidates(for: control) where target.assignment == .eligible {
                        try requireClean(session.assign(control: control, to: target.id), "A normal starter input failed.")
                    }
                }
            }
            try requireClean(session.snapshot.didWin && session.snapshot.saved == session.snapshot.total,
                             "Starter route \(index + 1) did not rescue every character.")
        }
    }

    static func characterChoicePreservesSimulationAndCheckpoints() throws {
        let dataSet = try OpenStarterContent.makeDataSet()
        let level = dataSet.campaign.levels[0].level
        let rendered = try ClassicLevelRenderer.render(level, groundSet: OpenStarterContent.makeGroundSet())
        let simulation = try ClassicDOSSimulation(level: level, renderedLevel: rendered)
        let assets = try ClassicMainDATAssets(decompressedSections: [
            Data(repeating: 0, count: 65_536), Data(repeating: 0, count: 1_024),
        ])
        let artwork = try cleanArtworkFixture()
        let session = ClassicMobileSession(simulation: simulation, renderedLevel: rendered, assets: assets,
                                           lixArtwork: artwork, levelIdentifier: "authored/fixture", levelIndex: 0)
        for _ in 0..<90 { session.tick() }
        let snapshot = session.snapshot
        let payload = try session.checkpointPayload()
        try requireClean(!session.usesLixArtwork, "Owned characters were replaced before selection.")
        try requireClean(session.setLixArtworkEnabled(true) && session.usesLixArtwork, "Lix selection failed.")
        _ = try session.render(highlight: nil)
        try requireClean(session.setLixArtworkEnabled(false) && !session.usesLixArtwork, "Original selection failed.")
        try requireClean(session.snapshot == snapshot, "A presentation change advanced the simulation.")
        let restored = ClassicMobileSession(simulation: simulation, renderedLevel: rendered, assets: assets,
                                            lixArtwork: artwork, useLixArtwork: true,
                                            levelIdentifier: "authored/fixture", levelIndex: 0)
        try restored.restoreCheckpointPayload(payload)
        try requireClean(restored.snapshot == snapshot, "Changing artwork invalidated a checkpoint.")
        for _ in 0..<80 { session.tick(); restored.tick() }
        try requireClean(restored.snapshot == session.snapshot, "Artwork changed later simulation outcomes.")

        let starter = try ClassicMobileLibrary.openStarter(directory: URL(fileURLWithPath: "/unused-starter"),
                                                          lixArtwork: artwork)
        let forced = try starter.loadLevel(at: 0).session
        try requireClean(!starter.setLixArtworkEnabled(false) && starter.usesLixArtwork,
                         "The starter library hid its only characters.")
        try requireClean(!forced.setLixArtworkEnabled(false) && forced.usesLixArtwork,
                         "The starter session hid its only characters.")
    }

    static func realSceneArtworkPreservesCoordinates(directory: URL) throws {
        let artwork = try LixArtwork(directory: directory)
        try requireClean(artwork.sceneArtwork != nil, "The prepared Lix scene artwork is unavailable.")
        let library = try ClassicMobileLibrary.openStarter(directory: URL(fileURLWithPath: "/unused-starter"),
                                                          lixArtwork: artwork)
        for index in 0..<3 {
            let session = try library.loadLevel(at: index).session
            for _ in 0..<70 { session.tick() }
            let before = try session.checkpointPayload()
            guard let target = session.targetCandidates(for: 0).first else {
                throw CleanContentFailure.failed("The scene check has no native actor.")
            }
            let selection = MobileTargetSelection(id: target.id, point: target.point, state: .eligible)
            let frame = try session.render(highlight: selection)
            try requireClean(frame.width == Int(session.levelSize.width) * 2
                && frame.height == Int(session.levelSize.height) * 2,
                "The Lix scene lost its native 2× detail or changed the logical level size.")
            let pixels = [UInt8](frame.rgba)
            let markerX = (Int(target.point.x.rounded()) + 8) * 2
            let markerY = (Int(target.point.y.rounded()) + 8) * 2
            for dy in 0..<2 { for dx in 0..<2 {
                let offset = ((markerY + dy) * frame.width + markerX + dx) * 4
                try requireClean(Array(pixels[offset..<(offset + 4)]) == [116, 255, 26, 255],
                                 "The 2× reticle moved away from its logical input target.")
            } }
            var red = 0
            for y in max(0, Int(target.point.y) - 10)..<min(frame.height / 2, Int(target.point.y) + 8) {
                for x in max(0, Int(target.point.x) - 10)..<min(frame.width / 2, Int(target.point.x) + 10) {
                    let offset = (y * 2 * frame.width + x * 2) * 4
                    if pixels[offset] > 180 && pixels[offset + 1] < 100 && pixels[offset + 2] < 100 { red += 1 }
                }
            }
            try requireClean(red > 0, "The source-detail Lix actor moved away from its native foot point.")
            try requireClean(try sameCleanCheckpoint(session.checkpointPayload(), before),
                             "The scene renderer changed the simulation or checkpoint.")
        }

        let level = try OpenStarterContent.makeDataSet().campaign.levels[0].level
        let rendered = try ClassicLevelRenderer.render(level, groundSet: OpenStarterContent.makeGroundSet())
        let simulation = try ClassicDOSSimulation(level: level, renderedLevel: rendered)
        let assets = try ClassicMainDATAssets(decompressedSections: [
            Data(repeating: 0, count: 65_536), Data(repeating: 0, count: 1_024),
        ])
        let session = ClassicMobileSession(simulation: simulation, renderedLevel: rendered, assets: assets,
            lixArtwork: artwork, levelIdentifier: "authored/scene-choice", levelIndex: 0)
        let before = try session.checkpointPayload()
        let original = try session.render(highlight: nil)
        try requireClean(session.setLixArtworkEnabled(true), "The full Lix scene choice failed.")
        let selected = try session.render(highlight: nil)
        try requireClean(selected.width == original.width * 2 && selected.height == original.height * 2,
                         "Selecting Lix did not replace the scene at source detail.")
        try requireClean(session.setLixArtworkEnabled(false), "The original scene choice failed.")
        try requireClean(try session.render(highlight: nil) == original,
                         "The original scene did not return after the Lix selection.")
        try requireClean(try sameCleanCheckpoint(session.checkpointPayload(), before),
                         "Changing scene artwork changed the simulation or checkpoint.")

        let bomber = try ClassicLevel(data: Data(repeating: 0, count: ClassicLevel.recordSize),
            propertiesOverride: .init(title: "Authored bomber check", releaseRate: 50, lemmingCount: 1,
                saveRequirement: 1, timeLimitMinutes: 3, skills: [.bomber: 1]),
            steelOverride: [], terrainOverride: level.terrain, objectsOverride: level.objects)
        let bomberScene = try ClassicLevelRenderer.render(bomber, groundSet: OpenStarterContent.makeGroundSet())
        var bomberSimulation = try ClassicDOSSimulation(level: bomber, renderedLevel: bomberScene)
        for _ in 0..<100 where bomberSimulation.lemmings.isEmpty { _ = bomberSimulation.tick() }
        guard let id = bomberSimulation.lemmings.first?.id else {
            throw CleanContentFailure.failed("The authored bomber check did not release an actor.")
        }
        try requireClean(bomberSimulation.assign(.bomber, to: id) == .assigned,
                         "The authored bomber command was rejected.")
        var observed = false
        for _ in 0..<200 {
            _ = bomberSimulation.tick()
            guard let lemming = bomberSimulation.lemmings.first, lemming.action == .exploding,
                  let expected = artwork.frame(activity: .imploder, animationFrame: lemming.animationFrame,
                    facingLeft: lemming.direction == .left),
                  let neutral = artwork.frame(activity: .stunner, animationFrame: lemming.animationFrame,
                    facingLeft: lemming.direction == .left) else { continue }
            let differing = stride(from: 0, to: expected.rgba.count, by: 4).contains {
                expected.rgba[$0 + 3] == 255
                    && expected.rgba[$0..<($0 + 4)] != neutral.rgba[$0..<($0 + 4)]
            }
            guard differing else { continue }
            let subject = ClassicMobileSession(simulation: bomberSimulation, renderedLevel: bomberScene,
                lixArtwork: artwork, useLixArtwork: true, levelIdentifier: "authored/bomber", levelIndex: 0)
            let actual = try subject.render(highlight: nil)
            let pixels = [UInt8](actual.rgba)
            var checked = 0
            for y in 0..<expected.height { for x in 0..<expected.width {
                let source = (y * expected.width + x) * 4
                guard expected.rgba[source + 3] == 255 else { continue }
                let targetX = lemming.foot.x * 2 - expected.footX + x
                let targetY = lemming.foot.y * 2 - expected.footY + y
                guard (0..<actual.width).contains(targetX), (0..<actual.height).contains(targetY) else { continue }
                let target = (targetY * actual.width + targetX) * 4
                try requireClean(pixels[target..<(target + 4)] == expected.rgba[source..<(source + 4)],
                                 "The real bomber transition lost its Lix implosion pixels.")
                checked += 1
            } }
            try requireClean(checked > 0, "The real bomber transition rendered no source pixels.")
            observed = true
            break
        }
        try requireClean(observed, "The authored bomber command did not reach its real explosion state.")
    }

    static func cleanImportRejectsInvalidReplacementsAndHiddenLinks() throws {
        let manager = FileManager.default
        let temporary = manager.temporaryDirectory.appendingPathComponent("CleanImport-\(UUID().uuidString)")
        defer { try? manager.removeItem(at: temporary) }
        let source = temporary.appendingPathComponent("Selected")
        try manager.createDirectory(at: source, withIntermediateDirectories: true)
        let file = source.appendingPathComponent("fixture.dat")
        try Data("accepted".utf8).write(to: file)
        let store = MobileContentStore(root: temporary.appendingPathComponent("Store"), cleanEdition: true) { staged in
            guard try Data(contentsOf: staged.appendingPathComponent("fixture.dat")) == Data("accepted".utf8) else {
                throw CleanContentFailure.invalidImport
            }
        }
        try store.install(directory: source)
        try requireClean(manager.fileExists(atPath: store.gameDataDirectory.appendingPathComponent(BYOIntegration.manifestName).path),
                         "The clean importer did not record the installed file hashes.")
        try Data("rejected".utf8).write(to: file)
        do {
            try store.install(directory: source)
            throw CleanContentFailure.failed("An invalid replacement was installed.")
        } catch CleanContentFailure.invalidImport { }
        try requireClean(try Data(contentsOf: store.gameDataDirectory.appendingPathComponent("fixture.dat"))
                         == Data("accepted".utf8), "A failed replacement damaged the prior import.")
        try Data("accepted".utf8).write(to: file)
        try manager.createSymbolicLink(at: source.appendingPathComponent(".hidden-link"), withDestinationURL: file)
        do {
            try store.install(directory: source)
            throw CleanContentFailure.failed("A hidden symbolic link was imported.")
        } catch BYOIntegrationError.symbolicLink { }
    }
}

#if MOBILE_CLEAN_CONTENT_STANDALONE
@main enum MobileCleanContentRunner {
    static func main() {
      do {
        try MobileCleanContentChecks.starterIsAvailableWithoutFilesAndDrawsLix()
        print("PASS clean starter availability, native Lix foot pixels and preservation defaults")
        try MobileCleanContentChecks.allStarterPuzzlesWinThroughNormalCommands()
        print("PASS all three starter puzzles through normal mobile commands")
        try MobileCleanContentChecks.characterChoicePreservesSimulationAndCheckpoints()
        print("PASS character selection, checkpoint compatibility and deterministic outcomes")
        if let directory = ProcessInfo.processInfo.environment["LIX_ARTWORK_PACK"] {
            try MobileCleanContentChecks.realSceneArtworkPreservesCoordinates(directory: URL(fileURLWithPath: directory))
            print("PASS three native 2× Lix scenes, actor anchors, reticle coordinates, reversible scene selection and real bomber transition")
        }
        try MobileCleanContentChecks.cleanImportRejectsInvalidReplacementsAndHiddenLinks()
        print("PASS bounded clean import, invalid replacement rollback and hidden-link rejection")
      } catch {
        FileHandle.standardError.write(Data("FAIL \(error)\n".utf8))
        exit(1)
      }
    }
}
#else
@Suite("Clean mobile content") struct MobileCleanContentTests {
    @Test func starterAvailabilityAndPixels() throws {
        try MobileCleanContentChecks.starterIsAvailableWithoutFilesAndDrawsLix()
    }
    @Test func starterPuzzles() throws {
        try MobileCleanContentChecks.allStarterPuzzlesWinThroughNormalCommands()
    }
    @Test func characterChoiceAndCheckpoints() throws {
        try MobileCleanContentChecks.characterChoicePreservesSimulationAndCheckpoints()
    }
    @Test func validatedImport() throws {
        try MobileCleanContentChecks.cleanImportRejectsInvalidReplacementsAndHiddenLinks()
    }
}
#endif
