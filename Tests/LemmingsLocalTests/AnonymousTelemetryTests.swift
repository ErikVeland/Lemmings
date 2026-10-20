#if os(macOS)
import AppKit
import Foundation
@testable import LemmingsAppCore
import NxlvKit
import LemmingsGameArt
import XCTest
@testable import LemmingsLocal

@MainActor private final class FakeTelemetryTransport: AnonymousTelemetryTransport {
    var requests: [URLRequest] = []
    var responseStatus = 204
    var responseData = Data()
    var failure: URLError?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        if let failure { throw failure }
        let response = HTTPURLResponse(url: request.url!, statusCode: responseStatus,
                                       httpVersion: "HTTP/1.1", headerFields: nil)!
        return (responseData, response)
    }
}

final class AnonymousTelemetryTests: XCTestCase {
    func testEventUsesFixedFieldsWithExplicitNulls() throws {
        let data = try JSONEncoder().encode(AnonymousTelemetryEvent(.activeDay))
        let values = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(values.keys), ["v", "event", "game", "level", "mode"])
        XCTAssertTrue(values["game"] is NSNull)
        XCTAssertTrue(values["level"] is NSNull)
        XCTAssertTrue(values["mode"] is NSNull)
        let saved = try JSONEncoder().encode(AnonymousTelemetryEvent(.lemmingsSaved,
            game: "fan", level: "all", mode: "solo", amount: 7))
        let savedFields = try XCTUnwrap(JSONSerialization.jsonObject(with: saved) as? [String: Any])
        XCTAssertEqual(Set(savedFields.keys), ["v", "event", "game", "level", "mode", "amount"])
        XCTAssertEqual(savedFields["amount"] as? Int, 7)
    }

    @MainActor func testLocalCountsDeduplicateResultsAndHidePrivateLevelDetails() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let telemetry = AnonymousTelemetry(defaults: defaults)
        let level = makeLevel(game: "fan", levelID: "private-level-path", packID: "private-pack")
        let attempt = UUID()
        telemetry.start(level, hotSeat: true, attemptID: attempt)
        telemetry.finish(level, hotSeat: true, attemptID: attempt, won: false, saved: 4)
        telemetry.finish(level, hotSeat: true, attemptID: attempt, won: false, saved: 4)
        let counts = telemetry.localSummary()
        XCTAssertEqual(counts.total(.levelStart), 1)
        XCTAssertEqual(counts.total(.levelFail), 1)
        XCTAssertEqual(counts.total(.levelStart, mode: "hot_seat"), 1)
        XCTAssertEqual(telemetry.localSavedTotal, 4)
        XCTAssertEqual(counts.counts.first { $0.event == "level_start" }?.level, "all")
        XCTAssertFalse(String(describing: counts).contains("private"))
        XCTAssertFalse(telemetry.sharesCounts)
        telemetry.clearLocalCounts()
        XCTAssertTrue(telemetry.localSummary().counts.isEmpty)
    }

    @MainActor func testAllSoundtrackChoiceCountsOncePerInstallation() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let telemetry = AnonymousTelemetry(defaults: defaults)
        telemetry.soundtrackAllSelected()
        telemetry.soundtrackAllSelected()
        telemetry.soundtrackAllDownloaded()
        telemetry.soundtrackAllDownloaded()
        let counts = telemetry.localSummary()
        XCTAssertEqual(counts.total(.allSoundtracksSelected), 1)
        XCTAssertEqual(counts.total(.allSoundtracksDownloaded), 1)
    }

    @MainActor func testLemmingsThreeTribesAndLemmingsTwoPracticeUseSafeBuckets() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let telemetry = AnonymousTelemetry(defaults: defaults)
        for raw in [1, 101, 201] {
            let level = makeLevel(game: "lemmings3", levelID: String(raw), packID: "private-pack")
            telemetry.start(level, hotSeat: false, attemptID: UUID())
        }
        let practice = makeLevel(game: "lemmings2", levelID: "practice-9", packID: "private-pack")
        telemetry.start(practice, hotSeat: false, attemptID: UUID())
        let keys = Set(telemetry.localSummary().counts.filter { $0.event == "level_start" }
            .compactMap(\.level))
        XCTAssertEqual(keys, ["level-1", "level-31", "level-61", "practice"])
    }

    @MainActor func testOnlyOfficialClassicLevelNumbersAreCounted() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let telemetry = AnonymousTelemetry(defaults: defaults)
        telemetry.start(makeLevel(game: "lemmings", levelID: "level-0", packID: "private-pack"),
                        hotSeat: false, attemptID: UUID())
        telemetry.start(makeLevel(game: "personal-title", levelID: "level-0", packID: "private-pack"),
                        hotSeat: false, attemptID: UUID())
        telemetry.start(makeLevel(game: "lemmings", levelID: "level-120", packID: "private-pack"),
                        hotSeat: false, attemptID: UUID())
        let starts = telemetry.localSummary().counts.filter { $0.event == "level_start" }
        XCTAssertEqual(starts.count, 1)
        XCTAssertEqual(starts.first?.game, "lemmings")
        XCTAssertEqual(starts.first?.level, "level-1")
    }

    @MainActor func testNoUploadBeforeConsentOrAfterOptOut() async throws {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let transport = FakeTelemetryTransport()
        let telemetry = AnonymousTelemetry(defaults: defaults,
            endpoint: URL(string: "https://counts.example.org")!, transport: transport)
        let level = makeLevel(game: "lemmings", levelID: "level-3", packID: "private-pack")
        let first = UUID()
        telemetry.start(level, hotSeat: false, attemptID: first)
        telemetry.finish(level, hotSeat: false, attemptID: first, won: false, saved: 0)
        await Task.yield()
        XCTAssertTrue(transport.requests.isEmpty)
        telemetry.setSharing(true)
        telemetry.start(level, hotSeat: false, attemptID: UUID())
        for _ in 0..<20 where transport.requests.count < 3 { await Task.yield() }
        XCTAssertEqual(transport.requests.count, 3)
        let bodies = try transport.requests.map { try XCTUnwrap($0.httpBody) }
        let messages = try bodies.map { try XCTUnwrap(JSONSerialization.jsonObject(with: $0) as? [String: Any]) }
        XCTAssertEqual(Set(messages.compactMap { $0["event"] as? String }), ["installation_opt_in", "active_day", "level_start"])
        XCTAssertFalse(String(describing: messages).contains("private-pack"))
        telemetry.setSharing(false)
        telemetry.start(level, hotSeat: false, attemptID: UUID())
        await Task.yield()
        XCTAssertEqual(transport.requests.count, 3)
    }

    @MainActor func testOptInCountsInstallationWithoutGameplayAndPersistsAcrossRelaunch() async throws {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let transport = FakeTelemetryTransport()
        let endpoint = URL(string: "https://counts.example.org")!
        let telemetry = AnonymousTelemetry(defaults: defaults, endpoint: endpoint, transport: transport)
        telemetry.setSharing(true)
        telemetry.recordActiveDay()
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(telemetry.localSummary().total(.installationOptIn), 1)
        XCTAssertEqual(telemetry.localSummary().total(.levelStart), 0)
        telemetry.setSharing(false)
        telemetry.setSharing(true)
        telemetry.clearLocalCounts()
        let relaunched = AnonymousTelemetry(defaults: defaults, endpoint: endpoint, transport: transport)
        relaunched.recordActiveDay()
        for _ in 0..<20 { await Task.yield() }
        let events = try transport.requests.map { request in
            try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        }
        XCTAssertEqual(events.filter { $0["event"] as? String == "installation_opt_in" }.count, 1)
        let registration = try XCTUnwrap(events.first { $0["event"] as? String == "installation_opt_in" })
        XCTAssertEqual(Set(registration.keys), ["v", "event", "game", "level", "mode"])
        XCTAssertTrue(registration["game"] is NSNull)
        XCTAssertTrue(registration["level"] is NSNull)
        XCTAssertTrue(registration["mode"] is NSNull)
    }

    @MainActor func testExistingOptInRegistersEvenIfActiveDayWasAlreadyCounted() async {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: AnonymousTelemetry.consentKey)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        defaults.set(formatter.string(from: Date()), forKey: "AnonymousTelemetryActiveDayV1")
        let transport = FakeTelemetryTransport()
        let telemetry = AnonymousTelemetry(defaults: defaults,
            endpoint: URL(string: "https://counts.example.org")!, transport: transport)
        telemetry.recordActiveDay()
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(telemetry.localSummary().total(.installationOptIn), 1)
        XCTAssertEqual(telemetry.localSummary().total(.activeDay), 0)
        XCTAssertEqual(transport.requests.count, 1)
    }

    @MainActor func testUnacknowledgedRegistrationRetriesAfterRelaunch() async {
        for offline in [false, true] {
            let suite = UUID().uuidString
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let transport = FakeTelemetryTransport()
            transport.responseStatus = 503
            transport.failure = offline ? URLError(.notConnectedToInternet) : nil
            let endpoint = URL(string: "https://counts.example.org")!
            let telemetry = AnonymousTelemetry(defaults: defaults, endpoint: endpoint, transport: transport)
            telemetry.setSharing(true)
            for _ in 0..<20 { await Task.yield() }
            telemetry.setSharing(false)
            transport.requests.removeAll()
            telemetry.recordActiveDay()
            for _ in 0..<20 { await Task.yield() }
            XCTAssertTrue(transport.requests.isEmpty)
            transport.responseStatus = 204
            transport.failure = nil
            defaults.set(true, forKey: AnonymousTelemetry.consentKey)
            let relaunched = AnonymousTelemetry(defaults: defaults, endpoint: endpoint, transport: transport)
            relaunched.recordActiveDay()
            relaunched.recordActiveDay()
            for _ in 0..<20 { await Task.yield() }
            XCTAssertEqual(transport.requests.count, 1)
            XCTAssertEqual(relaunched.localSummary().total(.installationOptIn), 1)
            relaunched.recordActiveDay()
            for _ in 0..<20 { await Task.yield() }
            XCTAssertEqual(transport.requests.count, 1)
        }
    }

    @MainActor func testPlainHTTPIsNeverEnabled() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let telemetry = AnonymousTelemetry(defaults: defaults,
            endpoint: URL(string: "http://counts.example.org"))
        telemetry.setSharing(true)
        XCTAssertNil(telemetry.endpoint)
        XCTAssertFalse(telemetry.sharesCounts)
    }

    @MainActor func testSavedCountAddsCompletedAttemptsIncludingClonesAndFormatsHomeLine() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let telemetry = AnonymousTelemetry(defaults: defaults)
        let level = makeLevel(game: "lemmings", levelID: "level-0", packID: "private-pack")
        let failed = UUID(), won = UUID()
        telemetry.finish(level, hotSeat: false, attemptID: failed, won: false, saved: 5)
        telemetry.finish(level, hotSeat: false, attemptID: failed, won: false, saved: 5)
        telemetry.finish(level, hotSeat: true, attemptID: won, won: true, saved: 4)
        telemetry.finish(level, hotSeat: false, attemptID: UUID(), won: true, saved: 12)
        XCTAssertEqual(telemetry.localSavedTotal, 21)
        XCTAssertEqual(telemetry.localSummary().total(.lemmingsSaved, mode: "hot_seat"), 4)
        XCTAssertEqual(SavedLemmingsCounter(local: telemetry.localSavedTotal, global: nil).text,
                       "LEMMINGS SAVED   LOCAL 21   GLOBAL —")
        XCTAssertEqual(SavedLemmingsCounter(local: 1_239, global: 34_567).text,
                       "LEMMINGS SAVED   LOCAL 1,239   GLOBAL 34,567")
    }

    @MainActor func testPublicSavedTotalRequiresConsentAndUsesNoOwnerToken() async throws {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let transport = FakeTelemetryTransport()
        transport.responseStatus = 200
        transport.responseData = Data("{\"saved\":12345}".utf8)
        let telemetry = AnonymousTelemetry(defaults: defaults,
            endpoint: URL(string: "https://counts.example.org")!, transport: transport)
        do {
            _ = try await telemetry.publicSavedTotal()
            XCTFail("A declined player must not contact the count service")
        } catch { XCTAssertTrue(transport.requests.isEmpty) }
        telemetry.setSharing(true)
        for _ in 0..<20 where transport.requests.count < 2 { await Task.yield() }
        transport.requests.removeAll()
        let total = try await telemetry.publicSavedTotal()
        XCTAssertEqual(total, 12_345)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.path, "/v1/saved")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertNil(request.httpBody)
        telemetry.setSharing(false)
        transport.requests.removeAll()
        do {
            _ = try await telemetry.publicSavedTotal()
            XCTFail("An opted-out player must not contact the count service")
        } catch { XCTAssertTrue(transport.requests.isEmpty) }
    }

    @MainActor func testSavedCountUploadsOneWeightedEvent() async throws {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let transport = FakeTelemetryTransport()
        let telemetry = AnonymousTelemetry(defaults: defaults,
            endpoint: URL(string: "https://counts.example.org")!, transport: transport)
        telemetry.setSharing(true)
        for _ in 0..<20 where transport.requests.count < 2 { await Task.yield() }
        transport.requests.removeAll()
        let level = makeLevel(game: "lemmings", levelID: "level-0", packID: "private-pack")
        let attempt = UUID()
        telemetry.finish(level, hotSeat: false, attemptID: attempt, won: true, saved: 7)
        telemetry.finish(level, hotSeat: false, attemptID: attempt, won: true, saved: 7)
        for _ in 0..<20 where transport.requests.count < 3 { await Task.yield() }
        XCTAssertEqual(transport.requests.count, 3)
        let saved = try XCTUnwrap(transport.requests.first { request in
            guard let body = request.httpBody,
                  let fields = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
            else { return false }
            return fields["event"] as? String == "lemmings_saved"
        })
        let body = try XCTUnwrap(saved.httpBody)
        let fields = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(fields["amount"] as? Int, 7)
        XCTAssertEqual(fields["game"] as? String, "lemmings")
        XCTAssertEqual(fields["level"] as? String, "level-1")
        XCTAssertFalse(String(describing: fields).contains("private-pack"))
    }

    @MainActor func testHomeSavedCountFitsAndLeavesMenuTargetsUsable() throws {
        _ = NSApplication.shared
        for size in [NSSize(width: 1120, height: 720), NSSize(width: 900, height: 620)] {
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                                  styleMask: [.titled], backing: .buffered, defer: false)
            let playfield = PlayfieldView(frame: NSRect(origin: .zero, size: size))
            window.contentView = playfield
            playfield.phase = .briefing
            playfield.overlayTitle = "LEMMINGS"
            playfield.overlayLines = ["ALL LEMMINGS", "CLASSIC", "OH NO", "HOLIDAY",
                                      "OH YES", "FAN", "LEMMINGS 2", "LEMMINGS 3"]
            playfield.overlayHighlight = 0
            playfield.overlaySavedCounts = size.width == 1120
                ? SavedLemmingsCounter(local: 1_239, global: 34_567).text
                : SavedLemmingsCounter(local: 0, global: nil).text
            playfield.overlayProfileInitials = "LEM"
            var selected = false, profiles = false
            playfield.onSelectOverlayLine = { _ in selected = true }
            playfield.onProfiles = { profiles = true }
            let bitmap = try XCTUnwrap(playfield.bitmapImageRepForCachingDisplay(in: playfield.bounds))
            playfield.displayIgnoringOpacity(playfield.bounds,
                in: NSGraphicsContext(bitmapImageRep: bitmap)!)
            let elements = playfield.accessibleControls(owner: playfield).compactMap { $0 as? GameAccessibleElement }
            let saved = try XCTUnwrap(elements.first { $0.accessibilityLabel()?.contains("LEMMINGS SAVED") == true })
            XCTAssertEqual(saved.accessibilityRole(), .staticText)
            XCTAssertTrue(playfield.bounds.contains(saved.localFrame))
            XCTAssertFalse(saved.accessibilityPerformPress())
            let first = try XCTUnwrap(elements.first { $0.accessibilityLabel() == "ALL LEMMINGS" })
            let profile = try XCTUnwrap(elements.first { $0.accessibilityLabel() == "Player profiles" })
            XCTAssertFalse(first.localFrame.intersects(saved.localFrame))
            XCTAssertFalse(profile.localFrame.intersects(saved.localFrame))
            XCTAssertTrue(first.accessibilityPerformPress())
            XCTAssertTrue(profile.accessibilityPerformPress())
            XCTAssertTrue(selected)
            XCTAssertTrue(profiles)
            if size.width == 1120,
               let path = ProcessInfo.processInfo.environment["LEMMINGS_TELEMETRY_HOME_SCREENSHOT"] {
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    .write(to: URL(fileURLWithPath: path))
            }
            if size.width == 900,
               let path = ProcessInfo.processInfo.environment["LEMMINGS_TELEMETRY_HOME_NARROW_SCREENSHOT"] {
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    .write(to: URL(fileURLWithPath: path))
            }
        }
    }

    func testHardestLevelsRankByFailsPerStart() {
        func rows(_ level: String, starts: Int, wins: Int, fails: Int) -> [AnonymousTelemetryCount] {
            [("level_start", starts), ("level_win", wins), ("level_fail", fails)].map {
                AnonymousTelemetryCount(day: nil, event: $0.0, game: "lemmings", level: level, mode: "solo", count: $0.1)
            }
        }
        let summary = AnonymousTelemetrySummary(days: 30, counts:
            rows("level-1", starts: 172, wins: 122, fails: 5)
            + rows("level-3", starts: 128, wins: 79, fails: 8)
            + rows("level-25", starts: 40, wins: 9, fails: 16)
            + rows("level-10", starts: 51, wins: 21, fails: 17)
            + rows("level-30", starts: 1, wins: 0, fails: 1))
        XCTAssertEqual(summary.hardestLevels.map(\.key), [
            "lemmings|level-25", "lemmings|level-10", "lemmings|level-3", "lemmings|level-1", "lemmings|level-30",
        ])
    }

    @MainActor func testOwnerSummaryUsesTokenAndDecodesCounts() async throws {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let transport = FakeTelemetryTransport()
        transport.responseStatus = 200
        transport.responseData = Data("""
            {"days":7,"counts":[{"day":null,"event":"level_fail","game":"lemmings",\
            "level":"level-54","mode":"solo","count":3}]}
            """.utf8)
        let telemetry = AnonymousTelemetry(defaults: defaults,
            endpoint: URL(string: "https://counts.example.org")!, transport: transport)
        let summary = try await telemetry.sharedSummary(token: "test-owner-token", days: 7)
        XCTAssertEqual(summary.total(.levelFail), 3)
        XCTAssertNil(summary.optedInInstalls)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.path, "/v1/dashboard")
        XCTAssertEqual(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?
            .queryItems?.first?.value, "7")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-owner-token")
        XCTAssertNil(request.httpBody)
        transport.responseData = Data("{\"days\":7,\"counts\":[],\"optedInInstalls\":42}".utf8)
        let currentSummary = try await telemetry.sharedSummary(token: "test-owner-token", days: 7)
        XCTAssertEqual(currentSummary.optedInInstalls, 42)
    }

    func testInsightsTargetsUseTelemetryNumbering() {
        XCTAssertEqual(TelemetryLevelTarget(key: "lemmings|level-52"), .classic(.lemmings, index: 51))
        XCTAssertEqual(TelemetryLevelTarget(key: "lemmings2|t12-l10"), .lemmings2(tribe: 11, index: 9))
        XCTAssertEqual(TelemetryLevelTarget(key: "lemmings3|level-30"), .lemmings3(tribe: 0, index: 29))
        XCTAssertEqual(TelemetryLevelTarget(key: "lemmings3|level-31"), .lemmings3(tribe: 1, index: 0))
        XCTAssertEqual(TelemetryLevelTarget(key: "lemmings3|level-90"), .lemmings3(tribe: 2, index: 29))
        for key in ["fan|all", "lemmings2|practice", "lemmings|level-0", "lemmings3|level-91",
                    "lemmings2|t13-l1", "lemmings2|t1-l11", "unknown|level-1", "lemmings|level-1|solo"] {
            XCTAssertNil(TelemetryLevelTarget(key: key), key)
        }
    }

    @MainActor func testInsightsLevelRowsLaunchAndRender() throws {
        _ = NSApplication.shared
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set([
            "level_start|lemmings|level-52|solo": 10,
            "level_start|lemmings2|t12-l10|hot_seat": 9,
            "level_start|lemmings3|level-31|solo": 8,
            "level_start|fan|all|solo": 7,
            "level_start|lemmings2|practice|solo": 6,
        ], forKey: "AnonymousTelemetryCountsV1")
        let dashboard = TelemetryDashboard(telemetry: AnonymousTelemetry(defaults: defaults))
        var launched: [TelemetryLevelTarget] = []
        dashboard.onStartLevel = { launched.append($0) }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 720),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 1120, height: 720))
        GameScreen.shared.gameWindow = window
        defer { GameScreen.shared.dismissAll(); GameScreen.shared.gameWindow = nil; window.close() }
        dashboard.show(owner: window)
        let page = try XCTUnwrap(GameScreen.shared.controllerPage(in: window) as? GameMenuPage)
        page.layoutSubtreeIfNeeded()
        let rows = page.body.subviews.compactMap { $0 as? NSButton }
        XCTAssertEqual(rows.count, 5)
        XCTAssertEqual(rows.filter(\.isEnabled).count, 3)
        for row in rows {
            let rect = row.convert(row.bounds, to: page)
            XCTAssertTrue(page.bounds.contains(rect))
            for fraction in [0.1, 0.7, 0.95] {
                let hit = page.hitTest(CGPoint(x: rect.minX + rect.width * fraction, y: rect.midY))
                XCTAssertTrue(hit === row || hit?.isDescendant(of: row) == true)
            }
            if row.isEnabled { row.performClick(nil) }
        }
        XCTAssertEqual(launched, [.classic(.lemmings, index: 51), .lemmings2(tribe: 11, index: 9),
                                 .lemmings3(tribe: 1, index: 0)])
        if let path = ProcessInfo.processInfo.environment["LEMMINGS_INSIGHTS_ROWS_SCREENSHOT"] {
            func capture(_ suffix: String) throws {
                let bitmap = try XCTUnwrap(page.bitmapImageRepForCachingDisplay(in: page.bounds))
                page.displayIgnoringOpacity(page.bounds, in: NSGraphicsContext(bitmapImageRep: bitmap)!)
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    .write(to: URL(fileURLWithPath: path + suffix + ".png"))
            }
            if let directory = ProcessInfo.processInfo.environment["LEMMINGS_TEST_MENU_ARTWORK"],
               let interface = ClassicMacUserInterface(artwork: try ClassicMacArtwork(directory: URL(fileURLWithPath: directory))) {
                try GameMenuArtwork.withRenderer(MacInterfaceRenderer(interface: interface)) {
                    try capture("")
                    let first = try XCTUnwrap(rows.first)
                    XCTAssertTrue(window.makeFirstResponder(first))
                    try capture("-focused")
                    first.highlight(true)
                    try capture("-pressed")
                    first.highlight(false)
                }
            } else { try capture("") }
        }
    }

    @MainActor func testDashboardRendersAndButtonsHaveTargets() throws {
        _ = NSApplication.shared
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let dashboard = TelemetryDashboard(telemetry: AnonymousTelemetry(defaults: defaults,
            endpoint: URL(string: "http://invalid.example")))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 720),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 1120, height: 720))
        GameScreen.shared.gameWindow = window
        defer { GameScreen.shared.dismissAll(); GameScreen.shared.gameWindow = nil }
        dashboard.show(owner: window)
        let page = try XCTUnwrap(GameScreen.shared.controllerPage(in: window) as? GameMenuPage)
        window.contentView?.layoutSubtreeIfNeeded()
        page.layoutSubtreeIfNeeded()
        func buttons(in view: NSView) -> [NSButton] {
            (view as? NSButton).map { [$0] } ?? view.subviews.flatMap(buttons)
        }
        let controls = buttons(in: page)
        XCTAssertTrue(controls.contains { $0.title == "Back" })
        XCTAssertFalse(controls.contains { $0.title == "Load shared" })
        XCTAssertTrue(page.body.subviews.compactMap { $0 as? GameLabel }
            .contains { $0.stringValue.contains("No level starts yet") })
        for control in controls {
            let rect = control.convert(control.bounds, to: page)
            XCTAssertTrue(page.bounds.contains(rect), "Clipped control: \(control.title)")
            let hit = page.hitTest(NSPoint(x: rect.midX, y: rect.midY))
            XCTAssertTrue(hit === control || hit?.isDescendant(of: control) == true,
                          "Missing input target: \(control.title)")
        }
        if let path = ProcessInfo.processInfo.environment["LEMMINGS_TELEMETRY_SCREENSHOT"] {
            let bitmap = try XCTUnwrap(page.bitmapImageRepForCachingDisplay(in: page.bounds))
            page.displayIgnoringOpacity(page.bounds, in: NSGraphicsContext(bitmapImageRep: bitmap)!)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                .write(to: URL(fileURLWithPath: path))
        }
    }

    @MainActor func testSharedDashboardShowsLifetimeInstallsAndDailyActivity() async throws {
        _ = NSApplication.shared
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let transport = FakeTelemetryTransport()
        transport.responseStatus = 200
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        transport.responseData = Data("""
            {"days":30,"optedInInstalls":12345,"counts":[
            {"day":"\(formatter.string(from: Date()))","event":"active_day","game":null,"level":null,"mode":null,"count":23}]}
            """.utf8)
        let dashboard = TelemetryDashboard(telemetry: AnonymousTelemetry(defaults: defaults,
            endpoint: URL(string: "https://counts.example.org")!, transport: transport))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 720),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 1120, height: 720))
        GameScreen.shared.gameWindow = window
        defer { GameScreen.shared.dismissAll(); GameScreen.shared.gameWindow = nil; window.close() }
        dashboard.show(owner: window)
        let page = try XCTUnwrap(GameScreen.shared.controllerPage(in: window) as? GameMenuPage)
        func views(in root: NSView) -> [NSView] { [root] + root.subviews.flatMap(views) }
        dashboard.loadShared(token: "test-owner-token")
        for _ in 0..<20 {
            if views(in: page).compactMap({ $0 as? GameLabel }).contains(where: { $0.stringValue == "12345" }) { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        page.layoutSubtreeIfNeeded()
        let labels = views(in: page).compactMap { $0 as? GameLabel }
        XCTAssertTrue(labels.contains { $0.stringValue == "OPTED-IN INSTALLS" })
        XCTAssertTrue(labels.contains { $0.stringValue == "12345" })
        XCTAssertTrue(labels.contains { $0.stringValue.contains("ACTIVE TODAY  23") })
        for control in views(in: page).compactMap({ $0 as? NSButton }) where control.isEnabled {
            let rect = control.convert(control.bounds, to: page)
            XCTAssertTrue(page.bounds.contains(rect))
            let hit = page.hitTest(NSPoint(x: rect.midX, y: rect.midY))
            XCTAssertTrue(hit === control || hit?.isDescendant(of: control) == true)
        }
        if let path = ProcessInfo.processInfo.environment["LEMMINGS_TELEMETRY_SHARED_SCREENSHOT"] {
            func capture() throws {
                let bitmap = try XCTUnwrap(page.bitmapImageRepForCachingDisplay(in: page.bounds))
                page.displayIgnoringOpacity(page.bounds, in: NSGraphicsContext(bitmapImageRep: bitmap)!)
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    .write(to: URL(fileURLWithPath: path))
            }
            if let directory = ProcessInfo.processInfo.environment["LEMMINGS_TEST_MENU_ARTWORK"],
               let interface = ClassicMacUserInterface(artwork: try ClassicMacArtwork(directory: URL(fileURLWithPath: directory))) {
                try GameMenuArtwork.withRenderer(MacInterfaceRenderer(interface: interface), capture)
            } else { try capture() }
        }
    }

    @MainActor func testMobileDashboardShowsLifetimeCountAndUnavailableStates() throws {
        let states: [(String, Bool, [String: Int], String)] = [
            ("shared", true, ["installs": 12345, "starts": 120], "12345"),
            ("local", false, ["installs": 12345], "N/A"),
            ("older-service", true, [:], "N/A"),
        ]
        for (state, shared, counts, value) in states {
            let page = MobileInformationArt.insights(counts: counts, shared: shared, days: 7, sharingAvailable: true)
            XCTAssertEqual(page.rows.first?.title, "Opted-in installs (all-time): " + value)
            XCTAssertFalse(try XCTUnwrap(page.rows.first).enabled)
            for (device, size) in [("phone", CGSize(width: 390, height: 844)),
                                   ("tablet", CGSize(width: 1024, height: 768)),
                                   ("tv", CGSize(width: 1920, height: 1080))] {
                let layout = GameFrontEnd.layout(page, width: size.width, minimumHeight: size.height)
                for target in layout.targets {
                    XCTAssertTrue(CGRect(origin: .zero, size: layout.size).contains(target.frame))
                    XCTAssertEqual(layout.action(at: CGPoint(x: target.frame.midX, y: target.frame.midY)),
                                   target.action.enabled ? target.action.id : nil)
                }
                if let directory = ProcessInfo.processInfo.environment["LEMMINGS_TEST_MENU_ARTWORK"],
                   let output = ProcessInfo.processInfo.environment["LEMMINGS_TELEMETRY_MOBILE_CAPTURES"] {
                    let typography = try XCTUnwrap(GameMenuTypography(directory: URL(fileURLWithPath: directory)))
                    let context = try XCTUnwrap(CGContext(data: nil, width: Int(layout.size.width), height: Int(layout.size.height),
                        bitsPerComponent: 8, bytesPerRow: Int(layout.size.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                    context.translateBy(x: 0, y: layout.size.height); context.scaleBy(x: 1, y: -1)
                    GameFrontEnd.draw(page, layout: layout, typography: typography, in: context)
                    let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(context.makeImage()))
                    try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                        .write(to: URL(fileURLWithPath: output).appendingPathComponent("\(device)-\(state).png"))
                }
            }
        }
    }

    @MainActor func testConfiguredDashboardShowsSharedControls() throws {
        _ = NSApplication.shared
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let telemetry = AnonymousTelemetry(defaults: defaults,
            endpoint: URL(string: "https://counts.example.org")!, transport: FakeTelemetryTransport())
        let dashboard = TelemetryDashboard(telemetry: telemetry)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 720),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 1120, height: 720))
        GameScreen.shared.gameWindow = window
        defer { GameScreen.shared.dismissAll(); GameScreen.shared.gameWindow = nil }
        dashboard.show(owner: window)
        let page = try XCTUnwrap(GameScreen.shared.controllerPage(in: window) as? GameMenuPage)
        window.contentView?.layoutSubtreeIfNeeded()
        page.layoutSubtreeIfNeeded()
        func buttons(in view: NSView) -> [NSButton] {
            (view as? NSButton).map { [$0] } ?? view.subviews.flatMap(buttons)
        }
        let controls = buttons(in: page)
        XCTAssertTrue(controls.contains { $0.title == "Load shared" && $0.isEnabled })
        XCTAssertTrue(controls.contains { $0.title == "This Mac" })
        XCTAssertTrue(controls.contains { $0.title == "Last 30 days" && !$0.isEnabled })
        for control in controls {
            let rect = control.convert(control.bounds, to: page)
            XCTAssertTrue(page.bounds.contains(rect), "Clipped control: \(control.title)")
            let hit = page.hitTest(NSPoint(x: rect.midX, y: rect.midY))
            XCTAssertTrue(hit === control || hit?.isDescendant(of: control) == true,
                          "Missing input target: \(control.title)")
        }
        if let path = ProcessInfo.processInfo.environment["LEMMINGS_TELEMETRY_SHARED_SCREENSHOT"] {
            let bitmap = try XCTUnwrap(page.bitmapImageRepForCachingDisplay(in: page.bounds))
            page.displayIgnoringOpacity(page.bounds, in: NSGraphicsContext(bitmapImageRep: bitmap)!)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                .write(to: URL(fileURLWithPath: path))
        }
    }

    @MainActor func testConsentDefaultsToDeclineAndRendersBothChoices() throws {
        _ = NSApplication.shared
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let transport = FakeTelemetryTransport()
        let telemetry = AnonymousTelemetry(defaults: defaults,
            endpoint: URL(string: "https://counts.example.org")!, transport: transport)
        let consent = TelemetryConsentWindow(telemetry: telemetry)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 720),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 1120, height: 720))
        GameScreen.shared.gameWindow = window
        defer { GameScreen.shared.dismissAll(); GameScreen.shared.gameWindow = nil }
        var continued = false
        consent.showIfNeeded(in: window) { continued = true }
        let page = try XCTUnwrap(GameScreen.shared.controllerPage(in: window) as? GameMenuPage)
        window.contentView?.layoutSubtreeIfNeeded()
        page.layoutSubtreeIfNeeded()
        XCTAssertEqual(page.controllerBackButton.title, "Not now")
        XCTAssertTrue(page.controllerInitialControl === page.controllerBackButton)
        func buttons(in view: NSView) -> [NSButton] {
            (view as? NSButton).map { [$0] } ?? view.subviews.flatMap(buttons)
        }
        let share = try XCTUnwrap(buttons(in: page).first { $0.title == "Share counts" })
        for control in [page.controllerBackButton, share] {
            let rect = control.convert(control.bounds, to: page)
            XCTAssertTrue(page.bounds.contains(rect))
            let hit = page.hitTest(NSPoint(x: rect.midX, y: rect.midY))
            XCTAssertTrue(hit === control || hit?.isDescendant(of: control) == true)
        }
        if let path = ProcessInfo.processInfo.environment["LEMMINGS_TELEMETRY_CONSENT_SCREENSHOT"] {
            let bitmap = try XCTUnwrap(page.bitmapImageRepForCachingDisplay(in: page.bounds))
            page.displayIgnoringOpacity(page.bounds, in: NSGraphicsContext(bitmapImageRep: bitmap)!)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                .write(to: URL(fileURLWithPath: path))
        }
        page.onBack?()
        XCTAssertTrue(continued)
        XCTAssertTrue(telemetry.consentDecided)
        XCTAssertFalse(telemetry.sharesCounts)
        XCTAssertTrue(transport.requests.isEmpty)
    }

    @MainActor func testPrivacySettingsRendersAndButtonsHaveTargets() throws {
        _ = NSApplication.shared
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let telemetry = AnonymousTelemetry(defaults: defaults,
            endpoint: URL(string: "https://counts.example.org")!, transport: FakeTelemetryTransport())
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 720),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 1120, height: 720))
        GameScreen.shared.gameWindow = window
        defer { GameScreen.shared.dismissAll(); GameScreen.shared.gameWindow = nil }
        let settings = SettingsWindow(settings: ClassicSettings(), options:
            ClassicSettingsOptions(graphics: [.macintosh], music: ClassicSettingsOptions.playableMusic,
                                   sound: ClassicSettingsOptions.playableSound), telemetry: telemetry)
        settings.show()
        let page = try XCTUnwrap(GameScreen.shared.controllerPage(in: window) as? GameMenuPage)
        let tabs = try XCTUnwrap(page.body.subviews.first { $0 is GameTabs } as? GameTabs)
        let privacy = try XCTUnwrap(tabs.subviews.compactMap { $0 as? NSButton }
            .first { $0.title == "Privacy" })
        privacy.performClick(nil)
        window.contentView?.layoutSubtreeIfNeeded()
        page.layoutSubtreeIfNeeded()
        func buttons(in view: NSView) -> [NSButton] {
            (view as? NSButton).map { [$0] } ?? view.subviews.flatMap(buttons)
        }
        let controls = buttons(in: page)
        for title in ["Share play counts", "View play insights", "Clear this Mac's counts"] {
            let control = try XCTUnwrap(controls.first { $0.title == title })
            let rect = control.convert(control.bounds, to: page)
            XCTAssertTrue(page.bounds.contains(rect), "Clipped control: \(title)")
            let hit = page.hitTest(NSPoint(x: rect.midX, y: rect.midY))
            XCTAssertTrue(hit === control || hit?.isDescendant(of: control) == true,
                          "Missing input target: \(title)")
        }
        let sharing = try XCTUnwrap(controls.first { $0.title == "Share play counts" })
        XCTAssertTrue(sharing.isEnabled)
        if let path = ProcessInfo.processInfo.environment["LEMMINGS_TELEMETRY_SETTINGS_SCREENSHOT"] {
            let bitmap = try XCTUnwrap(page.bitmapImageRepForCachingDisplay(in: page.bounds))
            page.displayIgnoringOpacity(page.bounds, in: NSGraphicsContext(bitmapImageRep: bitmap)!)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                .write(to: URL(fileURLWithPath: path))
        }
        sharing.performClick(nil)
        XCTAssertTrue(telemetry.sharesCounts)
        sharing.performClick(nil)
        XCTAssertFalse(telemetry.sharesCounts)
    }

    private func makeLevel(game: String, levelID: String, packID: String) -> ArcadeLevel {
        let conditions = TrolleyConditions(gameID: game, packID: packID, levelID: levelID,
            levelFingerprint: "test", rulesetVersion: "test", physicsMode: "test",
            population: 10, rescueRequirement: 1, startingSkills: [:], timeLimitSeconds: nil)
        return ArcadeLevel(id: "test", title: "Private title", game: "Private game",
                           rules: "test", total: 10, required: 1, conditions: conditions)
    }
}
#endif
