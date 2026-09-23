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
    let upgraded = try JSONDecoder().decode(ClassicSettings.self, from: Data("{}".utf8))
    try require(upgraded.bottomFallSounds && ClassicSettings().bottomFallSounds, "Bottom falls must default on for new and existing players")
    var quiet = upgraded
    quiet.bottomFallSounds = false
    let restoredQuiet = try JSONDecoder().decode(ClassicSettings.self, from: JSONEncoder().encode(quiet))
    try require(!restoredQuiet.bottomFallSounds, "The bottom-fall preference was not saved")
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
    try require(full.graphics == [.macintosh, .amiga, .dosVGA], "Mac artwork should be listed first")
    try require(ClassicSettings().graphics == .macintosh, "Mac artwork should be the default")
    for choice in full.graphics {
        var selected = ClassicSettings()
        selected.graphics = choice
        let saved = try JSONEncoder().encode(selected)
        let restored = try JSONDecoder().decode(ClassicSettings.self, from: saved)
        try require(full.correcting(restored).graphics == choice, "A saved artwork choice was replaced")
    }
    try require(full.music.contains(.amigaModules), "modules should be offered")
    // Macintosh MIDI is deliberately absent. The release carries the data but
    // nothing plays it yet, and the rule below is that an unplayable source is
    // never offered.
    try require(!full.music.contains(.macintoshMIDI), "Macintosh music has no player yet")
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

    // The rule holds for every source, not only the ones named above. A new
    // source added to the enum must not reach the menu before its decoder
    // does. Soundtracks the player supplied are exempt, because a folder of
    // audio files always plays.
    for choice in options.music {
        if case .remix = choice { continue }
        try require(
            ClassicSettingsOptions.playableMusic.contains(choice),
            "\(choice.displayName) was offered with nothing to play it")
    }
    for choice in options.sound {
        try require(
            ClassicSettingsOptions.playableSound.contains(choice),
            "\(choice.displayName) was offered with nothing to play it")
    }
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

/// A build that adds a setting must not throw away what the player chose.
private func testOlderSettingsStillLoad() throws {
    // Written by a build with no shuffle settings.
    let older = """
    {"graphics":{"dosVGA":{}},"colorDepth":"full","display":"monitor",
     "displayIntensity":0.5,"pixelAspect":1.2,"integerScaling":false,
     "music":{"amigaModules":{}},"musicStyle":"modern","musicVolume":0.25,
     "sound":{"macintoshResources":{}},"soundVolume":0.4}
    """
    let restored = try JSONDecoder().decode(ClassicSettings.self, from: Data(older.utf8))
    try require(restored.display == .monitor, "the chosen screen was lost")
    try require(restored.musicVolume == 0.25, "the chosen music volume was lost")
    try require(restored.pixelAspect == 1.2, "the chosen pixel width was lost")
    try require(!restored.integerScaling, "the chosen scaling was lost")
    try require(!restored.shuffleGraphics, "a missing setting should default to off")
    try require(!restored.shuffleMusic, "a missing setting should default to off")
    try require(restored.favorApproachingLemmings, "a missing setting should default to on")

    // And the new settings survive a round trip.
    var shuffled = restored
    shuffled.shuffleGraphics = true
    shuffled.shuffleMusic = true
    shuffled.favorApproachingLemmings = false
    let again = try JSONDecoder().decode(
        ClassicSettings.self, from: try JSONEncoder().encode(shuffled))
    try require(again.shuffleGraphics && again.shuffleMusic, "shuffle did not survive saving")
    try require(!again.favorApproachingLemmings, "favor-approaching did not survive saving")
    print("PASS settings written by an older build still load")
}

private func testRemovedSourcesDoNotDiscardSettings() throws {
    // A file written before DOS EGA artwork was removed names a case this
    // build does not have. The removed source falls back to the default and
    // every other choice survives.
    let stored = """
    {
      "graphics": { "dosEGA": {} },
      "musicVolume": 0.25,
      "soundVolume": 0.5,
      "integerScaling": false
    }
    """
    let settings = try JSONDecoder().decode(
        ClassicSettings.self, from: Data(stored.utf8))
    try require(
        settings.graphics == ClassicSettings().graphics,
        "A removed artwork source did not fall back to the default")
    try require(settings.musicVolume == 0.25, "Music volume was discarded")
    try require(settings.soundVolume == 0.5, "Sound volume was discarded")
    try require(settings.integerScaling == false, "Integer scaling was discarded")
    print("PASS a removed source falls back without discarding other settings")
}

private func testPointerCapturePreference() throws {
    let old = try JSONDecoder().decode(ClassicSettings.self, from: Data("{\"musicVolume\":0.25}".utf8))
    try require(old.confinePointer && old.musicVolume == 0.25, "Older settings must enable capture and retain other choices")
    var disabled = old
    disabled.confinePointer = false
    let restored = try JSONDecoder().decode(ClassicSettings.self, from: try JSONEncoder().encode(disabled))
    try require(!restored.confinePointer && restored.musicVolume == 0.25, "The pointer capture preference was not saved")
    print("PASS pointer capture defaults and saved opt-out")
}

private func testHDEffectsPreference() throws {
    let defaults = ClassicSettings()
    try require(defaults.pauseOnInterruption, "Interruptions should pause by default")
    var interruptionChoice = defaults; interruptionChoice.pauseOnInterruption = false
    let restoredInterruption = try JSONDecoder().decode(ClassicSettings.self, from: JSONEncoder().encode(interruptionChoice))
    try require(restoredInterruption == interruptionChoice,
                "Interruption preference did not survive persistence")
    try require(defaults.controllerEnabled && defaults.controllerTapSpeed && !defaults.controllerSwapSticks,
        "Controller QoL must default on")
    let oldControllerSettings = try JSONDecoder().decode(ClassicSettings.self, from: Data("{\"modernControlsEnabled\":false}".utf8))
    try require(!oldControllerSettings.pauseOnInterruption, "Migration re-enabled automatic pause for OG settings")
    try require(!oldControllerSettings.controllerEnabled, "Migration re-enabled a saved OG controller choice")
    let controllerChoice = ClassicSettings(controllerEnabled: true, controllerTapSpeed: false, controllerSwapSticks: true, controllerMappings: ["a": "b", "b": "a"])
    let restoredControllerChoice = try JSONDecoder().decode(ClassicSettings.self, from: JSONEncoder().encode(controllerChoice))
    try require(restoredControllerChoice == controllerChoice,
        "Controller settings did not round trip")
    try require(defaults.hdEffectsEnabled && defaults.fullScreenHDRFlashes, "New players must start with HD explosions and speed effects")
    let legacy = try JSONDecoder().decode(ClassicSettings.self, from: Data("{\"fullScreenHDRFlashes\":false,\"musicVolume\":0.25}".utf8))
    try require(legacy.hdEffectsEnabled && !legacy.fullScreenHDRFlashes && legacy.musicVolume == 0.25,
        "Migration must retain a saved explosion choice and unrelated settings")
    var oldSchool = defaults
    oldSchool.hdEffectsEnabled = false
    let saved = try JSONEncoder().encode(oldSchool)
    let restored = try JSONDecoder().decode(ClassicSettings.self, from: saved)
    try require(!restored.hdEffectsEnabled && restored.fullScreenHDRFlashes,
        "Old-school mode must persist without discarding the individual effect choices")
    print("PASS HD defaults, legacy preference migration and saved old-school mode")
    try require(defaults.modernControlsEnabled && defaults.variableSpeedEnabled,
      "Modern controls and variable speed must default on")
    var experience = ClassicSettings(graphics: .amiga, musicVolume: 0.25, soundVolume: 0.4)
    experience.applyExperiencePreset(modern: false)
    try require(!experience.pauseOnInterruption && !experience.modernControlsEnabled && !experience.variableSpeedEnabled && !experience.controllerEnabled && !experience.hdEffectsEnabled
      && !experience.confinePointer && !experience.fullScreenHDRFlashes && !experience.djIncludesOtherSoundtracks && !experience.favorApproachingLemmings,
      "OG did not disable the added conveniences together")
    try require(experience.graphics == .amiga && experience.musicVolume == 0.25 && experience.soundVolume == 0.4,
      "OG discarded the chosen machine or volumes")
    let savedExperience = try JSONDecoder().decode(ClassicSettings.self, from: JSONEncoder().encode(experience))
    try require(savedExperience == experience, "The OG preset did not survive relaunch")
    experience.applyExperiencePreset(modern: true)
    try require(experience.pauseOnInterruption && experience.modernControlsEnabled && experience.variableSpeedEnabled && experience.controllerEnabled && experience.hdEffectsEnabled
      && experience.confinePointer && experience.favorApproachingLemmings, "Modern defaults failed to restore the conveniences")
    print("PASS modern defaults, OG bundle, saved preference and preserved machine/volumes")
}

private func testReducedEffects() throws {
    let old = try JSONDecoder().decode(ClassicSettings.self, from: Data("{\"musicVolume\":0.25}".utf8))
    try require(!old.reduceMotion && !old.reduceFlashes && old.musicVolume == 0.25, "Older settings lost their values")
    for motion in [false, true] {
        for flashes in [false, true] {
            var value = ClassicSettings(reduceMotion: motion, reduceFlashes: flashes)
            try require(value.speedEffectsEnabled == !motion, "Motion control changed flash policy")
            try require(value.explosionEffectsEnabled == !flashes, "Flash control changed motion policy")
            try require(value.cinematicExplosionsEnabled == (!motion && !flashes), "Cinematic effects bypass reductions")
            try require(value.modernControlsEnabled && value.variableSpeedEnabled && value.controllerEnabled, "Effects disabled controls")
            let restored = try JSONDecoder().decode(ClassicSettings.self, from: JSONEncoder().encode(value))
            try require(restored == value, "Reduced effects did not survive relaunch")
            value.applyExperiencePreset(modern: false)
            value.applyExperiencePreset(modern: true)
            try require(value.reduceMotion == motion && value.reduceFlashes == flashes, "Experience preset erased accessibility choices")
        }
    }
    print("PASS independent reduced effects, migration, persistence and preserved controls")
}

do {
    for size in ClassicInterfaceSize.allCases {
        var settings = ClassicSettings()
        settings.interfaceSize = size
        settings.applyExperiencePreset(modern: false)
        settings.applyExperiencePreset(modern: true)
        try require(settings.interfaceSize == size, "Preset discarded interface size")
        let decoded = try JSONDecoder().decode(ClassicSettings.self, from: JSONEncoder().encode(settings))
        try require(decoded.interfaceSize == size, "Interface size did not persist")
    }
    for json in ["{}", "{\"interfaceSize\":\"future\"}"] {
        let decoded = try JSONDecoder().decode(ClassicSettings.self, from: Data(json.utf8))
        try require(decoded.interfaceSize == .standard, "Interface size migration failed")
    }
    print("PASS interface size persistence, migration and presets")
    try testReducedEffects()
    try testHDEffectsPreference()
    try testPointerCapturePreference()
    try testOptionsFollowInstalledData()
    try testUndecodedSourcesAreNotOffered()
    try testMixingAcrossMachines()
    try testStoredChoicesAreCorrected()
    try testPresetsMatchMachines()
    try testRemixesAndCustomArtwork()
    try testRoundTrip()
    try testOlderSettingsStillLoad()
    try testRemovedSourcesDoNotDiscardSettings()
    print("Classic settings tests passed.")
} catch {
    FileHandle.standardError.write(Data("Settings tests failed: \(error)\n".utf8))
    exit(1)
}
