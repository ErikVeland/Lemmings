import CoreGraphics
import Foundation
import ImageIO
import LemmingsAppCore
import LemmingsMobileCore
import NxlvKit
#if !MOBILE_CLEAN_CONTENT_STANDALONE
import Testing
#endif

private enum CleanContentFailure: Error, Equatable {
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

private final class FixtureArtwork: ClassicMobileArtworkProvider {
    let artwork: LixArtwork
    var isEnabled = true
    var revision: String { String(isEnabled) }
    let renderScale = 1
    init() throws { artwork = try cleanArtworkFixture() }
    func scene(_ level: ClassicRenderedLevel, simulation: ClassicDOSSimulation) -> MobilePixelFrame? {
        try? MobilePixelFrame(width: level.width, height: level.height,
            rgba: ClassicSceneFrame.rgba(level, simulation: simulation))
    }
    func sprite(_ lemming: ClassicDOSLemming, simulation: ClassicDOSSimulation) -> MobileSpriteHighlight? {
        guard let frame = artwork.frame(activity: .walker, animationFrame: lemming.animationFrame,
                                        facingLeft: lemming.direction == .left),
              let pixels = try? MobilePixelFrame(width: frame.width, height: frame.height, rgba: Data(frame.rgba))
        else { return nil }
        return .init(frame: pixels, rect: .init(x: Double(lemming.foot.x - frame.footX),
            y: Double(lemming.foot.y - frame.footY), width: Double(frame.width), height: Double(frame.height)),
            cacheKey: "fixture", time: nil, facingLeft: lemming.direction == .left)
    }
    func skill(control: Int) -> MobilePixelFrame? { nil }
}

@Suite("Clean mobile content") struct MobileCleanContentTests {
    private func withStarter(_ body: (ClassicMobileLibrary) throws -> Void) throws {
        let ports = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: ports) }
        let root = ports.appendingPathComponent("ultimate_lemmix_starter")
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", repo.appendingPathComponent("Tools/AlternativeAssets/prepare_open_starter.py").path,
                             "--output", root.path]
        try process.run(); process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        #expect(GameStarterContent.isStarter(directory: root))
        try body(ClassicMobileLibrary(directory: root))
    }

    @Test func starterPlaylistsResolveInAnAuthoredOnlyInstall() throws {
        try withStarter { starter in
            let ports = starter.directory.deletingLastPathComponent()
            let catalogue = MobileCatalogue(portsRoot: ports)
            let original = LevelCatalogueIdentity(engine: .classic, packID: "lemmings-LEVEL-120", levelID: "0:Fun:1:9:1")
            #expect(catalogue.families.contains(.classic))
            #expect(MobileJourneyLibrary.sourcePack(for: original, in: catalogue) == nil)
            let visible = StarterPlaylistCatalogue.routes.filter { MobileStarterPlaylists.hasSources(for: $0, in: catalogue) }
            #expect(visible.map(\.key) == ["open-starter"])
            let route = try #require(visible.first)
            let list = try MobileStarterPlaylists.playlist(for: route, portsRoot: ports)
            #expect(list.id == route.id)
            #expect(list.entries.map(\.level) == ["All/1", "All/2", "All/3"])
            let preview = MobileListLibrary(entries: list.entries, name: list.name, catalogue: catalogue)
            #expect(preview.levels.map(\.title) == starter.levels.map(\.title))
            #expect(try preview.loadLevel(at: 0).session.levelIdentifier == GameStarterContent.identifier + "/All/1")
        }
    }

    @Test func starterAvailabilityAndPixels() throws {
        try withStarter { library in
            #expect(library.isStarter)
            #expect(library.levels.count == 3)
            let session = try #require(library.loadLevel(at: 0).session as? ClassicMobileSession)
            #expect(session.needsArtworkProvider)
            session.artworkProvider = try FixtureArtwork()
            for _ in 0..<100 where session.targetCandidates(for: 0).isEmpty { session.tick() }
            let target = try #require(session.targetCandidates(for: 0).first)
            let frame = try session.render(highlight: nil)
            let pixels = [UInt8](frame.rgba)
            var redPixels = 0
            for y in max(0, Int(target.point.y) - 26)..<min(frame.height, Int(target.point.y) + 8) {
                for x in max(0, Int(target.point.x) - 16)..<min(frame.width, Int(target.point.x) + 18) {
                    let offset = (y * frame.width + x) * 4
                    if pixels[offset] > 180 && pixels[offset + 1] < 80 && pixels[offset + 2] < 80 { redPixels += 1 }
                }
            }
            #expect(redPixels > 0)
            #expect(session.levelIdentifier.hasPrefix(GameStarterContent.identifier))
            let empty = library.directory.appendingPathComponent("missing")
            #expect(try MobileContentStore(root: empty).loadLibrary() == nil)
            #expect(!FileManager.default.fileExists(atPath: empty.path))
        }
    }

    @Test func starterPuzzles() throws {
        try withStarter { library in
            for index in 0..<3 {
                let session = try library.loadLevel(at: index).session
                let control: Int? = index == 1 ? 1 : index == 2 ? 0 : nil
                while !session.snapshot.isComplete && session.snapshot.tick < 4_000 {
                    session.tick()
                    if let control {
                        for target in session.targetCandidates(for: control) where target.assignment == .eligible {
                            #expect(session.assign(control: control, to: target.id))
                        }
                    }
                }
                #expect(session.snapshot.didWin)
                #expect(session.snapshot.saved == session.snapshot.total)
            }
        }
    }

    @Test func characterChoiceAndCheckpoints() throws {
        try withStarter { library in
            let session = try #require(library.loadLevel(at: 0).session as? ClassicMobileSession)
            let provider = try FixtureArtwork()
            session.artworkProvider = provider
            for _ in 0..<90 { session.tick() }
            let snapshot = session.snapshot
            let payload = try session.checkpointPayload()
            provider.isEnabled = false
            _ = try session.render(highlight: nil)
            provider.isEnabled = true
            _ = try session.render(highlight: nil)
            #expect(session.snapshot == snapshot)
            #expect(try sameCleanCheckpoint(payload, session.checkpointPayload()))
            let restored = try #require(library.loadLevel(at: 0).session as? ClassicMobileSession)
            restored.artworkProvider = try FixtureArtwork()
            try restored.restoreCheckpointPayload(payload)
            #expect(restored.snapshot == snapshot)
            for _ in 0..<80 { session.tick(); restored.tick() }
            #expect(restored.snapshot == session.snapshot)
        }
    }

    @Test func validatedImport() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? manager.removeItem(at: root) }
        let source = root.appendingPathComponent("Selected")
        try manager.createDirectory(at: source, withIntermediateDirectories: true)
        let file = source.appendingPathComponent("fixture.dat")
        try Data("accepted".utf8).write(to: file)
        let store = MobileContentStore(root: root.appendingPathComponent("Store")) { staged in
            guard try Data(contentsOf: staged.appendingPathComponent("fixture.dat")) == Data("accepted".utf8)
            else { throw CleanContentFailure.invalidImport }
        }
        try store.install(directory: source)
        try Data("rejected".utf8).write(to: file)
        #expect(throws: CleanContentFailure.invalidImport) { try store.install(directory: source) }
        #expect(try Data(contentsOf: store.gameDataDirectory.appendingPathComponent("fixture.dat")) == Data("accepted".utf8))
        try Data("accepted".utf8).write(to: file)
        try manager.createSymbolicLink(at: source.appendingPathComponent(".hidden-link"), withDestinationURL: file)
        #expect(throws: MobileContentStoreError.symbolicLink) { try store.install(directory: source) }
    }
}
