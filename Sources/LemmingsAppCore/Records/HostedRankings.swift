import Foundation
import CryptoKit
import Security
import NxlvKit

public struct HostedBoard: Codable, Equatable {
    public struct Entry: Codable, Equatable {
        public let rank: Int
        public let name: String
        public let score: Int
        public let runID: UUID?
        public let replay: Bool
        public var actionReplay: Bool? = nil
        public init(rank: Int, name: String, score: Int, runID: UUID?, replay: Bool, actionReplay: Bool? = nil) {
            self.rank = rank; self.name = name; self.score = score; self.runID = runID
            self.replay = replay; self.actionReplay = actionReplay
        }
    }
    public let entries: [Entry]
    public let page: Int
    public let hasMore: Bool
    public let verification: String
    public init(entries: [Entry], page: Int, hasMore: Bool, verification: String) {
        self.entries = entries; self.page = page; self.hasMore = hasMore; self.verification = verification
    }
    /// Rank 1 can be shared. Every tied first-place entry leads.
    public var leaders: [Entry] { page == 0 ? entries.filter { $0.rank == 1 } : [] }
}

public enum HostedCategory: String, CaseIterable, Sendable {
    case fastestClear, fastestAllSaved, mostSaved, leastSkills, stars, clears, perfect
    public var title: String {
        switch self {
        case .fastestClear: L10n.text("Fastest clear")
        case .fastestAllSaved: L10n.text("Fastest 100%")
        case .mostSaved: L10n.text("Most saved")
        case .leastSkills: L10n.text("Least skills")
        case .stars: L10n.text("Career stars")
        case .clears: L10n.text("Levels cleared")
        case .perfect: L10n.text("Three-star levels")
        }
    }
    public var career: Bool { [.stars, .clears, .perfect].contains(self) }
    /// Worldwide ranks every shared player once across all levels.
    public static let worldwide: [HostedCategory] = [.stars, .clears, .perfect]
    /// Each level ranks every shared player once by their best direct run on that level.
    public static let level: [HostedCategory] = [.mostSaved, .fastestClear, .fastestAllSaved, .leastSkills]
    /// The next metric in the same leaderboard kind, wrapping at the end.
    public func next(_ offset: Int = 1) -> HostedCategory {
        let list = career ? Self.worldwide : Self.level
        let index = list.firstIndex(of: self) ?? 0
        return list[((index + offset) % list.count + list.count) % list.count]
    }
    @MainActor public func score(_ value: Int) -> String {
        let seconds = Double(value) / 1000
        return [.fastestClear, .fastestAllSaved].contains(self)
            ? String(format: "%d:%05.2f", Int(seconds) / 60, seconds.truncatingRemainder(dividingBy: 60)) : String(value)
    }
}

/// Shared row text for both leaderboard kinds, so every platform reads the same list.
public enum HostedLeaderboardText {
    @MainActor public static func row(_ entry: HostedBoard.Entry, category: HostedCategory) -> String {
        "#\(entry.rank)  \(entry.name)  " + category.score(entry.score)
    }
    /// One line naming the current leader or tied leaders. Nil when nobody has shared a result.
    @MainActor public static func leaders(_ board: HostedBoard?, category: HostedCategory) -> String? {
        guard let board, let first = board.leaders.first else { return nil }
        let names = board.leaders.map(\.name).joined(separator: ", ")
        return board.leaders.count == 1
            ? L10n.text("Leader: \(names)  \(category.score(first.score))")
            : L10n.text("Leaders: \(names)  \(category.score(first.score))")
    }
}

@MainActor public protocol HostedRankingsTransport {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
    func upload(for request: URLRequest, fromFile file: URL) async throws -> (Data, URLResponse)
    func download(for request: URLRequest) async throws -> (URL, URLResponse)
}
@MainActor public struct HostedURLTransport: HostedRankingsTransport {
    public let session: URLSession
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) { try await session.data(for: request) }
    public func upload(for request: URLRequest, fromFile file: URL) async throws -> (Data, URLResponse) { try await session.upload(for: request, fromFile: file) }
    public func download(for request: URLRequest) async throws -> (URL, URLResponse) { try await session.download(for: request) }
}

/// Each local player owns a separate credential. Public records never identify an Apple account.
@MainActor open class HostedRankingsService {
    public static let movieLimit = 64 * 1024 * 1024
    private let recordsStoreProvider: @MainActor () -> ArcadeStore
    public let endpoint: URL?
    public let transport: any HostedRankingsTransport
    private let credentials: ((String) throws -> String)?
    private let countSharing: @MainActor () -> Bool
    public let defaults: UserDefaults
    public var onChange: (() -> Void)?
    public var onSyncComplete: (() -> Void)?
    public private(set) var board: HostedBoard?
    public private(set) var busy = false
    public private(set) var syncing = false
    public private(set) var status = ""
    public private(set) var syncStatus = ""
    private var requestID = UUID()
    /// The level leaderboard loads beside the worldwide board, so a result screen never clears it.
    public var onLevelChange: (() -> Void)?
    public private(set) var levelBoard: HostedBoard?
    public private(set) var levelConditions: TrolleyConditions?
    public private(set) var levelBusy = false
    public private(set) var levelStatus = ""
    public private(set) var levelCategory = HostedCategory.mostSaved
    private var levelRequestID = UUID()
    private var submitted: Set<UUID> = []
    private var actions: Set<UUID> = []
    private var pending: Set<String> = []
    private var stopped: Set<String> = []
    private var deleting = false
    private var removals: Set<String> {
        get { Set(defaults.stringArray(forKey: "HostedRankings.pendingRemoval") ?? []) }
        set { defaults.set(Array(newValue), forKey: "HostedRankings.pendingRemoval") }
    }
    public var networkEnabled: Bool
    public init(endpoint: URL? = nil, transport: (any HostedRankingsTransport)? = nil, defaults: UserDefaults = .standard,
         credentials: ((String) throws -> String)? = nil, countSharing: (@MainActor () -> Bool)? = nil,
         recordsStoreProvider: @escaping @MainActor () -> ArcadeStore) {
        self.recordsStoreProvider = recordsStoreProvider
        let telemetry = AnonymousTelemetry(defaults: defaults)
        self.countSharing = countSharing ?? { telemetry.sharesCounts }
        self.endpoint = endpoint ?? (Bundle.main.object(forInfoDictionaryKey: "HostedRankingsURL") as? String).flatMap(URL.init(string:))
        self.transport = transport ?? HostedURLTransport(session: URLSession(configuration: .ephemeral)); self.defaults = defaults
        self.credentials = credentials
        networkEnabled = ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] != "muted"
    }
    public func hasShared(_ profile: String) -> Bool { defaults.bool(forKey: "HostedRankings.hasShared." + profile) }
    public func sharing(_ profile: String) -> Bool {
        let key = "HostedRankings.share." + profile
        return defaults.object(forKey: key) == nil ? countSharing() : defaults.bool(forKey: key)
    }
    /// Apply count sharing at launch and when its setting changes. Explicit player choices remain in force.
    public func countSharingChanged() {
        pending = pending.filter { sharing($0) }
        for profile in recordsStoreProvider().records.profiles where sharing(profile.id) {
            completed(profileID: profile.id)
        }
        onChange?()
    }
    public func setSharing(_ enabled: Bool, profile: String) {
        guard !enabled || !removals.contains(profile) else { retryRemovals(); return }
        defaults.set(enabled, forKey: "HostedRankings.share." + profile)
        if enabled { stopped.remove(profile); completed(profileID: profile) }
        else { stopped.insert(profile) }
        onChange?()
    }
    public static func conditionsJSON(_ conditions: TrolleyConditions) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(conditions), as: UTF8.self)
    }
    public static func payload(_ run: ArcadeRun) throws -> Data {
        guard !run.usedBonusSkill, let conditions = run.level.conditions, conditions.isValid, run.seconds.isFinite,
              run.seconds >= 0, run.seconds * 1000 <= Double(Int32.max) else { throw URLError(.cannotParseResponse) }
        return try JSONSerialization.data(withJSONObject: [
            "id": run.id.uuidString.lowercased(), "conditionsJSON": conditionsJSON(conditions),
            "assisted": run.assisted, "saved": run.saved, "population": run.population,
            "skills": run.skillCount, "milliseconds": Int((run.seconds * 1000).rounded()), "won": run.qualifies
        ])
    }
    public static func candidates(_ attempts: [TrolleyAttempt], profile: String) -> [ArcadeRun] {
        let own = attempts.filter { $0.run.profileID == profile && !$0.run.usedBonusSkill }
        var winners: [UUID: ArcadeRun] = [:]
        for group in Dictionary(grouping: own, by: \.comparisonID).values {
            for category: TrolleyBoard in [.mostSaved, .leastSkills, .fastestClear, .fastestAllSaved] {
                let eligible = group.filter { TrolleyLeaderboards.eligible($0, board: category, maximum: $0.maximum) }
                if let best = eligible.sorted(by: { hostedPrecedes($0.run, $1.run, category: category) }).first {
                    winners[best.id] = best.run
                }
            }
            // Career stars need the best successful rescue even if a failed run saved more.
            if let best = group.filter({ $0.run.qualifies }).sorted(by: {
                hostedPrecedes($0.run, $1.run, category: .mostSaved)
            }).first { winners[best.id] = best.run }
        }
        return winners.values.sorted { $0.date < $1.date }
    }
    private static func hostedPrecedes(_ a: ArcadeRun, _ b: ArcadeRun, category: TrolleyBoard) -> Bool {
        if [.fastestClear, .fastestAllSaved].contains(category), a.seconds != b.seconds { return a.seconds < b.seconds }
        if category == .leastSkills, a.skillCount != b.skillCount { return a.skillCount < b.skillCount }
        if a.saved != b.saved { return a.saved > b.saved }
        if a.skillCount != b.skillCount { return a.skillCount < b.skillCount }
        if a.seconds != b.seconds { return a.seconds < b.seconds }
        if a.date != b.date { return a.date < b.date }
        return a.id.uuidString < b.id.uuidString
    }
    private func credential(_ profile: String) throws -> String {
        if let credentials { return try credentials(profile) }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "academy.glasscode.lemmings.rankings", kSecAttrAccount as String: profile]
        var lookup = query; lookup[kSecReturnData as String] = true
        var result: CFTypeRef?
        let code = BackgroundKeychain.perform { SecItemCopyMatching(lookup as CFDictionary, &result) }
        if code == errSecSuccess, let data = result as? Data, let token = String(data: data, encoding: .utf8) { return token }
        guard code == errSecItemNotFound else { throw URLError(.userAuthenticationRequired) }
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw URLError(.unknown) }
        let token = bytes.map { String(format: "%02x", $0) }.joined()
        var entry = query; entry[kSecValueData as String] = Data(token.utf8)
        entry[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard BackgroundKeychain.perform({ SecItemAdd(entry as CFDictionary, nil) }) == errSecSuccess else { throw URLError(.cannotCreateFile) }
        return token
    }
    public func request(_ path: String, method: String = "GET", token: String? = nil, data: Data? = nil) throws -> URLRequest {
        guard networkEnabled, let endpoint, endpoint.scheme == "https", let url = URL(string: endpoint.absoluteString + path) else { throw URLError(.notConnectedToInternet) }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        request.httpMethod = method; request.httpBody = data
        request.setValue("UltimateLemmings/1.9.2", forHTTPHeaderField: "User-Agent")
        if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        if data != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        return request
    }
    public func checked(_ response: URLResponse, allowingConflict: Bool = false) throws {
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) || (allowingConflict && response.statusCode == 409) else { throw URLError(.badServerResponse) }
    }
    public func refresh(conditions: TrolleyConditions?, category: HostedCategory, assisted: Bool, page: Int = 0) {
        requestID = UUID(); let ticket = requestID
        board = nil; busy = true; status = "Loading..."; onChange?()
        retryRemovals()
        guard category.career || conditions != nil else { busy = false; status = L10n.text("Select a level first."); onChange?(); return }
        Task { [weak self] in
            guard let self else { return }
            do {
                let request = try self.request("/v1/boards?board=\(category.rawValue)&assisted=\(assisted ? 1 : 0)&page=\(page)&conditions=\(conditions?.fingerprint ?? "career")")
                let (data, response) = try await transport.data(for: request)
                try checked(response)
                let loaded = try JSONDecoder().decode(HostedBoard.self, from: data)
                guard ticket == requestID else { return }
                board = loaded; status = "Community records"
            } catch {
                guard ticket == requestID else { return }
                status = L10n.text("Offline. Local records are saved.")
            }
            busy = false; onChange?()
        }
    }
    /// Load one level's ranking. Direct runs only, first page, so rank 1 is always present.
    public func refreshLevel(conditions: TrolleyConditions?, category: HostedCategory? = nil) {
        if let category, !category.career { levelCategory = category }
        levelRequestID = UUID(); let ticket = levelRequestID
        levelConditions = conditions; levelBoard = nil
        guard let conditions else { levelBusy = false; levelStatus = ""; onLevelChange?(); return }
        levelBusy = true; levelStatus = L10n.text("Loading..."); onLevelChange?()
        let board = levelCategory
        Task { [weak self] in
            guard let self else { return }
            do {
                let request = try self.request("/v1/boards?board=\(board.rawValue)&assisted=0&page=0&conditions=\(conditions.fingerprint)")
                let (data, response) = try await transport.data(for: request)
                try checked(response)
                let loaded = try JSONDecoder().decode(HostedBoard.self, from: data)
                guard ticket == levelRequestID else { return }
                levelBoard = loaded; levelStatus = loaded.entries.isEmpty ? L10n.text("No shared records yet.") : ""
            } catch {
                guard ticket == levelRequestID else { return }
                levelStatus = L10n.text("Offline. Local records are saved.")
            }
            levelBusy = false; onLevelChange?()
        }
    }
    public func completed(profileID: String) {
        retryRemovals()
        guard networkEnabled, endpoint != nil, sharing(profileID) else { return }
        pending.insert(profileID)
        guard !syncing, !deleting else { return }
        syncing = true
        Task { [weak self] in
            guard let self else { return }
            defer {
                syncing = false; retryRemovals(); onSyncComplete?(); onChange?()
                // A just-shared result must appear on the level board that the result screen shows.
                if let conditions = levelConditions { refreshLevel(conditions: conditions) }
            }
            while let profile = pending.first {
                pending.remove(profile)
                guard sharing(profile), let player = recordsStoreProvider().records.profile(profile) else { continue }
                do {
                    let token = try credential(profile)
                    let register = try request("/v1/players", method: "POST", token: token,
                                               data: JSONSerialization.data(withJSONObject: ["name": player.initials]))
                    let (_, response) = try await transport.data(for: register); try checked(response)
                    defaults.set(true, forKey: "HostedRankings.hasShared." + profile)
                    let runs = Self.candidates(recordsStoreProvider().records.trolley.attempts, profile: profile)
                    for run in runs {
                        guard sharing(profile), !stopped.contains(profile) else { break }
                        if !submitted.contains(run.id) {
                            let post = try request("/v1/runs", method: "POST", token: token, data: Self.payload(run))
                            let (_, response) = try await transport.data(for: post); try checked(response)
                            submitted.insert(run.id)
                        }
                    }
                    var replayFailure = false
                    for run in runs {
                        guard sharing(profile), !stopped.contains(profile) else { break }
                        guard !actions.contains(run.id), let file = recordsStoreProvider().actionReplayURL(attemptID: run.id) else { continue }
                        guard let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                              size <= LeaderboardActionReplay.byteLimit else { replayFailure = true; continue }
                        do {
                            var upload = try request("/v1/actions/" + run.id.uuidString.lowercased(), method: "PUT", token: token)
                            upload.setValue("application/json", forHTTPHeaderField: "Content-Type")
                            let (_, response) = try await transport.upload(for: upload, fromFile: file)
                            try checked(response, allowingConflict: true); actions.insert(run.id)
                        } catch { replayFailure = true; break }
                    }
                    syncStatus = replayFailure ? L10n.text("Scores shared. Some replays remain local.") : "Records shared"; onChange?()
                } catch { syncStatus = L10n.text("Sync incomplete. Retry to share local records."); onChange?() }
            }
        }
    }
    public func profileDeleted(_ profile: String) {
        if sharing(profile) || hasShared(profile) { remove(profile: profile) }
    }
    public func remove(profile: String) {
        setSharing(false, profile: profile); pending.remove(profile)
        removals.insert(profile)
        retryRemovals()
    }
    private func retryRemovals() {
        guard networkEnabled, endpoint != nil, !syncing, !deleting, !removals.isEmpty else { return }
        deleting = true; busy = true; requestID = UUID(); board = nil
        Task {
            defer {
                deleting = false; busy = false; onChange?()
                if removals.isEmpty, let profile = pending.first { completed(profileID: profile) }
            }
            for profile in removals {
                do {
                    let deletion = try request("/v1/player", method: "DELETE", token: credential(profile))
                    let (_, response) = try await transport.data(for: deletion)
                    if (response as? HTTPURLResponse)?.statusCode != 401 { try checked(response) }
                    defaults.set(false, forKey: "HostedRankings.hasShared." + profile)
                    removals.remove(profile)
                    submitted = []; actions = []; board = nil; status = "Shared records removed"
                } catch { status = L10n.text("Removal queued. Retry when connected.") }
            }
        }
    }
    public func playbackActions(_ entry: HostedBoard.Entry, conditions: TrolleyConditions?,
                         opened: @escaping (LeaderboardActionReplay, String) -> Void) {
        guard let id = entry.runID, entry.actionReplay == true, (1...10).contains(entry.rank),
              let conditions, !busy else { return }
        busy = true; status = "Loading replay..."; onChange?()
        Task {
            defer { busy = false; onChange?() }
            do {
                let (file, response) = try await transport.download(for: request("/v1/actions/" + id.uuidString.lowercased()))
                defer { try? FileManager.default.removeItem(at: file) }
                try checked(response)
                guard response.mimeType == "application/json", let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                      size > 0, size <= LeaderboardActionReplay.byteLimit else { throw URLError(.dataLengthExceedsMaximum) }
                let data = try Data(contentsOf: file)
                let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                guard (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "X-Replay-SHA256") == hash else { throw URLError(.cannotParseResponse) }
                let replay = try JSONDecoder().decode(LeaderboardActionReplay.self, from: data)
                try replay.validateStructure()
                guard replay.runID == id, replay.conditions == conditions else { throw RunRecoveryError.differentGame }
                opened(replay, L10n.text("\(entry.name) - worldwide replay")); status = "Community records"
            } catch { status = L10n.text("Replay unavailable. Retry when connected.") }
        }
    }
    public func playback(_ entry: HostedBoard.Entry, opened: @escaping (URL, String) -> Void) {
        guard let id = entry.runID, entry.replay, !busy else { return }
        busy = true; status = "Loading replay..."; onChange?()
        Task {
            defer { busy = false; onChange?() }
            do {
                let (file, response) = try await transport.download(for: request("/v1/replays/" + id.uuidString.lowercased()))
                defer { try? FileManager.default.removeItem(at: file) }
                try checked(response)
                guard response.mimeType == "video/mp4", let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                      size > 0, size <= Self.movieLimit else { throw URLError(.dataLengthExceedsMaximum) }
                opened(file, L10n.text("\(entry.name) - worldwide replay")); status = "Community records"
            } catch { status = L10n.text("Replay unavailable. Retry when connected.") }
        }
    }
}
