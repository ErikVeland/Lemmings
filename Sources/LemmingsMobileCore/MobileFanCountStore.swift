import Foundation
import LemmingsAppCore
import NxlvKit

/// Disposable pack metadata lives outside the bundle and never changes a saved level reference.
public actor MobileFanCountStore {
    private struct Entry: Codable {
        let bytes: Int
        let modified: TimeInterval
        let count: Int
    }
    private let file: URL
    private var measured: [String: Entry]

    public init(storage: AppStorage = .current()) {
        file = storage.applicationSupport.appendingPathComponent("FanCounts/levels.v1.json")
        measured = (try? Data(contentsOf: file)).flatMap {
            try? JSONDecoder().decode([String: Entry].self, from: $0)
        } ?? [:]
    }

    public func measure(fanFolders: [URL], progress: @Sendable ([String: Int]) async -> Void = { _ in }) async throws -> [String: Int] {
        var result: [String: Int] = [:]
        var visited = Set<String>()
        for folder in fanFolders {
            try Task.checkCancellation()
            let files = (try? FileManager.default.contentsOfDirectory(at: folder,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles])) ?? []
            for url in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where url.pathExtension.lowercased() == "zip" {
                try Task.checkCancellation()
                let identity = ClassicFanPack.catalogueID(url)
                guard visited.insert(identity).inserted,
                      let info = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]),
                      info.isRegularFile == true, let bytes = info.fileSize, let date = info.contentModificationDate else { continue }
                let path = url.standardizedFileURL.path
                let cached = measured[path]
                let count: Int
                if let cached, cached.bytes == bytes, cached.modified == date.timeIntervalSince1970 { count = cached.count }
                else {
                    guard let pack = try? ClassicFanPack(url: url) else { continue }
                    try Task.checkCancellation()
                    count = pack.entries().count
                    try Task.checkCancellation()
                    measured[path] = Entry(bytes: bytes, modified: date.timeIntervalSince1970, count: count)
                    try save()
                }
                result[url.lastPathComponent] = count
                if result.count.isMultiple(of: 25) { await progress(result) }
            }
        }
        try Task.checkCancellation()
        await progress(result)
        return result
    }

    private func save() throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(measured).write(to: file, options: .atomic)
    }
}
