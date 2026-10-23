import Foundation
import Testing
@testable import LemmingsMobileCore

@Suite struct DeskClockSettingsTests {
    @Test func defaultsAreOn() {
        let settings = DeskClockSettings()
        #expect(settings.openWhenStacked)
        #expect(settings.openWhenCharging)
        #expect(settings.showNextEvent)
        #expect(!settings.redNightVision)
        #expect(!settings.calendarRequested)
    }

    @Test func oldSettingsDecodeWithDefaults() throws {
        var original = MobileSettings(pauseToAssign: false, fastSpeed: 5, soundtrack: "Amiga")
        original.deskClock.openWhenCharging = false
        let data = try JSONEncoder().encode(original)
        var json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "deskClock")
        let old = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(MobileSettings.self, from: old)
        #expect(decoded.deskClock == DeskClockSettings())
        var expected = original
        expected.deskClock = DeskClockSettings()
        #expect(decoded == expected)
    }

    @Test func partialDeskClockDecodesWithDefaults() throws {
        let decoded = try JSONDecoder().decode(DeskClockSettings.self, from: Data(#"{"showNextEvent":false}"#.utf8))
        #expect(!decoded.showNextEvent)
        #expect(decoded.openWhenStacked)
        #expect(decoded.openWhenCharging)
        #expect(!decoded.calendarRequested)
        #expect(!decoded.redNightVision)
    }

    @Test func roundTrip() throws {
        var settings = MobileSettings()
        settings.deskClock.openWhenCharging = false
        settings.deskClock.redNightVision = true
        let decoded = try JSONDecoder().decode(MobileSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded == settings)
        #expect(!decoded.deskClock.openWhenCharging)
        #expect(decoded.deskClock.redNightVision)
    }
}

@Suite struct DeskClockEventsRowTests {
    @Test func deniedAccessOpensSettings() {
        #expect(DeskClockEventsRowAction(access: .denied) == .openSettings)
        #expect(DeskClockEventsRowAction(access: .granted) == .toggle)
        #expect(DeskClockEventsRowAction(access: .notDetermined) == .toggle)
    }
}
