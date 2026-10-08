import AppKit
import CryptoKit
import Security
import NxlvKit

struct HostedBoard: Codable, Equatable {
    struct Entry: Codable, Equatable {
        let rank: Int
        let name: String
        let score: Int
        let runID: UUID?
        let replay: Bool
    }
    let entries: [Entry]
    let page: Int
    let hasMore: Bool
    let verification: String
}

enum HostedCategory: String, CaseIterable {
    case fastestClear, fastestAllSaved, mostSaved, leastSkills, stars, clears, perfect
    var title: String {
        switch self {
        case .fastestClear: "Fastest clear"
        case .fastestAllSaved: "Fastest 100%"
        case .mostSaved: "Most saved"
        case .leastSkills: "Least skills"
        case .stars: "Career stars"
        case .clears: "Levels cleared"
        case .perfect: "Three-star levels"
        }
    }
    var career: Bool { [.stars, .clears, .perfect].contains(self) }
    @MainActor func score(_ value: Int) -> String {
        [.fastestClear, .fastestAllSaved].contains(self) ? ArcadeView.time(Double(value) / 1000) : String(value)
    }
}

@MainActor protocol HostedRankingsTransport {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
    func upload(for request: URLRequest, fromFile file: URL) async throws -> (Data, URLResponse)
    func download(for request: URLRequest) async throws -> (URL, URLResponse)
}
@MainActor struct HostedURLTransport: HostedRankingsTransport {
    let session: URLSession
    func data(for request: URLRequest) async throws -> (Data, URLResponse) { try await session.data(for: request) }
    func upload(for request: URLRequest, fromFile file: URL) async throws -> (Data, URLResponse) { try await session.upload(for: request, fromFile: file) }
    func download(for request: URLRequest) async throws -> (URL, URLResponse) { try await session.download(for: request) }
}

/// Each local player owns a separate credential. Public records never identify an Apple account.
@MainActor final class HostedRankings {
    static var shared = HostedRankings()
    static let movieLimit = 64 * 1024 * 1024
    let endpoint: URL?
    let transport: any HostedRankingsTransport
    private let credentials: ((String) throws -> String)?
    let defaults: UserDefaults
    var onChange: (() -> Void)?
    var onSyncComplete: (() -> Void)?
    private(set) var board: HostedBoard?
    private(set) var busy = false
    private(set) var syncing = false
    private(set) var status = ""
    private(set) var syncStatus = ""
    private var requestID = UUID()
    private var submitted: Set<UUID> = []
    private var movies: Set<UUID> = []
    private var pending: Set<String> = []
    private var stopped: Set<String> = []
    var networkEnabled: Bool
    init(endpoint: URL? = nil, transport: (any HostedRankingsTransport)? = nil, defaults: UserDefaults = .standard,
         credentials: ((String) throws -> String)? = nil) {
        self.endpoint = endpoint ?? (Bundle.main.object(forInfoDictionaryKey: "HostedRankingsURL") as? String).flatMap(URL.init(string:))
        self.transport = transport ?? HostedURLTransport(session: URLSession(configuration: .ephemeral)); self.defaults = defaults
        self.credentials = credentials
        networkEnabled = ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] != "muted"
    }
    func hasShared(_ profile: String) -> Bool { defaults.bool(forKey: "HostedRankings.hasShared." + profile) }
    func sharing(_ profile: String) -> Bool { defaults.bool(forKey: "HostedRankings.share." + profile) }
    func setSharing(_ enabled: Bool, profile: String) {
        defaults.set(enabled, forKey: "HostedRankings.share." + profile)
        if enabled { stopped.remove(profile); completed(profileID: profile) }
        else { stopped.insert(profile) }
        onChange?()
    }
    static func conditionsJSON(_ conditions: TrolleyConditions) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(conditions), as: UTF8.self)
    }
    static func payload(_ run: ArcadeRun) throws -> Data {
        guard let conditions = run.level.conditions, conditions.isValid, run.seconds.isFinite,
              run.seconds >= 0, run.seconds * 1000 <= Double(Int32.max) else { throw URLError(.cannotParseResponse) }
        return try JSONSerialization.data(withJSONObject: [
            "id": run.id.uuidString.lowercased(), "conditionsJSON": conditionsJSON(conditions),
            "assisted": run.assisted, "saved": run.saved, "population": run.population,
            "skills": run.skillCount, "milliseconds": Int((run.seconds * 1000).rounded()), "won": run.qualifies
        ])
    }
    static func candidates(_ attempts: [TrolleyAttempt], profile: String) -> [ArcadeRun] {
        let own = attempts.filter { $0.run.profileID == profile }
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
        let code = SecItemCopyMatching(lookup as CFDictionary, &result)
        if code == errSecSuccess, let data = result as? Data, let token = String(data: data, encoding: .utf8) { return token }
        guard code == errSecItemNotFound else { throw URLError(.userAuthenticationRequired) }
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw URLError(.unknown) }
        let token = bytes.map { String(format: "%02x", $0) }.joined()
        var entry = query; entry[kSecValueData as String] = Data(token.utf8)
        entry[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(entry as CFDictionary, nil) == errSecSuccess else { throw URLError(.cannotCreateFile) }
        return token
    }
    func request(_ path: String, method: String = "GET", token: String? = nil, data: Data? = nil) throws -> URLRequest {
        guard networkEnabled, let endpoint, endpoint.scheme == "https", let url = URL(string: endpoint.absoluteString + path) else { throw URLError(.notConnectedToInternet) }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        request.httpMethod = method; request.httpBody = data
        request.setValue("UltimateLemmings/1.8.2", forHTTPHeaderField: "User-Agent")
        if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        if data != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        return request
    }
    func checked(_ response: URLResponse, allowingConflict: Bool = false) throws {
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) || (allowingConflict && response.statusCode == 409) else { throw URLError(.badServerResponse) }
    }
    func refresh(conditions: TrolleyConditions?, category: HostedCategory, assisted: Bool, page: Int = 0) {
        requestID = UUID(); let ticket = requestID
        board = nil; busy = true; status = "Loading..."; onChange?()
        guard category.career || conditions != nil else { busy = false; status = "Select a level first."; onChange?(); return }
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
                status = "Offline. Local records are saved."
            }
            busy = false; onChange?()
        }
    }
    func completed(profileID: String) {
        guard networkEnabled, endpoint != nil, sharing(profileID) else { return }
        pending.insert(profileID)
        guard !syncing else { return }
        syncing = true
        Task { [weak self] in
            guard let self else { return }
            defer { syncing = false; onSyncComplete?(); onChange?() }
            while let profile = pending.first {
                pending.remove(profile)
                guard sharing(profile), let player = ArcadeStore.shared.records.profile(profile) else { continue }
                do {
                    let token = try credential(profile)
                    let register = try request("/v1/players", method: "POST", token: token,
                                               data: JSONSerialization.data(withJSONObject: ["name": player.initials]))
                    let (_, response) = try await transport.data(for: register); try checked(response)
                    defaults.set(true, forKey: "HostedRankings.hasShared." + profile)
                    let runs = Self.candidates(ArcadeStore.shared.records.trolley.attempts, profile: profile)
                    for run in runs {
                        guard sharing(profile), !stopped.contains(profile) else { break }
                        if !submitted.contains(run.id) {
                            let post = try request("/v1/runs", method: "POST", token: token, data: Self.payload(run))
                            let (_, response) = try await transport.data(for: post); try checked(response)
                            submitted.insert(run.id)
                        }
                    }
                    var movieFailure = false
                    for run in runs {
                        guard sharing(profile), !stopped.contains(profile) else { break }
                        guard !movies.contains(run.id), let file = ArcadeStore.shared.replayURL(attemptID: run.id) else { continue }
                        guard let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= Self.movieLimit else { movieFailure = true; continue }
                        do {
                            var upload = try request("/v1/replays/" + run.id.uuidString.lowercased(), method: "PUT", token: token)
                            upload.setValue("video/mp4", forHTTPHeaderField: "Content-Type")
                            let (_, response) = try await transport.upload(for: upload, fromFile: file)
                            try checked(response, allowingConflict: true); movies.insert(run.id)
                        } catch { movieFailure = true; break }
                    }
                    syncStatus = movieFailure ? "Scores shared. Some replays remain local." : "Records shared"; onChange?()
                } catch { syncStatus = "Sync incomplete. Retry to share local records."; onChange?() }
            }
        }
    }
    func remove(profile: String) {
        guard !syncing, !busy else { return }
        setSharing(false, profile: profile); pending.remove(profile)
        busy = true
        Task {
            defer { busy = false; onChange?() }
            do {
                let deletion = try request("/v1/player", method: "DELETE", token: credential(profile))
                let (_, response) = try await transport.data(for: deletion)
                if (response as? HTTPURLResponse)?.statusCode != 401 { try checked(response) }
                defaults.set(false, forKey: "HostedRankings.hasShared." + profile)
                submitted = []; movies = []; board = nil; status = "Shared records removed"
            } catch { status = "Removal failed. Retry when connected." }
        }
    }
    func playback(_ entry: HostedBoard.Entry, opened: @escaping (URL, String) -> Void) {
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
                opened(file, "\(entry.name) - worldwide replay"); status = "Community records"
            } catch { status = "Replay unavailable. Retry when connected." }
        }
    }
}
