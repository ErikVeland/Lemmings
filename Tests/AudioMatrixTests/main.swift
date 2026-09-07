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

/// Records what these players actually produce today.
///
/// None of the three decodes its source format yet, so each one renders
/// silence. These tests pin that down so the day a real decoder lands, the
/// test fails and has to be rewritten to describe the new behaviour. The
/// previous version asserted `buffer.count`, which a silent player and a
/// working player both satisfy.
private func isSilent(_ buffer: [Float]) -> Bool { buffer.allSatisfy { $0 == 0 } }

private func testAdlibSequencerRendersSilence() throws {
    var seq = AdlibSequencer()
    seq.loadDriver(data: Data([0xDE, 0xAD, 0xBE, 0xEF]))
    seq.playTune(index: 0)
    var buffer = [Float](repeating: 1, count: 1024)
    seq.render(into: &buffer)
    try require(buffer.count == 1024, "AdLib render changed the buffer length")
    try require(
        isSilent(buffer),
        "AdLib rendered audio. The sequencer now decodes something, so rewrite this test")
    print("PASS AdlibSequencer renders silence, because the driver format is undecoded")
}

private func testSNESAudioPlayerRendersSilence() throws {
    var snes = SNESAudioPlayer()
    snes.loadTrack(index: 1)
    var buffer = [Float](repeating: 1, count: 512)
    snes.render(into: &buffer)
    try require(buffer.count == 512, "SNES render changed the buffer length")
    try require(
        isSilent(buffer),
        "SNES rendered audio. The player now decodes something, so rewrite this test")
    print("PASS SNESAudioPlayer renders silence, because there is no SPC700 core")
}

private func testGenesisFMPlayerRendersSilence() throws {
    var genesis = GenesisFMPlayer()
    genesis.loadTrack(index: 0)
    var buffer = [Float](repeating: 1, count: 512)
    genesis.render(into: &buffer)
    try require(buffer.count == 512, "Genesis render changed the buffer length")
    try require(
        isSilent(buffer),
        "Genesis rendered audio. The player now decodes something, so rewrite this test")
    print("PASS GenesisFMPlayer renders silence, because there is no YM2612 core")
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
    // A source is offered only when something can play it. The players above
    // render silence, so their sources stay out of the menu however much game
    // data is installed. Offering them would give the player controls that
    // change nothing.
    try require(options.music.contains(.amigaModules), "Amiga modules should be offered")
    try require(!options.music.contains(.dosAdlib), "DOS Ad-Lib was offered with no sequencer")
    try require(!options.music.contains(.snesSPC), "SNES SPC was offered with no SPC700 core")
    try require(!options.music.contains(.genesisFM), "Genesis FM was offered with no YM2612 core")
    try require(!options.music.contains(.macintoshMIDI), "Macintosh MIDI was offered with no player")
    try require(
        options.sound.contains(.macintoshResources), "Macintosh sound should be offered")
    // The Amiga banks are decoded now, so this source is offered wherever the
    // Amiga data is installed. It used to be absent for want of a reader.
    try require(
        options.sound.contains(.amigaVoices),
        "Amiga voices should be offered once the Amiga data is installed")
    let withoutAmiga = ClassicSettingsOptions.available(
        hasDOSData: true, hasAmigaDisk: false, hasMacintoshDisk: true, moduleCount: 14)
    try require(
        !withoutAmiga.sound.contains(.amigaVoices),
        "Amiga voices were offered with no Amiga data installed")

    print("PASS only sources with a decoder behind them are offered")
}

do {
    try testAdlibSequencerRendersSilence()
    try testSNESAudioPlayerRendersSilence()
    try testGenesisFMPlayerRendersSilence()
    try testAudioSettingsOptions()
    print("Audio matrix tests passed successfully.")
} catch {
    FileHandle.standardError.write(Data("Audio matrix tests failed: \(error)\n".utf8))
    exit(1)
}
