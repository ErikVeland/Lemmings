import Foundation
import Testing
import NxlvKit
@testable import LemmingsMobileCore

struct MobileSettingsTests {
    @Test func ridiculousSpeedIsOptionalAndPersists() throws {
        #expect(!MobileSettings().classic.ridiculousSpeedEnabled)
        #expect(!MobileSettings().availableFastSpeeds.contains(25))
        var classic = ClassicSettings()
        classic.ridiculousSpeedEnabled = true
        let settings = MobileSettings(classic: classic, fastSpeed: 25)
        #expect(settings.availableFastSpeeds.last == 25 && settings.fastSpeed == 25)
        let restored = try JSONDecoder().decode(MobileSettings.self, from: JSONEncoder().encode(settings))
        #expect(restored.classic.ridiculousSpeedEnabled && restored.fastSpeed == 25)
        classic.ridiculousSpeedEnabled = false
        #expect(MobileSettings(classic: classic, fastSpeed: 25).fastSpeed == 2)
    }

    @Test func presentationPreservesTouchPlanningControllerAndSoundtrackChoices() throws {
        var settings = MobileSettings(pauseToAssign: false, fastSpeed: 5, musicEnabled: false,
                                      soundtrack: "Adaptive DJ")
        settings.classic.modernControlsEnabled = false
        settings.classic.variableSpeedEnabled = false
        settings.classic.controllerEnabled = false
        settings.classic.controllerTapSpeed = false
        settings.classic.controllerSwapSticks = true
        settings.classic.controllerMappings = ["a": "b", "b": "a"]
        settings.classic.pauseOnInterruption = false
        settings.classic.favorApproachingLemmings = false
        settings.classic.music = .adaptiveDJ
        settings.classic.graphics = .amiga
        settings.classic.musicVolume = 0.3
        settings.classic.soundVolume = 0.4
        let personal = PlayerControlSettings(settings.classic)
        for modern in [false, true] {
            settings.applyExperiencePreset(modern: modern)
            #expect(PlayerControlSettings(settings.classic) == personal)
            #expect(!settings.pauseToAssign && settings.fastSpeed == 5 && !settings.musicEnabled)
            #expect(!settings.classic.modernControlsEnabled && !settings.classic.variableSpeedEnabled)
            #expect(!settings.classic.pauseOnInterruption && !settings.classic.favorApproachingLemmings)
            #expect(settings.soundtrack == "Adaptive DJ" && settings.classic.music == .adaptiveDJ)
            #expect(settings.classic.graphics == .amiga && settings.classic.musicVolume == 0.3 && settings.classic.soundVolume == 0.4)
            #expect(!settings.classic.fullScreenHDRFlashes && !settings.classic.djIncludesOtherSoundtracks)
            #expect(settings.classic.gameplayCursorStyle == (modern ? .modern : .original))
            #expect(try JSONDecoder().decode(MobileSettings.self, from: JSONEncoder().encode(settings)) == settings)
        }
    }

    @Test func playerInputAndAccessibilityStaySeparateWhileDeviceSettingsRemainShared() {
        let store = defaults()
        var legacy = MobileSettings()
        legacy.classic.reduceFlashes = true
        legacy.save(to: store)
        var first = MobileSettings.load(from: store, profileID: "first")
        first.classic.controllerSwapSticks = true
        first.classic.interfaceSize = .extraLarge
        first.classic.reduceMotion = true
        first.classic.showSongInfo = false
        first.classic.musicVolume = 0.3
        first.djShuffleScope = .allTracks
        first.save(to: store, profileID: "first")
        let second = MobileSettings.load(from: store, profileID: "second")
        #expect(!second.classic.controllerSwapSticks && !second.classic.reduceMotion && second.classic.showSongInfo)
        #expect(second.classic.reduceFlashes && second.classic.musicVolume == 0.3)
        MobileSettings.activateProfile("first", in: store)
        #expect(MobileSettings.current(from: store) == first)
        MobileSettings.activateProfile("second", in: store)
        #expect(MobileSettings.current(from: store) == second)
        #expect(MobileSettings.load(from: store).classic.interfaceSize == legacy.classic.interfaceSize)
    }
    @Test func mutePreferenceDefaultsMigratesAndIsSharedAcrossProfiles() throws {
        #expect(MobileSettings().respectMuteSetting)
        #expect(try JSONDecoder().decode(MobileSettings.self, from: Data("{}".utf8)).respectMuteSetting)
        let store = defaults()
        var settings = MobileSettings.load(from: store, profileID: "first")
        settings.respectMuteSetting = false
        settings.save(to: store, profileID: "first")
        #expect(!MobileSettings.load(from: store, profileID: "second").respectMuteSetting)
        #expect(try JSONDecoder().decode(MobileSettings.self, from: JSONEncoder().encode(settings)) == settings)
    }

    private func defaults() -> UserDefaults { UserDefaults(suiteName: "MobileSettingsTests.\(UUID())")! }

    @Test func testTutorialCountsTenAutomaticPausesAcrossLaunches() {
        let store = defaults()
        var settings = MobileSettings.load(from: store)
        #expect(settings.pauseToAssign)
        for use in 1...10 {
            settings.recordSkillSelectionPause(wasRunning: true, isReadOnly: false)
            settings.save(to: store)
            settings = MobileSettings.load(from: store)
            #expect(settings.skillSelectionPauseCount == use)
            #expect(settings.shouldOfferSkillSelectionPauseChoice == (use == 10))
        }
        settings.recordSkillSelectionPause(wasRunning: true, isReadOnly: false)
        #expect(settings.skillSelectionPauseCount == 10)
    }

    @Test func testPlanningChangesAndReplaysDoNotSpendTutorialUses() {
        var settings = MobileSettings()
        for _ in 0..<20 {
            settings.recordSkillSelectionPause(wasRunning: false, isReadOnly: false)
            settings.recordSkillSelectionPause(wasRunning: true, isReadOnly: true)
        }
        #expect(settings.skillSelectionPauseCount == 0)
        #expect(!settings.shouldOfferSkillSelectionPauseChoice)
    }

    @Test func testBothChoicesPersistAndNeverRepeatAfterPresets() {
        for keep in [false, true] {
            let store = defaults()
            var settings = MobileSettings(skillSelectionPauseCount: 10)
            settings.chooseSkillSelectionPause(keep)
            settings.save(to: store)
            settings = MobileSettings.load(from: store)
            #expect(settings.pauseToAssign == keep)
            #expect(!settings.shouldOfferSkillSelectionPauseChoice)
            settings.applyExperiencePreset(modern: false)
            settings.applyExperiencePreset(modern: true)
            for _ in 0..<20 { settings.recordSkillSelectionPause(wasRunning: true, isReadOnly: false) }
            #expect(settings.pauseToAssign == keep)
            #expect(!settings.shouldOfferSkillSelectionPauseChoice)
        }
    }

    @Test func testManualPreferenceEndsReminderAndLegacyOffStaysOff() throws {
        var settings = MobileSettings()
        settings.chooseSkillSelectionPause(false)
        settings.chooseSkillSelectionPause(true)
        for _ in 0..<20 { settings.recordSkillSelectionPause(wasRunning: true, isReadOnly: false) }
        #expect(!settings.shouldOfferSkillSelectionPauseChoice)
        let restored = try JSONDecoder().decode(MobileSettings.self, from: Data("{\"pauseToAssign\":false}".utf8))
        #expect(!restored.pauseToAssign)
        #expect(restored.skillSelectionPauseChoiceMade)
        let olderDefault = try JSONDecoder().decode(MobileSettings.self, from: Data("{}".utf8))
        #expect(olderDefault.pauseToAssign && olderDefault.skillSelectionPauseCount == 0)
    }

    @Test func testLegacyKeysMigrate() {
        let store = defaults()
        store.set(true, forKey: "mobile.continuousSkillSelection")
        store.set(5, forKey: "mobile.fastSpeed")
        store.set(false, forKey: "mobile.music")
        store.set("Remix", forKey: "mobile.soundtrack")
        let migrated = MobileSettings.load(from: store)
        #expect(!migrated.pauseToAssign)
        #expect(migrated.fastSpeed == 5)
        #expect(!migrated.musicEnabled)
        #expect(migrated.soundtrack == "Remix")
        store.set(false, forKey: "mobile.continuousSkillSelection")
        store.set(10, forKey: "mobile.fastSpeed")
        store.set(true, forKey: "mobile.music")
        store.set("Original", forKey: "mobile.soundtrack")
        #expect(MobileSettings.load(from: store) == migrated)
    }

    @Test func testUnknownFastSpeedFallsBackToTwo() {
        let store = defaults()
        store.set(99, forKey: "mobile.fastSpeed")
        #expect(MobileSettings.load(from: store).fastSpeed == 2)
        store.set(Data("{\"fastSpeed\":99}".utf8), forKey: MobileSettings.defaultsKey)
        #expect(MobileSettings.load(from: store).fastSpeed == 2)
    }

    @Test func testSharedClassicPreferencesSurviveRoundTrip() throws {
        let store = defaults()
        var settings = MobileSettings()
        settings.classic.applyExperiencePreset(modern: false)
        settings.classic.favorBuilders = true
        settings.classic.experiencePreset = .custom
        settings.classic.controllerMappings = ControllerBindings.swapping([:], physical: .a, role: .y)
        settings.classic.reduceMotion = true
        settings.classic.musicVolume = 0.3
        settings.save(to: store)
        #expect(MobileSettings.load(from: store) == settings)
        #expect(try JSONDecoder().decode(ClassicSettings.self, from: JSONEncoder().encode(settings.classic)) == settings.classic)
    }

    @Test func testOlderMobileDocumentKeepsChoicesAndDefaultsNewFields() throws {
        let data = Data("{\"pauseToAssign\":false,\"fastSpeed\":3,\"classic\":{\"musicVolume\":0.4,\"experiencePreset\":\"original\"}}".utf8)
        let restored = try JSONDecoder().decode(MobileSettings.self, from: data)
        #expect(!restored.pauseToAssign)
        #expect(restored.fastSpeed == 3)
        #expect(restored.classic.musicVolume == 0.4)
        #expect(restored.classic.experiencePreset == .original)
        #expect(restored.musicEnabled)
    }
}
