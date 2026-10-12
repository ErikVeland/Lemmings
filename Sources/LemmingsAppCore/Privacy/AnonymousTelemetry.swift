import Foundation
import NxlvKit

@MainActor public protocol AnonymousTelemetryTransport {
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
public struct AnonymousTelemetryEvent: Encodable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case activeDay = "active_day"
        case levelStart = "level_start"
        case levelWin = "level_win"
        case levelFail = "level_fail"
        case levelAbandon = "level_abandon"
        case lemmingsSaved = "lemmings_saved"
        case allSoundtracksSelected = "all_soundtracks_selected"
        case allSoundtracksDownloaded = "all_soundtracks_downloaded"
    }

    public let v = 1
    public let event: Kind
    public let game: String?
    public let level: String?
    public let mode: String?
    public let amount: Int?

    public init(_ event: Kind, game: String? = nil, level: String? = nil,
         mode: String? = nil, amount: Int? = nil) {
        self.event = event
        self.game = game
        self.level = level
        self.mode = mode
        self.amount = amount
    }

    private enum CodingKeys: String, CodingKey { case v, event, game, level, mode, amount }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(v, forKey: .v)
        try values.encode(event, forKey: .event)
        try values.encode(game, forKey: .game)
        try values.encode(level, forKey: .level)
        try values.encode(mode, forKey: .mode)
        if let amount { try values.encode(amount, forKey: .amount) }
    }
}

public struct AnonymousTelemetryCount: Codable, Sendable {
    public let day: String?
    public let event: String
    public let game: String?
    public let level: String?
    public let mode: String?
    public let count: Int
    public init(day: String?, event: String, game: String?, level: String?, mode: String?, count: Int) {
        self.day = day; self.event = event; self.game = game; self.level = level; self.mode = mode; self.count = count
    }
}

public struct AnonymousTelemetrySummary: Codable, Sendable {
    public let days: Int
    public let counts: [AnonymousTelemetryCount]
    public init(days: Int, counts: [AnonymousTelemetryCount]) { self.days = days; self.counts = counts }

    public func total(_ event: AnonymousTelemetryEvent.Kind, mode: String? = nil) -> Int {
        counts.filter { $0.event == event.rawValue && (mode == nil || $0.mode == mode) }
            .reduce(0) { $0 + $1.count }
    }
}

@MainActor public struct SavedLemmingsCounter {
    public let local: Int
    public let global: Int?

    public init(local: Int, global: Int?) { self.local = local; self.global = global }

    public var text: String {
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
@MainActor public final class AnonymousTelemetry {
    public static let shared = AnonymousTelemetry()
    public static let consentKey = "AnonymousTelemetryConsentV1"
    public static let decidedKey = "AnonymousTelemetryDecisionV1"
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
    public let endpoint: URL?
    private var active: Attempt?
    private var finishedAttempts = Set<UUID>()
    private var uploads: [UUID: Task<Void, Never>] = [:]
    public var onCountsChanged: (() -> Void)?

    /// A nil `defaults` uses `storage.defaults`. A nil `endpoint` uses the Info.plist value of `storage.bundle`.
    public init(storage: AppStorage = .current(), defaults: UserDefaults? = nil, endpoint: URL? = nil,
                transport: (any AnonymousTelemetryTransport)? = nil) {
        self.defaults = defaults ?? storage.defaults
        let supplied = endpoint ?? (storage.bundle.object(forInfoDictionaryKey: "AnonymousTelemetryURL") as? String)
            .flatMap(URL.init(string:))
        self.endpoint = supplied.flatMap { url in
            guard url.scheme == "https", url.host != nil, url.user == nil, url.password == nil,
                  url.query == nil, url.fragment == nil else { return nil }
            return url
        }
        self.transport = transport ?? URLSessionAnonymousTelemetryTransport()
    }

    public var sharingAvailable: Bool { endpoint != nil }
    public var consentDecided: Bool { defaults.bool(forKey: Self.decidedKey) }
    public var sharesCounts: Bool { endpoint != nil && defaults.bool(forKey: Self.consentKey) }

    public func setSharing(_ enabled: Bool) {
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

    public func clearLocalCounts() {
        defaults.removeObject(forKey: Self.countsKey)
        onCountsChanged?()
    }

    public func recordActiveDay() {
        guard sharesCounts else { return }
        let day = Self.utcDay()
        guard defaults.string(forKey: Self.activeDayKey) != day else { return }
        defaults.set(day, forKey: Self.activeDayKey)
        record(.init(.activeDay))
    }

    public func start(_ level: ArcadeLevel, hotSeat: Bool, attemptID: UUID) {
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

    public func finish(_ level: ArcadeLevel, hotSeat: Bool, attemptID: UUID, won: Bool, saved: Int) {
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

    public func soundtrackAllSelected() {
        guard !defaults.bool(forKey: Self.soundtrackSelectedKey) else { return }
        defaults.set(true, forKey: Self.soundtrackSelectedKey)
        record(.init(.allSoundtracksSelected))
    }

    public func soundtrackAllDownloaded() {
        guard !defaults.bool(forKey: Self.soundtrackDownloadedKey) else { return }
        defaults.set(true, forKey: Self.soundtrackDownloadedKey)
        record(.init(.allSoundtracksDownloaded))
    }

    public func localSummary() -> AnonymousTelemetrySummary {
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

    public var localSavedTotal: Int { localSummary().total(.lemmingsSaved) }

    public func publicSavedTotal() async throws -> Int {
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

    public func sharedSummary(token: String, days: Int = 30) async throws -> AnonymousTelemetrySummary {
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
