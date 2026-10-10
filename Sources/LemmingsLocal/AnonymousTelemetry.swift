import Foundation
import NxlvKit

@MainActor protocol AnonymousTelemetryTransport {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

@MainActor private final class URLSessionAnonymousTelemetryTransport: AnonymousTelemetryTransport {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        config.urlCache = nil
        session = URLSession(configuration: config)
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

/**
 * A fixed, identifier-free event sent only after the player agrees to share counts.
 */
struct AnonymousTelemetryEvent: Encodable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case activeDay = "active_day"
        case levelStart = "level_start"
        case levelWin = "level_win"
        case levelFail = "level_fail"
        case levelAbandon = "level_abandon"
        case lemmingsSaved = "lemmings_saved"
        case allSoundtracksSelected = "all_soundtracks_selected"
        case allSoundtracksDownloaded = "all_soundtracks_downloaded"
    }

    let v = 1
    let event: Kind
    let game: String?
    let level: String?
    let mode: String?
    let amount: Int?

    init(_ event: Kind, game: String? = nil, level: String? = nil,
         mode: String? = nil, amount: Int? = nil) {
        self.event = event
        self.game = game
        self.level = level
        self.mode = mode
        self.amount = amount
    }

    private enum CodingKeys: String, CodingKey { case v, event, game, level, mode, amount }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(v, forKey: .v)
        try values.encode(event, forKey: .event)
        try values.encode(game, forKey: .game)
        try values.encode(level, forKey: .level)
        try values.encode(mode, forKey: .mode)
        if let amount { try values.encode(amount, forKey: .amount) }
    }
}

struct AnonymousTelemetryCount: Codable, Sendable {
    let day: String?
    let event: String
    let game: String?
    let level: String?
    let mode: String?
    let count: Int
}

struct AnonymousTelemetrySummary: Codable, Sendable {
    let days: Int
    let counts: [AnonymousTelemetryCount]

    func total(_ event: AnonymousTelemetryEvent.Kind, mode: String? = nil) -> Int {
        counts.filter { $0.event == event.rawValue && (mode == nil || $0.mode == mode) }
            .reduce(0) { $0 + $1.count }
    }
}

@MainActor struct SavedLemmingsCounter {
    let local: Int
    let global: Int?

    var text: String {
        "LEMMINGS SAVED   LOCAL \(Self.grouped(local))   GLOBAL \(global.map(Self.grouped) ?? "—")"
    }

    private static func grouped(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_AU")
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count)) ?? String(count)
    }
}

/**
 * Keeps local aggregate counts. The optional network copy has no player, device,
 * profile, run, replay, timestamp, pack name or free-form level title.
 */
@MainActor final class AnonymousTelemetry {
    static let shared = AnonymousTelemetry()
    static let consentKey = "AnonymousTelemetryConsentV1"
    static let decidedKey = "AnonymousTelemetryDecisionV1"
    private static let countsKey = "AnonymousTelemetryCountsV1"
    private static let activeDayKey = "AnonymousTelemetryActiveDayV1"
    private static let soundtrackSelectedKey = "AnonymousTelemetryAllSoundtracksSelectedV1"
    private static let soundtrackDownloadedKey = "AnonymousTelemetryAllSoundtracksDownloadedV1"

    private struct Level: Equatable {
        let game: String
        let level: String
        let mode: String
    }

    private struct Attempt {
        let id: UUID
        let level: Level
    }

    private let defaults: UserDefaults
    private let transport: any AnonymousTelemetryTransport
    let endpoint: URL?
    private var active: Attempt?
    private var finishedAttempts = Set<UUID>()
    private var uploads: [UUID: Task<Void, Never>] = [:]
    var onCountsChanged: (() -> Void)?

    init(defaults: UserDefaults = .standard, endpoint: URL? = nil,
         transport: (any AnonymousTelemetryTransport)? = nil) {
        self.defaults = defaults
        let supplied = endpoint ?? (Bundle.main.object(forInfoDictionaryKey: "AnonymousTelemetryURL") as? String)
            .flatMap(URL.init(string:))
        self.endpoint = supplied.flatMap { url in
            guard url.scheme == "https", url.host != nil, url.user == nil, url.password == nil,
                  url.query == nil, url.fragment == nil else { return nil }
            return url
        }
        self.transport = transport ?? URLSessionAnonymousTelemetryTransport()
    }

    var consentDecided: Bool { defaults.bool(forKey: Self.decidedKey) }
    var sharesCounts: Bool { endpoint != nil && defaults.bool(forKey: Self.consentKey) }

    func setSharing(_ enabled: Bool) {
        let wasSharing = sharesCounts
        defaults.set(true, forKey: Self.decidedKey)
        defaults.set(enabled && endpoint != nil, forKey: Self.consentKey)
        if !enabled {
            uploads.values.forEach { $0.cancel() }
            uploads.removeAll()
        }
        if enabled { recordActiveDay() }
        if sharesCounts != wasSharing { onCountsChanged?() }
    }

    func clearLocalCounts() {
        defaults.removeObject(forKey: Self.countsKey)
        onCountsChanged?()
    }

    func recordActiveDay() {
        guard sharesCounts else { return }
        let day = Self.utcDay()
        guard defaults.string(forKey: Self.activeDayKey) != day else { return }
        defaults.set(day, forKey: Self.activeDayKey)
        record(.init(.activeDay))
    }

    func start(_ level: ArcadeLevel, hotSeat: Bool, attemptID: UUID) {
        guard let next = Self.safeLevel(level, hotSeat: hotSeat) else { return }
        guard active?.id != attemptID else { return }
        if let active {
            record(.init(.levelAbandon, game: active.level.game,
                         level: active.level.level, mode: active.level.mode))
        }
        active = .init(id: attemptID, level: next)
        recordActiveDay()
        record(.init(.levelStart, game: next.game, level: next.level, mode: next.mode))
    }

    func finish(_ level: ArcadeLevel, hotSeat: Bool, attemptID: UUID, won: Bool, saved: Int) {
        guard let current = Self.safeLevel(level, hotSeat: hotSeat) else { return }
        guard finishedAttempts.insert(attemptID).inserted else { return }
        if active?.id != attemptID {
            if let active {
                record(.init(.levelAbandon, game: active.level.game,
                             level: active.level.level, mode: active.level.mode))
            }
            record(.init(.levelStart, game: current.game, level: current.level, mode: current.mode))
        }
        active = nil
        record(.init(won ? .levelWin : .levelFail,
                     game: current.game, level: current.level, mode: current.mode))
        if saved > 0 && saved <= 1_000_000 {
            record(.init(.lemmingsSaved, game: current.game, level: current.level,
                         mode: current.mode, amount: saved))
            onCountsChanged?()
        }
    }

    func soundtrackAllSelected() {
        guard !defaults.bool(forKey: Self.soundtrackSelectedKey) else { return }
        defaults.set(true, forKey: Self.soundtrackSelectedKey)
        record(.init(.allSoundtracksSelected))
    }

    func soundtrackAllDownloaded() {
        guard !defaults.bool(forKey: Self.soundtrackDownloadedKey) else { return }
        defaults.set(true, forKey: Self.soundtrackDownloadedKey)
        record(.init(.allSoundtracksDownloaded))
    }

    func localSummary() -> AnonymousTelemetrySummary {
        let counts = defaults.dictionary(forKey: Self.countsKey) as? [String: Int] ?? [:]
        let rows = counts.compactMap { key, count -> AnonymousTelemetryCount? in
            let parts = key.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 4, count > 0 else { return nil }
            return .init(day: nil, event: parts[0], game: parts[1].isEmpty ? nil : parts[1],
                         level: parts[2].isEmpty ? nil : parts[2],
                         mode: parts[3].isEmpty ? nil : parts[3], count: count)
        }
        return .init(days: 0, counts: rows)
    }

    var localSavedTotal: Int { localSummary().total(.lemmingsSaved) }

    func publicSavedTotal() async throws -> Int {
        guard sharesCounts, let endpoint else { throw URLError(.userAuthenticationRequired) }
        let request = URLRequest(url: endpoint.appendingPathComponent("v1/saved"),
                                 cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        let (data, response) = try await transport.data(for: request)
        guard sharesCounts, let http = response as? HTTPURLResponse,
              http.statusCode == 200, data.count <= 64 else { throw URLError(.badServerResponse) }
        let total = try JSONDecoder().decode(PublicSavedTotal.self, from: data).saved
        guard total >= 0 else { throw URLError(.badServerResponse) }
        return total
    }

    private struct PublicSavedTotal: Decodable { let saved: Int }

    func sharedSummary(token: String, days: Int = 30) async throws -> AnonymousTelemetrySummary {
        guard let endpoint, [7, 30].contains(days), !token.isEmpty else {
            throw URLError(.badURL)
        }
        var url = URLComponents(url: endpoint.appendingPathComponent("v1/dashboard"), resolvingAgainstBaseURL: false)!
        url.queryItems = [URLQueryItem(name: "days", value: String(days))]
        var request = URLRequest(url: url.url!)
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await transport.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              data.count <= 2_000_000 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(AnonymousTelemetrySummary.self, from: data)
    }

    private func record(_ event: AnonymousTelemetryEvent) {
        let key = [event.event.rawValue, event.game ?? "", event.level ?? "", event.mode ?? ""].joined(separator: "|")
        var counts = defaults.dictionary(forKey: Self.countsKey) as? [String: Int] ?? [:]
        let increment = event.amount ?? 1
        let (updated, overflow) = counts[key, default: 0].addingReportingOverflow(increment)
        counts[key] = overflow ? Int.max : updated
        defaults.set(counts, forKey: Self.countsKey)
        guard sharesCounts, let endpoint,
              let body = try? JSONEncoder().encode(event) else { return }
        var request = URLRequest(url: endpoint.appendingPathComponent("v1/event"))
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("UltimateLemmingsCounts/1", forHTTPHeaderField: "User-Agent")
        let id = UUID()
        uploads[id] = Task { [weak self, transport] in
            guard let self else { return }
            defer { self.uploads[id] = nil }
            guard !Task.isCancelled, self.sharesCounts else { return }
            _ = try? await transport.data(for: request)
        }
    }

    private static func safeLevel(_ level: ArcadeLevel, hotSeat: Bool) -> Level? {
        guard let source = level.conditions else { return nil }
        let mode = hotSeat ? "hot_seat" : "solo"
        let game = source.gameID
        if game == "fan" { return .init(game: "fan", level: "all", mode: mode) }
        if game == "lemmings2" {
            if source.levelID.hasPrefix("practice-") {
                return .init(game: game, level: "practice", mode: mode)
            }
            let parts = source.levelID.split(separator: ":")
            guard parts.count == 2, let tribe = Int(parts[0]), let number = Int(parts[1]),
                  (0..<12).contains(tribe), (0..<10).contains(number) else { return nil }
            return .init(game: game, level: "t\(tribe + 1)-l\(number + 1)", mode: mode)
        }
        if game == "lemmings3" {
            guard let number = Int(source.levelID) else { return nil }
            let tribe = (number - 1) / 100, index = (number - 1) % 100
            guard (0..<3).contains(tribe), (0..<30).contains(index) else { return nil }
            return .init(game: game, level: "level-\(tribe * 30 + index + 1)", mode: mode)
        }
        guard let title = ClassicTitle(rawValue: game), title != .lemmings2TheTribes,
              title != .lemmings3TheChronicles,
              source.levelID.hasPrefix("level-"),
              let index = Int(source.levelID.dropFirst(6)),
              let maximum = title.expectedLevelCount, (0..<maximum).contains(index) else { return nil }
        return .init(game: game, level: "level-\(index + 1)", mode: mode)
    }

    private static func utcDay() -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = calendar.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
