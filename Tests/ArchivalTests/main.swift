import Foundation
import NxlvKit

private struct Failure: Error, CustomStringConvertible {
    let description: String
}

private func require(
    _ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw Failure(description: message()) }
}

private func testArchivalCatalogRegistry() throws {
    let platforms = ArchivalCatalog.platforms
    try require(platforms.count == 16, "Expected 16 registered ports, got \(platforms.count)")
    let amiga = ArchivalCatalog.platform(for: "amiga")
    try require(amiga != nil, "Amiga platform missing from catalog")
    try require(amiga?.exclusiveLevelCount == 20, "Amiga exclusive levels count mismatch")
    print("PASS ArchivalCatalog 16 ports registered and verified")
}

private func testArchivalAudioRegistry() throws {
    let soundtracks = ArchivalAudioRegistry.soundtracks
    let soundBanks = ArchivalAudioRegistry.soundBanks
    try require(soundtracks.count == 8, "Expected 8 archival soundtracks, got \(soundtracks.count)")
    try require(soundBanks.count == 5, "Expected 5 sound banks, got \(soundBanks.count)")
    print("PASS ArchivalAudioRegistry tracks and sound banks verified")
}

private func testArchivalGraphicsRegistry() throws {
    let modes = ArchivalGraphicsRegistry.graphicsModes
    try require(modes.count == 10, "Expected 10 graphics modes, got \(modes.count)")
    print("PASS ArchivalGraphicsRegistry modes verified")
}

do {
    try testArchivalCatalogRegistry()
    try testArchivalAudioRegistry()
    try testArchivalGraphicsRegistry()
    print("Archival edition tests passed successfully.")
} catch {
    FileHandle.standardError.write(Data("Archival tests failed: \(error)\n".utf8))
    exit(1)
}
