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

private func testSNESLevelDecoder() throws {
    let levels = SNESLevelDecoder.sunsoftSpecialLevels
    try require(levels.count == 5, "Expected 5 Sunsoft Special levels, got \(levels.count)")
    for (idx, level) in levels.enumerated() {
        try require(level.isSunsoftSpecial, "Level \(level.title) is not marked Sunsoft Special")
        try require(level.title == "Sunsoft Special \(idx + 1)", "Unexpected title \(level.title)")
    }
    print("PASS SNESLevelDecoder 5 Sunsoft Special levels verified")
}

private func testGenesisLevelDecoder() throws {
    let levels = GenesisLevelDecoder.presenterLevels
    try require(levels.count == 30, "Expected 30 Genesis Presenter levels, got \(levels.count)")
    try require(levels[0].title == "Presenter 1", "First presenter level title mismatch")
    print("PASS GenesisLevelDecoder 30 Presenter levels verified")
}

private func testArcadeLevelDecoder() throws {
    let levels = ArcadeLevelDecoder.arcadeLevels
    try require(!levels.isEmpty, "Arcade levels list is empty")
    try require(levels.contains(where: \.isTwoPlayerCoOp), "Missing Arcade Co-Op stage")
    print("PASS ArcadeLevelDecoder bonus stages verified")
}

/// These four titles were retired, and this records why.
///
/// Three of them never had levels. `SNESLevelDecoder` returns a fixed list
/// whatever ROM it is handed, `GenesisLevelDecoder` builds its entries from a
/// formula, and neither carries terrain, so nothing could be drawn or played.
/// The arcade set has a ROM on disk but no decoder.
///
/// The fourth, the Amiga two-player levels, is real and did not go away: those
/// twenty levels live in "Oh Yes! More Lemmings!" alongside ten more from Oh
/// No! and the thirty Mega Drive levels Sunsoft wrote. Keeping the old title as
/// well would have listed the same levels twice and counted them twice.
///
/// Restore a title here only when its levels load with terrain.
private func testRetiredTitlesAreGone() throws {
    let names = ClassicTitle.allCases.map(\.rawValue)
    for retired in ["snesSunsoftSpecial", "genesisPresenter", "arcadeBonus", "amigaTwoPlayer"] {
        try require(
            !names.contains(retired),
            "\(retired) is back in the library. It needs levels that load, not just a name")
    }
    // The pack that replaced the one real title is still there.
    try require(
        names.contains("ohYesMoreLemmings"),
        "the port-exclusive pack is missing from the library")
    print("PASS the four titles with no playable levels stay out of the library")
}

do {
    try testSNESLevelDecoder()
    try testGenesisLevelDecoder()
    try testArcadeLevelDecoder()
    try testRetiredTitlesAreGone()
    print("Platform exclusive tests passed successfully.")
} catch {
    FileHandle.standardError.write(Data("Platform exclusive tests failed: \(error)\n".utf8))
    exit(1)
}
