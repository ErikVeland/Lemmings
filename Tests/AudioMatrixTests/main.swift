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

private func testAdlibSequencerInit() throws {
    var seq = AdlibSequencer()
    seq.playTune(index: 0)
    var buffer = [Float](repeating: 0, count: 1024)
    seq.render(into: &buffer)
    try require(buffer.count == 1024, "Buffer size mismatch")
    print("PASS AdlibSequencer initialization and render test")
}

private func testSNESAudioPlayer() throws {
    var snes = SNESAudioPlayer()
    snes.loadTrack(index: 1)
    var buffer = [Float](repeating: 0, count: 512)
    snes.render(into: &buffer)
    try require(buffer.count == 512, "SNES buffer size mismatch")
    print("PASS SNESAudioPlayer track loading test")
}

private func testGenesisFMPlayer() throws {
    var genesis = GenesisFMPlayer()
    genesis.loadTrack(index: 0)
    var buffer = [Float](repeating: 0, count: 512)
    genesis.render(into: &buffer)
    try require(buffer.count == 512, "Genesis buffer size mismatch")
    print("PASS GenesisFMPlayer track loading test")
}

private func testAudioSettingsOptions() throws {
    let settings = ClassicSettings(
        music: .dosAdlib,
        sound: .amigaVoices
    )
    try require(settings.music == .dosAdlib, "Music setting mismatch")
    try require(settings.sound == .amigaVoices, "Sound setting mismatch")

    let options = ClassicSettingsOptions.available(
        hasDOSData: true,
        hasAmigaDisk: true,
        hasMacintoshDisk: true,
        moduleCount: 14
    )
    try require(options.music.contains(.dosAdlib), "Options missing DOS Ad-Lib")
    try require(options.music.contains(.snesSPC), "Options missing SNES SPC")
    try require(options.music.contains(.genesisFM), "Options missing Genesis FM")
    try require(options.sound.contains(.amigaVoices), "Options missing Amiga Voices")

    print("PASS AudioSettingsOptions multi-port matrix test")
}

do {
    try testAdlibSequencerInit()
    try testSNESAudioPlayer()
    try testGenesisFMPlayer()
    try testAudioSettingsOptions()
    print("Audio matrix tests passed successfully.")
} catch {
    FileHandle.standardError.write(Data("Audio matrix tests failed: \(error)\n".utf8))
    exit(1)
}
