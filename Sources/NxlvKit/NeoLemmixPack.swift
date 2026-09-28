import CryptoKit
import Foundation

public enum NeoLemmixPackError: Error, Equatable, CustomStringConvertible, LocalizedError {
    case unreadable(String)
    case unsafePath(String)
    case malformedLevel(String)
    case duplicateLevelID(String)
    case duplicatePackID(String)
    case emptyPack(String)

    public var description: String {
        switch self {
        case let .unreadable(path): "NeoLemmix pack data could not be read: \(path)"
        case let .unsafePath(path): "NeoLemmix pack data contains an unsafe path: \(path)"
        case let .malformedLevel(path): "NeoLemmix level could not be decoded: \(path)"
        case let .duplicateLevelID(id): "NeoLemmix pack contains duplicate level ID \(id)."
        case let .duplicatePackID(id): "NeoLemmix library contains duplicate pack ID \(id)."
        case let .emptyPack(path): "NeoLemmix pack contains no levels: \(path)"
        }
    }

    public var errorDescription: String? { description }
}

public struct NeoLemmixPackLevel: Sendable, Equatable {
    public let url: URL
    public let relativePath: String
    public let groups: [String]
    public let title: String
    public let levelID: String
    public let sourceRevision: String

    public init(
        url: URL,
        relativePath: String,
        groups: [String],
        title: String,
        levelID: String,
        sourceRevision: String
    ) {
        self.url = url
        self.relativePath = relativePath
        self.groups = groups
        self.title = title
        self.levelID = levelID
        self.sourceRevision = sourceRevision
    }
}

public struct NeoLemmixPack: Sendable, Equatable {
    public let rootURL: URL
    public let id: String
    public let title: String
    public let author: String?
    public let sourceRevision: String
    public let levels: [NeoLemmixPackLevel]

    public init(
        rootURL: URL,
        id: String,
        title: String,
        author: String?,
        sourceRevision: String,
        levels: [NeoLemmixPackLevel]
    ) {
        self.rootURL = rootURL
        self.id = id
        self.title = title
        self.author = author
        self.sourceRevision = sourceRevision
        self.levels = levels
    }
}

/// Reads the CE `levels` tree without relying on directory enumeration order.
/// `levels.nxmi` controls group and level order when it is present.
public enum NeoLemmixPackLibrary {
    private static let maximumTextBytes = 16 * 1024 * 1024

    public static func discover(in selectedRoot: URL) throws -> [NeoLemmixPack] {
        let root = selectedRoot.resolvingSymlinksInPath().standardizedFileURL
        let manager = FileManager.default
        guard directoryExists(root) else { throw NeoLemmixPackError.unreadable(root.path) }

        let roots: [URL]
        if isPackRoot(root) {
            roots = [root]
        } else {
            roots = try manager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ).filter { directoryExists($0) && isPackRoot($0) }
              .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        }
        let packs = try roots.map(readPack)
        var packIDs: Set<String> = []
        for pack in packs where !packIDs.insert(pack.id).inserted {
            throw NeoLemmixPackError.duplicatePackID(pack.id)
        }
        return packs
    }

    private static func readPack(_ suppliedRoot: URL) throws -> NeoLemmixPack {
        let root = suppliedRoot.resolvingSymlinksInPath().standardizedFileURL
        let infoURL = root.appendingPathComponent("info.nxmi")
        let infoText = fileExists(infoURL) ? try readText(infoURL) : nil
        let info = infoText.map(NxlvParser.parse)
        let title = info?.trimmedLine("title").flatMap { $0.isEmpty ? nil : $0 }
            ?? displayName(root.lastPathComponent)
        let author = info?.line("author")

        var manifestData: [(String, Data)] = []
        var ordered: [(url: URL, groups: [String])] = []
        let manifest = root.appendingPathComponent("levels.nxmi")
        if fileExists(manifest) {
            try appendManifest(
                manifest,
                packRoot: root,
                groups: [],
                manifests: &manifestData,
                levels: &ordered
            )
        } else {
            ordered = try fallbackLevels(in: root).map { ($0, []) }
        }
        guard !ordered.isEmpty else { throw NeoLemmixPackError.emptyPack(root.path) }

        var levels: [NeoLemmixPackLevel] = []
        var levelIDs: Set<String> = []
        var revisionData = Data()
        for manifest in manifestData.sorted(by: { $0.0 < $1.0 }) {
            revisionData.append(Data(manifest.0.utf8))
            revisionData.append(0)
            revisionData.append(manifest.1)
        }
        if let infoText {
            revisionData.append(Data("info.nxmi".utf8))
            revisionData.append(0)
            revisionData.append(Data(infoText.utf8))
        }

        for item in ordered {
            let relativePath = try relativePath(of: item.url, under: root)
            let data = try readData(item.url)
            guard let text = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .isoLatin1),
                  let level = NxlvLevel(text: text) else {
                throw NeoLemmixPackError.malformedLevel(relativePath)
            }
            let stableID = level.id.map { String(format: "x%016llX", $0) }
                ?? "path:" + relativePath.lowercased()
            guard levelIDs.insert(stableID).inserted else {
                throw NeoLemmixPackError.duplicateLevelID(stableID)
            }
            let sourceRevision = digest(data)
            revisionData.append(Data(relativePath.utf8))
            revisionData.append(0)
            revisionData.append(Data(sourceRevision.utf8))
            levels.append(NeoLemmixPackLevel(
                url: item.url,
                relativePath: relativePath,
                groups: item.groups,
                title: level.title,
                levelID: stableID,
                sourceRevision: sourceRevision
            ))
        }

        let identitySource = [title, author ?? ""].joined(separator: "\n").lowercased()
        return NeoLemmixPack(
            rootURL: root,
            id: "neolemmix:" + String(digest(Data(identitySource.utf8)).prefix(24)),
            title: title,
            author: author,
            sourceRevision: digest(revisionData),
            levels: levels
        )
    }

    private static func appendManifest(
        _ suppliedManifest: URL,
        packRoot: URL,
        groups: [String],
        manifests: inout [(String, Data)],
        levels: inout [(url: URL, groups: [String])]
    ) throws {
        let manifest = suppliedManifest.resolvingSymlinksInPath().standardizedFileURL
        let relativeManifest = try relativePath(of: manifest, under: packRoot)
        let data = try readData(manifest)
        manifests.append((relativeManifest, data))
        guard let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else {
            throw NeoLemmixPackError.unreadable(relativeManifest)
        }
        let document = NxlvParser.parse(text)
        for entry in document.entries {
            switch entry {
            case let .line(line) where line.keyword == "level":
                let url = try resolved(line.value, relativeTo: manifest.deletingLastPathComponent(), under: packRoot)
                guard url.pathExtension.caseInsensitiveCompare("nxlv") == .orderedSame,
                      fileExists(url) else { throw NeoLemmixPackError.unreadable(line.value) }
                levels.append((url, groups))
            case let .section(section) where section.keyword == "group":
                guard let folder = section.trimmedLine("folder"), !folder.isEmpty else {
                    throw NeoLemmixPackError.unreadable(relativeManifest)
                }
                let name = section.line("name").flatMap { $0.isEmpty ? nil : $0 }
                    ?? displayName(folder)
                let directory = try resolved(
                    folder,
                    relativeTo: manifest.deletingLastPathComponent(),
                    under: packRoot
                )
                try appendManifest(
                    directory.appendingPathComponent("levels.nxmi"),
                    packRoot: packRoot,
                    groups: groups + [name],
                    manifests: &manifests,
                    levels: &levels
                )
            default:
                continue
            }
        }
    }

    private static func fallbackLevels(in root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { throw NeoLemmixPackError.unreadable(root.path) }
        return enumerator.compactMap { item -> URL? in
            guard let url = item as? URL,
                  url.pathExtension.caseInsensitiveCompare("nxlv") == .orderedSame,
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                return nil
            }
            return url.resolvingSymlinksInPath().standardizedFileURL
        }.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    private static func resolved(_ path: String, relativeTo directory: URL, under root: URL) throws -> URL {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.hasPrefix("\\"), !path.contains(":") else {
            throw NeoLemmixPackError.unsafePath(path)
        }
        let url = directory.appendingPathComponent(path)
            .resolvingSymlinksInPath().standardizedFileURL
        _ = try relativePath(of: url, under: root)
        return url
    }

    private static func relativePath(of url: URL, under root: URL) throws -> String {
        let rootComponents = root.resolvingSymlinksInPath().standardizedFileURL.pathComponents
        let components = url.resolvingSymlinksInPath().standardizedFileURL.pathComponents
        guard components.count > rootComponents.count,
              components.prefix(rootComponents.count).elementsEqual(rootComponents) else {
            throw NeoLemmixPackError.unsafePath(url.path)
        }
        return components.dropFirst(rootComponents.count).joined(separator: "/")
    }

    private static func readText(_ url: URL) throws -> String {
        let data = try readData(url)
        guard let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else {
            throw NeoLemmixPackError.unreadable(url.path)
        }
        return text
    }

    private static func readData(_ url: URL) throws -> Data {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              values.isRegularFile == true,
              let size = values.fileSize,
              size <= maximumTextBytes,
              let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else {
            throw NeoLemmixPackError.unreadable(url.path)
        }
        return data
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func fileExists(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }

    private static func directoryExists(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private static func isPackRoot(_ url: URL) -> Bool {
        if fileExists(url.appendingPathComponent("levels.nxmi"))
            || fileExists(url.appendingPathComponent("info.nxmi")) { return true }
        return (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ).contains { $0.pathExtension.caseInsensitiveCompare("nxlv") == .orderedSame }) == true
    }

    private static func displayName(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: " ")
    }
}
