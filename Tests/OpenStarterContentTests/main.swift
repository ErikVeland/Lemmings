import Foundation
import NxlvKit

private struct Failure: Error, CustomStringConvertible {
    let description: String
}

private func require(_ value: @autoclosure () -> Bool, _ message: String) throws {
    guard value() else { throw Failure(description: message) }
}

private func run(_ level: ClassicLevel, assign skill: ClassicSkill?) throws -> ClassicDOSSimulation {
    let rendered = try ClassicLevelRenderer.render(level, groundSet: OpenStarterContent.makeGroundSet())
    var game = try ClassicDOSSimulation(level: level, renderedLevel: rendered)
    while !game.isComplete && game.tickCount < 4_000 {
        _ = game.tick()
        if let skill {
            for lemming in game.lemmings where lemming.isActive {
                let needsSkill = skill == .floater ? !lemming.hasFloater : !lemming.hasClimber
                if needsSkill {
                    try require(game.assign(skill, to: lemming.id) == .assigned, "Starter skill assignment failed.")
                }
            }
        }
    }
    return game
}

private func testStarter() throws {
    let set = try OpenStarterContent.makeDataSet()
    try require(OpenStarterContent.isStarter(set), "The starter marker must be stable.")
    try require(set.title == nil && set.campaign.levels.count == 3, "The starter must be an independent three-level campaign.")
    let ground = OpenStarterContent.makeGroundSet()
    try require(ground.terrain.count == 2 && ground.objects.count == 2, "Starter artwork is incomplete.")
    let skills: [ClassicSkill?] = [nil, .floater, .climber]
    for (index, entry) in set.campaign.levels.enumerated() {
        for skill in [ClassicSkill.basher, .miner, .digger, .bomber, .builder, .blocker] {
            try require(entry.level.skills[skill] == 0, "The starter exposes an unsupported skill.")
        }
        let won = try run(entry.level, assign: skills[index])
        try require(won.didWin && won.savedCount == entry.level.lemmingCount, "Starter route did not rescue every worker: \(entry.level.title).")
        try require(won.comparisonDestructionMasks == nil, "The starter must not require commercial destruction masks.")
        if index > 0 {
            let unassisted = try run(entry.level, assign: nil)
            try require(!unassisted.didWin, "The authored puzzle does not require its advertised skill.")
        }
        print("PASS starter route \(index + 1): \(won.savedCount) rescued at tick \(won.tickCount)")
    }
}

private final class PromotionFailure: FileManager, @unchecked Sendable {
    var rejectPromotion = false

    override func moveItem(at source: URL, to target: URL) throws {
        if rejectPromotion && source.lastPathComponent.hasPrefix("Import-") {
            rejectPromotion = false
            throw Failure(description: "Injected replacement failure.")
        }
        try super.moveItem(at: source, to: target)
    }
}

private func testImports() throws {
    let manager = FileManager.default
    let folder = manager.temporaryDirectory.appendingPathComponent("BYO-tests-\(UUID().uuidString)", isDirectory: true)
    try manager.createDirectory(at: folder, withIntermediateDirectories: false)
    defer { try? manager.removeItem(at: folder) }
    let source = folder.appendingPathComponent("Selected", isDirectory: true)
    try manager.createDirectory(at: source, withIntermediateDirectories: false)
    let file = source.appendingPathComponent("DATA.DAT")
    try Data("accepted".utf8).write(to: file)
    let validator: BYOContentValidator = { directory, _ in
        let value = try Data(contentsOf: directory.appendingPathComponent("DATA.DAT"))
        guard value == Data("accepted".utf8) else { throw Failure(description: "Rejected synthetic data.") }
    }
    let moves = PromotionFailure()
    let store = BYOIntegration(root: folder.appendingPathComponent("Installed"), fileManager: { moves }, validator: validator)
    for game in BYOGame.allCases {
        let result = try store.install(directory: source, game: game)
        try require(result.fileCount == 1 && result.bytes == 8, "Import receipt is incorrect.")
        try require(store.installedDirectory(for: game) == result.directory, "The installed game lookup failed.")
        _ = try store.verifyInstalled(game: game)
        moves.rejectPromotion = true
        do {
            try store.install(directory: source, game: game)
            throw Failure(description: "The replacement failure was ignored.")
        } catch let error as Failure {
            try require(error.description == "Injected replacement failure.", "Unexpected rollback test result.")
        }
        _ = try store.verifyInstalled(game: game)
        try Data("rejected".utf8).write(to: file)
        do {
            try store.install(directory: source, game: game)
            throw Failure(description: "Malformed staged data was installed.")
        } catch let error as Failure {
            try require(error.description == "Rejected synthetic data.", "Unexpected staged validation result.")
        }
        _ = try store.verifyInstalled(game: game)
        try Data("accepted".utf8).write(to: file)
    }
    let installed = store.installedDirectory(for: .classic)!
    try Data("changed".utf8).write(to: installed.appendingPathComponent("DATA.DAT"))
    do {
        _ = try store.verifyInstalled(game: .classic)
        throw Failure(description: "Changed installed data passed verification.")
    } catch BYOIntegrationError.invalidManifest { }
    let limited = BYOIntegration(root: folder.appendingPathComponent("Limited"),
        limits: .init(maximumBytes: 1), validator: validator)
    do {
        try limited.install(directory: source, game: .classic)
        throw Failure(description: "The byte limit was ignored.")
    } catch BYOIntegrationError.exceedsLimits { }
    try manager.createSymbolicLink(at: source.appendingPathComponent(".hidden-link"), withDestinationURL: file)
    do {
        try store.install(directory: source, game: .classic)
        throw Failure(description: "A hidden symbolic link was imported.")
    } catch BYOIntegrationError.symbolicLink { }
    try manager.removeItem(at: source.appendingPathComponent(".hidden-link"))
    for game in BYOGame.allCases {
        do {
            try BYOIntegration.validateGame(directory: source, game: game)
            throw Failure(description: "The native validator accepted incomplete \(game.rawValue) files.")
        } catch is Failure { throw Failure(description: "The native validator accepted incomplete files.") }
        catch { }
    }
    print("PASS imports: all engines, staged rejection, rollback, tamper detection, byte limits and hidden links")
}

do {
    try testStarter()
    try testImports()
    print("PASS open starter and player-owned import checks")
} catch {
    FileHandle.standardError.write(Data("FAIL: \(error)\n".utf8))
    exit(1)
}
