import Foundation
import NxlvKit

// Settings exist so choices can be mixed. What matters is that only workable
// choices are offered, and that a stored choice pointing at data which is no
// longer there gets corrected rather than left broken.

private struct Failure: Error, CustomStringConvertible {
    let description: String
}

private func require(
    _ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw Failure(description: message()) }
}

private func testOptionsFollowInstalledData() throws {
    let bare = ClassicSettingsOptions.available(
        hasDOSData: true, hasAmigaDisk: false, hasMacintoshDisk: false, moduleCount: 0)
    try require(bare.graphics == [.dosVGA], "only DOS artwork should be offered")
    try require(
        !bare.music.contains(.amigaModules),
        "module music was offered with no modules installed")
    try require(
        !bare.sound.contains(.macintoshResources),
        "Macintosh sound was offered with no Macintosh disk")

    let full = ClassicSettingsOptions.available(
        hasDOSData: true, hasAmigaDisk: true, hasMacintoshDisk: true, moduleCount: 22)
    try require(full.graphics.count == 3, "three artwork sources should be offered")
    try require(full.music.contains(.amigaModules), "modules should be offered")
    try require(full.music.contains(.macintoshMIDI), "Macintosh music should be offered")
    try require(full.sound.contains(.macintoshResources), "Macintosh sound should be offered")
    print("PASS the options offered follow the data installed")
}

private func testUndecodedSourcesAreNotOffered() throws {
    // The Ad-Lib synthesizer exists but its sequencer is not decoded, so
    // offering DOS music would fail the moment it was chosen.
    let options = ClassicSettingsOptions.available(
        hasDOSData: true, hasAmigaDisk: true, hasMacintoshDisk: true, moduleCount: 22)
    try require(
        !options.music.contains(.dosAdlib),
        "DOS music was offered while its sequencer is undecoded")
    try require(
        !options.sound.contains(.dosAdlib),
        "DOS sound was offered while its sequencer is undecoded")
    print("PASS sources that are not decoded yet are not offered")
}

private func testMixingAcrossMachines() throws {
    let options = ClassicSettingsOptions.available(
        hasDOSData: true, hasAmigaDisk: false, hasMacintoshDisk: true, moduleCount: 22)
    var settings = ClassicSettings()
    settings.graphics = .dosVGA
    settings.music = .amigaModules
    settings.sound = .macintoshResources
    try require(
        options.allows(settings),
        "DOS artwork with Amiga music and Macintosh sound should be allowed")
    print("PASS artwork, music and sound can come from different machines")
}

private func testStoredChoicesAreCorrected() throws {
    // A folder was moved since the settings were saved.
    var stored = ClassicSettings()
    stored.graphics = .macintosh
    stored.music = .macintoshMIDI
    stored.sound = .macintoshResources

    let options = ClassicSettingsOptions.available(
        hasDOSData: true, hasAmigaDisk: false, hasMacintoshDisk: false, moduleCount: 22)
    try require(!options.allows(stored), "the stored settings should not be allowed")

    let corrected = options.correcting(stored)
    try require(options.allows(corrected), "correction produced settings still not allowed")
    try require(corrected.graphics == .dosVGA, "artwork was not corrected to what exists")
    try require(corrected.music == .amigaModules, "music was not corrected to what exists")
    try require(corrected.sound == .silent, "sound should fall back to none")
    print("PASS settings pointing at missing data are corrected")
}

private func testPresetsMatchMachines() throws {
    let amiga = ClassicSettings.matching(.amiga)
    try require(amiga.colorDepth == .amigaOCS, "the Amiga preset should reduce colour")
    try require(amiga.music == .amigaModules, "the Amiga preset should use modules")
    try require(amiga.display == .monitor, "the Amiga preset should use a monitor")

    let modern = ClassicSettings.matching(.modern)
    try require(modern.colorDepth == .full, "the modern preset should not reduce colour")
    try require(modern.display == .flat, "the modern preset should use a flat panel")
    print("PASS a machine preset fills the settings in")
}

private func testRemixesAndCustomArtwork() throws {
    let options = ClassicSettingsOptions.available(
        hasDOSData: true, hasAmigaDisk: false, hasMacintoshDisk: false, moduleCount: 0,
        remixFolders: ["Orchestral Remix"], customGraphics: ["High Resolution"])
    try require(
        options.music.contains(.remix(name: "Orchestral Remix")),
        "a supplied remix folder was not offered")
    try require(
        options.graphics.contains(.custom(name: "High Resolution")),
        "supplied artwork was not offered")
    print("PASS supplied remixes and artwork are offered alongside the originals")
}

private func testRoundTrip() throws {
    var settings = ClassicSettings.matching(.amiga)
    settings.music = .remix(name: "Orchestral Remix")
    settings.musicStyle = .modern
    let data = try JSONEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(ClassicSettings.self, from: data)
    try require(decoded == settings, "settings changed across a save and load")
    print("PASS settings survive being saved and loaded")
}

do {
    try testOptionsFollowInstalledData()
    try testUndecodedSourcesAreNotOffered()
    try testMixingAcrossMachines()
    try testStoredChoicesAreCorrected()
    try testPresetsMatchMachines()
    try testRemixesAndCustomArtwork()
    try testRoundTrip()
    print("Classic settings tests passed.")
} catch {
    FileHandle.standardError.write(Data("Settings tests failed: \(error)\n".utf8))
    exit(1)
}
