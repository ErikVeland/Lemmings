import Foundation
import ImageIO
import NxlvKit

// Only the sequel selection values are needed by the production preview source contract.
enum Lemmings2PlayWindow {
    struct LevelSelection: Sendable { let tribe: Int; let level: Int }
}
enum Lemmings3PlayWindow {
    struct LevelSelection: Sendable { let tribe: Lemmings3ClassicCampaign.Tribe; let level: Int }
}

@MainActor enum ArcadeStore {
    static let shared = ProgressBoundary()
    struct ProgressBoundary {
        func progressKey(_ key: String) -> String {
            preconditionFailure("Starter previews must not access player progress.")
        }
    }
}

private struct Failure: Error { let message: String }
private func check(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    guard try condition() else { throw Failure(message: message) }
}

private func run() async throws {
    guard let path = ProcessInfo.processInfo.environment["LEMMIX_PREVIEW_TEST_LIX_DIRECTORY"],
          let output = ProcessInfo.processInfo.environment["LEMMIX_PREVIEW_TEST_CAPTURES"] else {
        throw Failure(message: "Set the prepared Lix artwork and test capture directories.")
    }
    let artwork = try LixSceneArtwork(directory: URL(fileURLWithPath: path))
    let dataSet = try OpenStarterContent.makeDataSet()
    let absent = FileManager.default.temporaryDirectory.appendingPathComponent("AbsentStarter-\(UUID())")
    try check(!FileManager.default.fileExists(atPath: absent.path), "The no-data fixture unexpectedly exists.")
    let store = LevelPreviewStore()
    for (index, theme) in [LixSceneArtwork.Theme.brick, .earth, .wood].enumerated() {
        let source = LevelPreviewSource.classic(dataSet: dataSet, root: absent, levelIndex: index,
                                               sourceFingerprint: nil, lixArtworkDirectory: URL(fileURLWithPath: path))
        let revision = try source.sourceRevision()
        try check(!revision.isEmpty, "The generated starter has no source revision.")
        let identity = LevelCatalogueIdentity(engine: .classic, packID: dataSet.identifierKey,
                                             levelID: "starter-\(index)")
        let actual = try await store.bitmap(for: LevelPreviewRequest(identity: identity,
            catalogueRevision: revision, source: source))
        let level = dataSet.campaign.levels[index].level
        try check(level.startX == 0, "The hand-checked starter preview origin changed.")
        let rendered = try ClassicLevelRenderer.render(level, groundSet: OpenStarterContent.makeGroundSet())
        let simulation = try ClassicDOSSimulation(level: level, renderedLevel: rendered,
            mechanics: ClassicDOSMechanics(title: nil, rank: "Starter"))
        let frame = artwork.frame(rendered, simulation: simulation, theme: theme, pixelScale: 1)
        var expected = Data()
        for row in 0..<160 {
            let offset = row * frame.width * 4
            expected.append(frame.rgba.subdata(in: offset..<(offset + 320 * 4)))
        }
        try check(actual.width == 320 && actual.height == 160 && actual.rgba == expected,
                  "The starter thumbnail does not contain the actual Lix scene pixels.")
        let provider = CGDataProvider(data: actual.rgba as CFData)!
        let image = CGImage(width: 320, height: 160, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: 1280, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let url = URL(fileURLWithPath: output).appendingPathComponent("starter-preview-\(index + 1).png")
        let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        try check(CGImageDestinationFinalize(destination), "The starter thumbnail capture could not be saved.")
    }
    let manifestRoot = FileManager.default.temporaryDirectory.appendingPathComponent("StarterManifest-\(UUID())")
    try FileManager.default.createDirectory(at: manifestRoot, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: manifestRoot) }
    let manifest = manifestRoot.appendingPathComponent("manifest.json")
    try Data("{\"starter\":1}".utf8).write(to: manifest)
    guard let manifestRevision = FanLevelLibrary.classicSourceRevision(for: nil, root: manifestRoot) else {
        throw Failure(message: "The starter manifest has no directory revision.")
    }
    let source = LevelPreviewSource.classic(dataSet: dataSet, root: manifestRoot, levelIndex: 0,
        sourceFingerprint: manifestRevision, lixArtworkDirectory: URL(fileURLWithPath: path))
    try check(try source.sourceRevision() == manifestRevision, "The supplied starter manifest revision changed.")
    _ = try await store.bitmap(for: LevelPreviewRequest(identity: .init(engine: .classic, packID: "manifest", levelID: "0"),
        catalogueRevision: manifestRevision, source: source))
    try Data("{\"starter\":2}".utf8).write(to: manifest)
    var changedRejected = false
    do {
        _ = try await LevelPreviewStore().bitmap(for: LevelPreviewRequest(identity: .init(engine: .classic, packID: "changed", levelID: "0"),
            catalogueRevision: manifestRevision, source: source))
    } catch { changedRejected = true }
    try check(changedRejected, "A changed starter manifest bypassed revision validation.")
    let archive = "archive-byte-revision"
    let entry = FanLevelLibrary.Entry(file: "example.lvl", section: nil, label: "Example")
    let legacyFan = LevelPreviewSource.fanClassic(pack: absent, entry: entry,
        archiveFingerprint: archive, portsRoot: absent)
    try check(try legacyFan.sourceRevision() == archive, "A legacy fan preview changed its source revision.")
    let ownedFan = LevelPreviewSource.fanClassic(pack: absent, entry: entry,
        archiveFingerprint: archive, portsRoot: absent, ownedClassicRoots: [manifestRoot])
    let ownedRevision = try ownedFan.sourceRevision()
    try Data("{\"starter\":3}".utf8).write(to: manifest)
    try check(try ownedFan.sourceRevision() != ownedRevision,
              "A changed installed style failed to invalidate its fan preview revision.")
    var missingArtworkRejected = false
    do {
        let missing = LevelPreviewSource.classic(dataSet: dataSet, root: absent, levelIndex: 0, sourceFingerprint: nil)
        _ = try await store.bitmap(for: LevelPreviewRequest(identity: .init(engine: .classic, packID: "missing-art", levelID: "0"),
            catalogueRevision: "missing-art", source: missing))
    } catch { missingArtworkRejected = true }
    try check(missingArtworkRejected, "Missing Lix artwork silently used primitive starter graphics.")
    print("PASS all three generated starter previews: no game-data directory, stable revisions, exact brick/earth/wood Lix pixels, manifest change detection and no primitive fallback")
}

Task {
    do { try await run(); exit(0) }
    catch {
        let message = (error as? Failure)?.message ?? error.localizedDescription
        FileHandle.standardError.write(Data(("FAIL " + message + "\n").utf8))
        exit(1)
    }
}
dispatchMain()
