import Foundation
import Testing
import NxlvKit
@testable import LemmingsMobileCore

struct MobileSettingsTests {
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
