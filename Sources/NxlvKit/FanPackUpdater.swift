import Foundation

/// Checks the public fan level catalogue and installs packs that are not on the device yet.
///
/// Requests run one at a time with a pause between them, and a fresh launch needs
/// only one small request because new packs are listed first. Nothing installed is
/// ever replaced.
public actor FanPackUpdater {
    public struct Pack: Equatable, Sendable {
        public let id: Int
        public let slug: String
        public var filename: String { String(format: "%04d", id) + "-" + slug + ".zip" }
        public var page: URL { URL(string: "https://lldb.camanis.net/levelpack/\(id)/\(slug)")! }
    }

    public struct Outcome: Sendable {
        public var added = 0
        /// Level counts of the packs added, by file name.
        public var counts: [String: Int] = [:]
        public var unavailable = false
        public var status: String {
            if added > 0 { return L10n.text("\(added) NEW \(added == 1 ? L10n.text("PACK") : L10n.text("PACKS"))") + (unavailable ? L10n.text(" · CHECK INCOMPLETE") : "") }
            return unavailable ? L10n.text("OFFLINE COLLECTION READY · CHECK UNAVAILABLE") : L10n.text("COLLECTION UP TO DATE")
        }
        public init() {}
    }

    public enum Failure: Error { case response, tooLarge, invalidCatalogue, invalidArchive }
    public typealias Fetch = @Sendable (URL, Int) async throws -> Data

    private let fetch: Fetch
    private let delay: UInt64

    public init(delay: UInt64 = 1_500_000_000, fetch: @escaping Fetch = FanPackUpdater.fetch) {
        self.fetch = fetch
        self.delay = delay
    }

    public static func fetch(_ url: URL, limit: Int) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 20)
        request.setValue(L10n.text("UltimateLemmings/0.1 (fan-pack updates; sequential requests)"), forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              response.url?.scheme == "https", response.url?.host == "lldb.camanis.net" else { throw Failure.response }
        guard response.expectedContentLength <= limit else { throw Failure.tooLarge }
        var data = Data()
        for try await byte in bytes {
            guard data.count < limit else { throw Failure.tooLarge }
            data.append(byte)
        }
        return data
    }

    public static func catalogue(_ data: Data) throws -> [Pack] {
        let html = String(decoding: data, as: UTF8.self)
        let regex = try NSRegularExpression(pattern: #"href="/levelpack/(\d+)/([A-Za-z0-9_-]+)""#)
        let text = html as NSString
        var seen = Set<Int>()
        let packs = regex.matches(in: html, range: NSRange(location: 0, length: text.length)).compactMap { match -> Pack? in
            guard let id = Int(text.substring(with: match.range(at: 1))), id > 0, id <= Int(Int32.max),
                  seen.insert(id).inserted else { return nil }
            return Pack(id: id, slug: text.substring(with: match.range(at: 2)))
        }
        guard !packs.isEmpty else { throw Failure.invalidCatalogue }
        return packs
    }

    public static func downloadURL(_ data: Data, pack: Pack) throws -> URL {
        let html = String(decoding: data, as: UTF8.self) as NSString
        let regex = try NSRegularExpression(pattern: #"href="(/levelpack/download/"# + String(pack.id) + #"/[A-Za-z0-9_-]+(?:\?i=\d+)?)""#)
        guard let match = regex.firstMatch(in: html as String, range: NSRange(location: 0, length: html.length)),
              let url = URL(string: "https://lldb.camanis.net" + html.substring(with: match.range(at: 1))) else { throw Failure.response }
        return url
    }

    /// Reads central-directory sizes before asking the level decoder to inspect an archive.
    public static func validateZIP(_ data: Data) throws {
        let bytes = [UInt8](data)
        func u16(_ p: Int) -> Int { Int(bytes[p]) | Int(bytes[p + 1]) << 8 }
        func u32(_ p: Int) -> Int { u16(p) | u16(p + 2) << 16 }
        guard bytes.count >= 22, bytes.count <= 8 * 1024 * 1024 else { throw Failure.invalidArchive }
        let lower = max(0, bytes.count - 65557)
        guard let end = stride(from: bytes.count - 22, through: lower, by: -1).first(where: {
            u32($0) == 0x06054b50 && $0 + 22 + u16($0 + 20) == bytes.count
        }), u16(end + 4) == 0, u16(end + 6) == 0 else { throw Failure.invalidArchive }
        let count = u16(end + 10)
        guard count > 0, count <= 4000, u16(end + 8) == count else { throw Failure.invalidArchive }
        var offset = u32(end + 16), total = 0
        guard offset < end, u32(end + 12) == end - offset else { throw Failure.invalidArchive }
        for _ in 0..<count {
            guard offset + 46 <= end, u32(offset) == 0x02014b50, u16(offset + 8) & 1 == 0 else { throw Failure.invalidArchive }
            let size = u32(offset + 24)
            total += size
            guard size <= 4 * 1024 * 1024, total <= 64 * 1024 * 1024 else { throw Failure.tooLarge }
            offset += 46 + u16(offset + 28) + u16(offset + 30) + u16(offset + 32)
            guard offset <= end else { throw Failure.invalidArchive }
        }
        guard offset == end else { throw Failure.invalidArchive }
    }

    /// Looks for packs not in `existing` and installs them into `destination`.
    public func check(existing: [URL], destination: URL) async -> Outcome {
        var outcome = Outcome()
        var known = Set(existing.compactMap(ClassicFanPack.packID))
        // A page holding only installed packs ends the catch-up scan. Fresh releases appear first.
        do {
            for page in 1...100 {
                try Task.checkCancellation()
                if page > 1 { try await Task.sleep(nanoseconds: delay) }
                let url = URL(string: "https://lldb.camanis.net/levelpack/list?sort=-date&page=\(page)")!
                let data = try await fetch(url, 1024 * 1024)
                let packs = try Self.catalogue(data)
                let missing = packs.filter { !known.contains($0.id) }
                if missing.isEmpty { break }
                for pack in missing {
                    try Task.checkCancellation()
                    do {
                        try await Task.sleep(nanoseconds: delay)
                        let pageData = try await fetch(pack.page, 1024 * 1024)
                        let download = try Self.downloadURL(pageData, pack: pack)
                        try await Task.sleep(nanoseconds: delay)
                        let archive = try await fetch(download, 8 * 1024 * 1024)
                        try Self.validateZIP(archive)
                        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                        let temporary = destination.appendingPathComponent(".incoming-\(UUID().uuidString).zip")
                        defer { try? FileManager.default.removeItem(at: temporary) }
                        try archive.write(to: temporary, options: .atomic)
                        let count = (try? ClassicFanPack(url: temporary).entries().count) ?? 0
                        guard count > 0 else { throw Failure.invalidArchive }
                        let target = destination.appendingPathComponent(pack.filename)
                        // Never replace installed content or a file another launch just added.
                        guard !FileManager.default.fileExists(atPath: target.path) else { known.insert(pack.id); continue }
                        try FileManager.default.moveItem(at: temporary, to: target)
                        known.insert(pack.id)
                        outcome.added += 1
                        outcome.counts[pack.filename] = count
                    } catch is CancellationError { throw CancellationError() }
                    catch { outcome.unavailable = true }
                }
                if !String(decoding: data, as: UTF8.self).contains("rel=\"next\"") { break }
                if page == 100 { outcome.unavailable = true }
            }
        } catch { outcome.unavailable = true }
        return outcome
    }
}
