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

private func testAdaptiveDJEngineChillState() throws {
    var dj = AdaptiveDJEngine()
    let telemetry = AdaptiveDJEngine.Telemetry(
        releasedCount: 10,
        totalCount: 100,
        savedCount: 2,
        requiredCount: 50,
        releaseRate: 30,
        dangerCount: 0,
        remainingSeconds: 240,
        isNuking: false,
        didWin: false
    )
    let energy = dj.evaluate(telemetry: telemetry)
    try require(energy == .chill, "Expected .chill energy state, got \(energy)")
    print("PASS AdaptiveDJEngine chill state evaluation verified")
}

private func testAdaptiveDJEngineBuildingState() throws {
    var dj = AdaptiveDJEngine()
    let telemetry = AdaptiveDJEngine.Telemetry(
        releasedCount: 40,
        totalCount: 100,
        savedCount: 30,
        requiredCount: 50,
        releaseRate: 60,
        dangerCount: 2,
        remainingSeconds: 180,
        isNuking: false,
        didWin: false
    )
    let energy = dj.evaluate(telemetry: telemetry)
    try require(energy == .building, "Expected .building energy state, got \(energy)")
    print("PASS AdaptiveDJEngine building state evaluation verified")
}

private func testAdaptiveDJEngineNukeDropState() throws {
    var dj = AdaptiveDJEngine()
    let telemetry = AdaptiveDJEngine.Telemetry(
        releasedCount: 50,
        totalCount: 100,
        savedCount: 20,
        requiredCount: 50,
        releaseRate: 99,
        dangerCount: 10,
        remainingSeconds: 100,
        isNuking: true,
        didWin: false
    )
    let energy = dj.evaluate(telemetry: telemetry)
    try require(energy == .nukeDrop, "Expected .nukeDrop energy state, got \(energy)")
    print("PASS AdaptiveDJEngine nuke drop state evaluation verified")
}

private func testAdaptiveDJEngineVictoryState() throws {
    var dj = AdaptiveDJEngine()
    let telemetry = AdaptiveDJEngine.Telemetry(
        releasedCount: 60,
        totalCount: 60,
        savedCount: 60,
        requiredCount: 50,
        releaseRate: 99,
        dangerCount: 0,
        remainingSeconds: 120,
        isNuking: false,
        didWin: true
    )
    let energy = dj.evaluate(telemetry: telemetry)
    try require(energy == .victory, "Expected .victory energy state, got \(energy)")
    print("PASS AdaptiveDJEngine victory state evaluation verified")
}

private func testAdaptiveDJIsOfferedOnlyWithSoundtracks() throws {
    // The mix moves between the soundtracks the player supplied. With none
    // installed it has nothing to play, so it must not appear in the menu.
    let withoutSoundtracks = ClassicSettingsOptions.available(
        hasDOSData: true, hasAmigaDisk: true, hasMacintoshDisk: true,
        moduleCount: 14, hasSoundtracks: false)
    try require(
        !withoutSoundtracks.music.contains(.adaptiveDJ),
        "The mix was offered with no soundtrack installed")

    let withSoundtracks = ClassicSettingsOptions.available(
        hasDOSData: true, hasAmigaDisk: true, hasMacintoshDisk: true,
        moduleCount: 14, remixFolders: ["Studio recordings"], hasSoundtracks: true)
    try require(
        withSoundtracks.music.contains(.adaptiveDJ),
        "The mix was not offered although a soundtrack is installed")

    // Whatever the menu holds, the default must be something that plays on a
    // machine with nothing extra installed.
    let settings = ClassicSettings()
    try require(
        withoutSoundtracks.music.contains(settings.music),
        "The default music source is not offered on a plain installation")
    print("PASS the mix is offered only when there is a soundtrack for it to play")
}

do {
    try testAdaptiveDJEngineChillState()
    try testAdaptiveDJEngineBuildingState()
    try testAdaptiveDJEngineNukeDropState()
    try testAdaptiveDJEngineVictoryState()
    try testAdaptiveDJIsOfferedOnlyWithSoundtracks()
    print("Adaptive DJ tests passed successfully.")
} catch {
    FileHandle.standardError.write(Data("Adaptive DJ tests failed: \(error)\n".utf8))
    exit(1)
}
