import Foundation
import Testing
@testable import NxlvKit

struct PlayerControlSettingsTests {
    @Test func pausedInspectionDefaultsAndRetainsPlayerChoice() throws {
        #expect(ClassicSettings().inspectWhilePaused)
        #expect(try JSONDecoder().decode(ClassicSettings.self, from: Data("{}".utf8)).inspectWhilePaused)
        var settings = ClassicSettings()
        settings.inspectWhilePaused = false
        settings.applyExperiencePreset(modern: false)
        settings.applyExperiencePreset(modern: true)
        #expect(!settings.inspectWhilePaused)
        let stored = try JSONEncoder().encode(settings)
        #expect(try !JSONDecoder().decode(ClassicSettings.self, from: stored).inspectWhilePaused)
        let controls = PlayerControlSettings(settings)
        let data = try JSONEncoder().encode(controls)
        #expect(try !JSONDecoder().decode(PlayerControlSettings.self, from: data).applying(to: .init()).inspectWhilePaused)
        var legacy = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        legacy.removeValue(forKey: "inspectWhilePaused")
        #expect(try JSONDecoder().decode(PlayerControlSettings.self,
            from: JSONSerialization.data(withJSONObject: legacy)).inspectWhilePaused)
    }

    @Test func macShuffleScopeDefaultsAndSurvivesSavedSettingsAndPresets() throws {
        var value = try JSONDecoder().decode(ClassicSettings.self, from: Data("{}".utf8))
        #expect(value.djShuffleScope == .sameTrack)
        value.djShuffleScope = .allTracks
        value.applyExperiencePreset(modern: false)
        value.applyExperiencePreset(modern: true)
        #expect(try JSONDecoder().decode(ClassicSettings.self, from: JSONEncoder().encode(value)).djShuffleScope == .allTracks)
    }
    @Test func profileChoicesOverlayOnlyInputAndAccessibility() {
        var personal = ClassicSettings()
        personal.controllerEnabled = false
        personal.controllerTapSpeed = false
        personal.controllerSwapSticks = true
        personal.controllerMappings = ControllerBindings.swapping([:], physical: .a, role: .y)
        personal.interfaceSize = .extraLarge
        personal.reduceMotion = true
        personal.reduceFlashes = true
        personal.showSongInfo = false
        personal.fadeMenuButton = false
        var device = ClassicSettings()
        device.musicVolume = 0.3
        device.graphics = .amiga
        let applied = PlayerControlSettings(personal).applying(to: device)
        #expect(PlayerControlSettings(applied) == PlayerControlSettings(personal))
        #expect(applied.musicVolume == 0.3 && applied.graphics == .amiga)
    }

    @Test func profilesRetainIndependentChoicesAndLegacyDefaults() {
        let suite = "PlayerControls.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let legacy = ClassicSettings(reduceFlashes: true)
        var first = PlayerControlSettings.load(from: defaults, profileID: "first", legacy: legacy)
        first.controllerSwapSticks = true
        first.save(to: defaults, profileID: "first")
        let second = PlayerControlSettings.load(from: defaults, profileID: "second", legacy: legacy)
        #expect(second.reduceFlashes && !second.controllerSwapSticks)
        #expect(PlayerControlSettings.load(from: defaults, profileID: "first", legacy: .init()) == first)
        #expect(PlayerControlSettings.defaultsKey(profileID: "a.b") != PlayerControlSettings.defaultsKey(profileID: "a"))
    }
}
