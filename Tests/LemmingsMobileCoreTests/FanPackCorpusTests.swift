import Foundation
import NxlvKit
import Testing
@testable import LemmingsMobileCore

/// Every bundled fan level must load through the iOS path, not just the Mac's.
struct FanPackCorpusTests {
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private static let packs = root.appendingPathComponent("Content/LevelPacks")
    private static let ports = root.appendingPathComponent(".build/ios-ports")

    @Test func everyBundledFanLevelLoadsRendersAndTicks() throws {
        guard FileManager.default.fileExists(atPath: Self.ports.path) else {
            Issue.record("Run Tools/IOSBeta/ports.py --destination .build/ios-ports first.")
            return
        }
        let files = try FileManager.default.contentsOfDirectory(at: Self.packs, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "zip" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        var failures: [String] = []
        var levels = 0
        var emptyPacks = 0
        for file in files {
            let library: ClassicFanMobileLibrary
            do { library = try ClassicFanMobileLibrary(packURL: file, portsRoot: Self.ports) }
            catch { emptyPacks += 1; continue }
            for summary in library.levels {
                do {
                    let content = try library.loadLevel(at: summary.index)
                    let frame = try content.session.render(highlight: nil)
                    guard frame.width > 0, frame.height > 0 else { throw MobileSessionError.frameUnavailable }
                    content.session.tick()
                    levels += 1
                    if levels.isMultiple(of: 500) { print("fan corpus progress: \(levels) levels") }
                } catch {
                    failures.append("\(file.lastPathComponent) #\(summary.number) \(summary.title): \(error)")
                }
            }
        }
        print("fan corpus: \(levels) levels loaded, \(failures.count) failed, \(emptyPacks) packs without levels")
        for failure in failures.prefix(40) { print("FAILED " + failure) }
        #expect(levels > 5_000)
        #expect(failures.isEmpty)
    }
}
