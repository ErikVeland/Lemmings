#if os(macOS)
import Foundation
import NxlvKit
import XCTest
@testable import LemmingsLocal

/// The shared pack reader must agree with the Mac's `unzip`-based library on every bundled pack.
final class FanPackParityTests: XCTestCase {
    private static let packs = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Content/LevelPacks")

    func testSharedReaderMatchesTheMacLibrary() throws {
        let files = FanLevelLibrary.packs(in: [Self.packs])
        XCTAssertGreaterThan(files.count, 500)
        var levels = 0
        for file in files {
            let shared = try ClassicFanPack(url: file)
            let mac = FanLevelLibrary.entries(in: file)
            let ours = shared.entries()
            XCTAssertEqual(ours.map { "\($0.file)#\($0.section ?? -1)|\($0.label)" },
                           mac.map { "\($0.file)#\($0.section ?? -1)|\($0.label)" }, file.lastPathComponent)
            XCTAssertEqual(shared.localStyleDirectory(includeHoliday: true),
                           FanLevelLibrary.localStyleDirectory(in: file, includeHoliday: true), file.lastPathComponent)
            XCTAssertEqual(shared.localStyleDirectory(), FanLevelLibrary.localStyleDirectory(in: file), file.lastPathComponent)
            XCTAssertEqual(shared.fingerprint, FanLevelLibrary.archiveFingerprint(file), file.lastPathComponent)
            for (entry, macEntry) in zip(ours, mac) {
                let a = try shared.level(entry)
                let b = try FanLevelLibrary.level(macEntry, in: file)
                XCTAssertEqual(a.0, b.0, "\(file.lastPathComponent) \(entry.label)")
                XCTAssertEqual(a.1, b.1)
                XCTAssertEqual(String(describing: shared.mechanics(for: entry)),
                               String(describing: FanLevelLibrary.mechanics(for: file, entry: macEntry)))
                levels += 1
            }
        }
        XCTAssertGreaterThan(levels, 5_000)
    }
}
#endif
