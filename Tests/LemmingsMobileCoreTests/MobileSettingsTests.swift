import Foundation
import Testing
import NxlvKit
@testable import LemmingsMobileCore

struct MobileSettingsTests {
    private func defaults() -> UserDefaults { UserDefaults(suiteName: "MobileSettingsTests.\(UUID())")! }

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
