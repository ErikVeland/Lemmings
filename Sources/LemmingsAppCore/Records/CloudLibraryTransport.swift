import CryptoKit
import Foundation
#if !os(tvOS)
import LocalAuthentication
#endif
import NxlvKit
import Security

@MainActor public protocol CloudLibraryTransport: AnyObject {
    func discover(_ identities: [CloudLibraryIdentity]) async throws -> [CloudLibraryIdentity]
    func load(_ identity: CloudLibraryIdentity) async throws -> [Data]
    func save(_ data: Data, identity: CloudLibraryIdentity, device: String) async throws
}

/// The credential is private, recoverable through iCloud, and transferable by a
/// one-use code. Hosted storage sees only authenticated ciphertext.
@MainActor public final class AppleCloudLibraryTransport: CloudLibraryTransport {
    public private(set) var providers: Set<String> = []
    public private(set) var issues: [String] = []
    private let defaults: UserDefaults
    private let endpoint: URL?
    private let network: URLSession
    private let enabled: Bool
    private var root: URL?
    private var account: Data?
    private var readable: [String: Set<String>] = [:]
    private var etags: [String: String] = [:]
    private var hashes: [String: Set<Data>] = [:]
    private lazy var cloudKit = CloudKitLibraryStore(defaults: defaults)
    private var cloudKitReady = false
    private var cloudKitEnabled: Bool { Bundle.main.object(forInfoDictionaryKey: "CloudLibraryCloudKitEnabled") as? Bool == true }
    private static let service = "academy.glasscode.lemmings.cloud-library-v2"
#if os(tvOS)
    private static let containerIdentifier = "iCloud.academy.glasscode.lemmings"
#else
    private static let containerIdentifier = AppleGameProgressTransport.containerIdentifier
#endif
    public var available: Bool { enabled }
    public init(defaults: UserDefaults = .standard, endpoint: URL? = nil) {
        self.defaults = defaults
        self.endpoint = endpoint ?? (Bundle.main.object(forInfoDictionaryKey: "CloudLibraryURL") as? String).flatMap(URL.init(string:))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15; configuration.timeoutIntervalForResource = 45
        network = URLSession(configuration: configuration)
        enabled = ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] != "muted"
    }
    public func credentials() throws -> [CloudLibraryIdentity] {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service, kSecAttrAccount as String: "library",
            kSecReturnData as String: true]
#if !os(tvOS)
        let context = LAContext(); context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context
#endif
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess, let data = result as? Data else { throw SequelDataError.invalid(L10n.text("Unlock this device to access cloud saves.")) }
        let identities = try JSONDecoder().decode([CloudLibraryIdentity].self, from: data)
        try Self.validate(identities); return identities
    }
    public func storeCredentials(_ identities: [CloudLibraryIdentity]) throws {
        try Self.validate(identities)
        let data = try JSONEncoder().encode(identities)
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service, kSecAttrAccount as String: "library"]
#if !os(tvOS)
        let context = LAContext(); context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context
#endif
        let update = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecItemNotFound {
            var entry = query; entry.removeValue(forKey: kSecUseAuthenticationContext as String); entry[kSecValueData as String] = data
            entry[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(entry as CFDictionary, nil) == errSecSuccess else { throw SequelDataError.invalid(L10n.text("The library key could not be saved.")) }
        } else if update != errSecSuccess { throw SequelDataError.invalid(L10n.text("The library key could not be saved.")) }
    }
    private static func validate(_ identities: [CloudLibraryIdentity]) throws {
        guard identities.count <= 16, Set(identities.map(\.id)).count == identities.count else { throw SequelDataError.invalid(L10n.text("Too many linked libraries.")) }
        for identity in identities { try identity.validate() }
    }
    private func currentAccount() throws -> Data? {
        guard let token = FileManager.default.ubiquityIdentityToken else { return nil }
        return try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: false)
    }
    private func checkAccount() throws {
        guard try currentAccount() == account else { throw SequelDataError.invalid(L10n.text("The iCloud account changed. Existing saves were kept.")) }
    }
    public func discover(_ local: [CloudLibraryIdentity]) async throws -> [CloudLibraryIdentity] {
        guard enabled else { throw URLError(.notConnectedToInternet) }
        providers = []; issues = []; readable = [:]; root = nil; cloudKitReady = false
        var identities = local
        #if !os(tvOS)
        account = try currentAccount()
        if let account {
            if let bound = defaults.data(forKey: "CloudLibrary.iCloudOwner"), bound != account {
                issues.append("iCloud account changed")
            } else {
                let containerIdentifier = Self.containerIdentifier
                let url = await Task.detached(priority: .utility) {
                    FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier)
                }.value
                if let url {
                    try checkAccount()
                    root = url.appendingPathComponent("Documents/PrivateLibrary-v2", isDirectory: true)
                    let cloudRoot = root!
                    do {
                        let found = try await Task.detached(priority: .utility) {
                            try Self.readIdentities(at: cloudRoot)
                        }.value
                        try checkAccount()
                        for identity in found {
                            if let previous = identities.first(where: { $0.id == identity.id }) {
                                guard previous == identity else { throw SequelDataError.invalid(L10n.text("The library keys conflict.")) }
                            } else { identities.append(identity) }
                        }
                        try Self.validate(identities)
                        // First-use creation is local and private. Distinct identity
                        // files retain both sides if two offline devices start together.
                        if identities.isEmpty { identities = [CloudLibraryIdentity()] }
                        let toWrite = identities
                        try await Task.detached(priority: .utility) {
                            for identity in toWrite where !found.contains(where: { $0.id == identity.id }) {
                                try Self.write(try JSONEncoder().encode(identity), at: cloudRoot.appendingPathComponent("identity-\(identity.id).json"))
                            }
                        }.value
                        try checkAccount()
                        defaults.set(account, forKey: "CloudLibrary.iCloudOwner")
                        providers.insert("iCloud Drive")
                    } catch {
                        root = nil; issues.append("iCloud unavailable")
                        // A malformed identity must not be replaced or published.
                        if error is DecodingError || error is SequelDataError { throw error }
                    }
                } else { issues.append("iCloud unavailable") }
            }
        }
        #endif
        if cloudKitEnabled {
            do {
                identities = try await cloudKit.discover(identities)
                cloudKitReady = true
            } catch {
                issues.append("iCloud unavailable")
                if error is DecodingError || error is SequelDataError { throw error }
            }
        }
        if identities.isEmpty { identities = [CloudLibraryIdentity()] }
        try Self.validate(identities)
        return identities.sorted { $0.id < $1.id }
    }
    private nonisolated static func readIdentities(at root: URL) throws -> [CloudLibraryIdentity] {
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        let files = try Self.files(at: root)
            .filter { $0.lastPathComponent.hasPrefix("identity-") && $0.pathExtension == "json" }
        guard files.count <= 16 else { throw SequelDataError.invalid(L10n.text("Too many iCloud libraries.")) }
        return try files.map { file in
            let data = try read(at: file, limit: 4096)
            let identity = try JSONDecoder().decode(CloudLibraryIdentity.self, from: data)
            try identity.validate()
            guard file.lastPathComponent == "identity-\(identity.id).json" else { throw SequelDataError.invalid(L10n.text("Invalid iCloud library identity.")) }
            return identity
        }
    }
    private nonisolated static func files(at root: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).map { file in
            let name = file.lastPathComponent
            if name.hasPrefix("."), name.hasSuffix(".icloud") {
                return root.appendingPathComponent(String(name.dropFirst().dropLast(7)))
            }
            return file
        }
    }
    private nonisolated static func read(at url: URL, limit: Int) throws -> Data {
        try FileManager.default.startDownloadingUbiquitousItem(at: url)
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var result: Result<Data, Error>?
        coordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinationError) { file in
            result = Result {
                let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? limit + 1
                guard size <= limit else { throw SequelDataError.invalid(L10n.text("The cloud save is too large.")) }
                return try Data(contentsOf: file)
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        return try result.get()
    }
    private nonisolated static func write(_ data: Data, at url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?, writeError: Error?
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { file in
            do { try data.write(to: file, options: .atomic) } catch { writeError = error }
        }
        if let coordinationError { throw coordinationError }
        if let writeError { throw writeError }
    }
    public func load(_ identity: CloudLibraryIdentity) async throws -> [Data] {
        var data: [Data] = [], success = Set<String>()
        hashes[identity.id + "iCloud"] = []; hashes[identity.id + "Cloud"] = []
        hashes[identity.id + "CloudKit"] = []
        if cloudKitReady {
            do {
                let cloud = try await cloudKit.load(identity)
                data += cloud; success.insert("CloudKit"); providers.insert("iCloud")
                hashes[identity.id + "CloudKit"] = Set(cloud.map { Data(SHA256.hash(data: $0)) })
            } catch { issues.append("iCloud saves unavailable") }
        }
        if let root {
            do {
                try checkAccount()
                let folder = root.appendingPathComponent(identity.id, isDirectory: true)
                let cloud = try await Task.detached(priority: .utility) {
                    guard FileManager.default.fileExists(atPath: folder.path) else { return [Data]() }
                    let files = try Self.files(at: folder).filter { $0.pathExtension == "save" }
                    guard files.count <= 256 else { throw SequelDataError.invalid(L10n.text("Too many iCloud saves.")) }
                    return try files.map { try identity.open(Self.read(at: $0, limit: CloudLibraryArchive.maximumBytes + 28)) }
                }.value
                // Decode every version before marking this provider writable.
                for value in cloud { _ = try CloudLibraryArchive.decode(value) }
                try checkAccount(); data += cloud; success.insert("iCloud")
                hashes[identity.id + "iCloud"] = Set(cloud.map { Data(SHA256.hash(data: $0)) })
            } catch { issues.append("iCloud saves unavailable") }
        }
        if endpoint != nil {
            do {
                etags = etags.filter { !$0.key.hasPrefix("/v1/vaults/\(identity.id)/") }
                let (body, status) = try await request("/v1/vaults/\(identity.id)", token: identity.token, allowMissing: true)
                if status != 404 {
                    struct Manifest: Decodable { let devices: [String] }
                    let manifest = try JSONDecoder().decode(Manifest.self, from: body)
                    guard manifest.devices.count <= 32, manifest.devices.allSatisfy({ UUID(uuidString: $0) != nil }) else { throw SequelDataError.invalid(L10n.text("Invalid cloud device list.")) }
                    for device in manifest.devices {
                        let (sealed, _) = try await request("/v1/vaults/\(identity.id)/devices/\(device)", token: identity.token)
                        let opened = try identity.open(sealed)
                        _ = try CloudLibraryArchive.decode(opened); data.append(opened)
                        hashes[identity.id + "Cloud", default: []].insert(Data(SHA256.hash(data: opened)))
                    }
                }
                success.insert("Cloud"); providers.insert("Cloud")
            } catch { issues.append("Cloud offline") }
        }
        readable[identity.id] = success
        guard !success.isEmpty else { throw URLError(.notConnectedToInternet) }
        return data
    }
    public func save(_ data: Data, identity: CloudLibraryIdentity, device: String) async throws {
        _ = try CloudLibraryArchive.decode(data)
        let sealed = try identity.seal(data)
        let contentHash = Data(SHA256.hash(data: data))
        var saved = false
        if readable[identity.id]?.contains("CloudKit") == true {
            if hashes[identity.id + "CloudKit"]?.contains(contentHash) == true { saved = true }
            else {
                do { try await cloudKit.save(data, identity: identity, device: device); saved = true }
                catch { issues.append("iCloud upload pending") }
            }
        }
        if readable[identity.id]?.contains("iCloud") == true, let root {
            if hashes[identity.id + "iCloud"]?.contains(contentHash) == true { saved = true }
            else {
            do {
                try checkAccount()
                let folder = root.appendingPathComponent(identity.id, isDirectory: true)
                // Content-addressed files cannot overwrite another device or an
                // unresolved iCloud conflict. Keep the previous local generation.
                let digest = SHA256.hash(data: data).prefix(12).map { String(format: "%02x", $0) }.joined()
                try await Task.detached(priority: .utility) {
                    let file = folder.appendingPathComponent("\(device)-\(digest).save")
                    if !FileManager.default.fileExists(atPath: file.path) { try Self.write(sealed, at: file) }
                    let old = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])
                        .filter { $0.lastPathComponent.hasPrefix(device + "-") && $0.pathExtension == "save" }
                        .sorted { a, b in
                            let first = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                            let second = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                            return first > second
                        }
                    // Every old generation was decoded during load before this save.
                    for obsolete in old.dropFirst(2) where obsolete != file { try FileManager.default.removeItem(at: obsolete) }
                }.value
                try checkAccount(); saved = true
            } catch { issues.append("iCloud upload pending") }
            }
        }
        if readable[identity.id]?.contains("Cloud") == true {
            if hashes[identity.id + "Cloud"]?.contains(contentHash) == true { saved = true }
            else {
            do {
                _ = try await request("/v1/vaults/\(identity.id)/devices/\(device)", method: "PUT", token: identity.token, body: sealed)
                saved = true
            } catch { issues.append("Cloud upload pending") }
            }
        }
        guard saved else { throw URLError(.notConnectedToInternet) }
    }
    private func request(_ path: String, method: String = "GET", token: String? = nil, body: Data? = nil, allowMissing: Bool = false) async throws -> (Data, Int) {
        guard enabled, let endpoint, endpoint.scheme == "https", let url = URL(string: endpoint.absoluteString + path) else { throw URLError(.notConnectedToInternet) }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = method; request.httpBody = body
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        if method == "PUT" { request.setValue(etags[path] ?? "*", forHTTPHeaderField: "If-Match") }
        let (data, response) = try await network.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) || (allowMissing && response.statusCode == 404) else { throw URLError(.badServerResponse) }
        guard data.count <= CloudLibraryArchive.maximumBytes + 28 else { throw SequelDataError.invalid(L10n.text("The cloud response is too large.")) }
        if method == "GET", path.contains("/devices/"), response.statusCode == 200 {
            guard let etag = response.value(forHTTPHeaderField: "ETag"), etag.count == 64 else { throw URLError(.badServerResponse) }
            etags[path] = etag
        }
        return (data, response.statusCode)
    }
    public func makeLink(_ identities: [CloudLibraryIdentity]) async throws -> String {
        try Self.validate(identities)
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let bytes = SymmetricKey(size: .bits128).withUnsafeBytes { Array($0) }
        // Twelve random characters give 60 bits. Domain-separated hashes prevent
        // the server's lookup digest from decrypting the transferred private key.
        let code = String(bytes.prefix(12).map { alphabet[Int($0) % alphabet.count] })
        let digest = Self.linkLookup(code)
        let sealed = try AES.GCM.seal(JSONEncoder().encode(identities), using: Self.linkKey(code)).combined!
        let payload = try JSONEncoder().encode(Link(code: digest.map { String(format: "%02x", $0) }.joined(), payload: sealed.base64EncodedString()))
        _ = try await request("/v1/links", method: "POST", body: payload)
        return code
    }
    private struct Link: Codable { let code: String; let payload: String }
    nonisolated static func linkLookup(_ code: String) -> SHA256.Digest { SHA256.hash(data: Data(("UL-Link-Lookup-v1:" + code).utf8)) }
    nonisolated static func linkKey(_ code: String) -> SymmetricKey { SymmetricKey(data: SHA256.hash(data: Data(("UL-Link-Key-v1:" + code).utf8))) }
    public static func cleanCode(_ input: String) -> String { input.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) } }
    public func redeemLink(_ input: String) async throws -> [CloudLibraryIdentity] {
        let code = Self.cleanCode(input)
        guard code.count == 12 else { throw SequelDataError.invalid(L10n.text("Enter the 12-character code.")) }
        let digest = Self.linkLookup(code)
        let (data, _) = try await request("/v1/links/" + digest.map { String(format: "%02x", $0) }.joined(), method: "POST")
        let link = try JSONDecoder().decode(Link.self, from: data)
        guard let sealed = Data(base64Encoded: link.payload), sealed.count <= 16384 else { throw SequelDataError.invalid("Invalid device link.") }
        let opened = try AES.GCM.open(.init(combined: sealed), using: Self.linkKey(code))
        let identities = try JSONDecoder().decode([CloudLibraryIdentity].self, from: opened)
        try Self.validate(identities); guard !identities.isEmpty else { throw SequelDataError.invalid(L10n.text("The library key is missing.")) }
        return identities
    }
}
