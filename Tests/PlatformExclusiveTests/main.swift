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

private func testSagaPlatformTitleIntegration() throws {
    let titles: [ClassicTitle] = [
        .snesSunsoftSpecial,
        .genesisPresenter,
        .arcadeBonus,
        .amigaTwoPlayer
    ]
    for title in titles {
        try require(title.expectedLevelCount != nil, "Missing expected level count for \(title.displayName)")
        let campaignDef = ClassicCampaignDefinition.festive(title)
        try require(campaignDef != nil, "Missing campaign definition for \(title.displayName)")
    }
    print("PASS ClassicSaga and ClassicCampaign integration for platform titles verified")
}

do {
    try testSNESLevelDecoder()
    try testGenesisLevelDecoder()
    try testArcadeLevelDecoder()
    try testSagaPlatformTitleIntegration()
    print("Platform exclusive tests passed successfully.")
} catch {
    FileHandle.standardError.write(Data("Platform exclusive tests failed: \(error)\n".utf8))
    exit(1)
}
