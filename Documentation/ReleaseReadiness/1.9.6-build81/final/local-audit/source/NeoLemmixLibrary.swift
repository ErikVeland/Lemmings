import Foundation

/// Combines the bundled NeoLemmix packs with a player's own folder.
///
/// Sources are in priority order. A later source cannot replace a pack ID that
/// an earlier source supplied. Each level uses the first styles root that has
/// every style it names, trying its own source's styles first. This check reads
/// only the level. The full piece resolution runs when the level starts.
public enum NeoLemmixLibrary {
    public struct Source: Sendable, Equatable {
        public let levelsRoot: URL
        public let stylesRoot: URL?

        public init(levelsRoot: URL, stylesRoot: URL?) {
            self.levelsRoot = levelsRoot
            self.stylesRoot = stylesRoot
        }
    }

    public struct Pack: Sendable, Equatable {
        public let pack: NeoLemmixPack
        /// Level ID to styles root. A level without an entry cannot start.
        public let stylesRoots: [String: URL]

        public func stylesRoot(for level: NeoLemmixPackLevel) -> URL? {
            stylesRoots[level.levelID]
        }
    }

    public static func discover(_ sources: [Source]) -> [Pack] {
        var names: [URL: Set<String>] = [:]
        return packs(in: sources).map { pack, candidates in
            let indexed = candidates.map { root in
                (root, names[root] ?? { names[root] = styleNames(in: root); return names[root]! }())
            }
            var roots: [String: URL] = [:]
            for level in pack.levels {
                roots[level.levelID] = readLevel(level.url).flatMap { stylesRoot(for: $0, in: indexed) }
            }
            return Pack(pack: pack, stylesRoots: roots)
        }
    }

    /// Finds a saved run's level by its stable IDs and resolves only its styles.
    public static func locate(packID: String, levelID: String, in sources: [Source])
        -> (level: NeoLemmixPackLevel, stylesRoot: URL?)? {
        for (pack, candidates) in packs(in: sources) where pack.id == packID {
            guard let level = pack.levels.first(where: { $0.levelID == levelID }) else { return nil }
            return (level, stylesRoot(for: level.url, candidates: candidates))
        }
        return nil
    }

    /// Packs in source order without duplicate IDs, each with its styles candidates.
    private static func packs(in sources: [Source]) -> [(NeoLemmixPack, [URL])] {
        let allStyles = sources.compactMap(\.stylesRoot)
        var seen: Set<String> = []
        var result: [(NeoLemmixPack, [URL])] = []
        for source in sources {
            guard let packs = try? NeoLemmixPackLibrary.discover(in: source.levelsRoot) else { continue }
            let candidates = ([source.stylesRoot].compactMap { $0 } + allStyles).uniqued()
            for pack in packs where seen.insert(pack.id).inserted {
                result.append((pack, candidates))
            }
        }
        return result
    }

    /// The first candidate that has every style the level names.
    public static func stylesRoot(for levelURL: URL, candidates: [URL]) -> URL? {
        guard let level = readLevel(levelURL) else { return nil }
        return stylesRoot(for: level, in: candidates.map { ($0, styleNames(in: $0)) })
    }

    private static func stylesRoot(for level: NxlvLevel, in candidates: [(URL, Set<String>)]) -> URL? {
        let scan = level.scanStyleAssetReferences()
        guard !scan.diagnostics.contains(where: { $0.severity == .error }) else { return nil }
        let needed = Set(scan.references.map { $0.style.lowercased() })
        return candidates.first { needed.isSubset(of: $0.1) }?.0
    }

    /// Style folder names, lowercased. The resolver matches styles without case.
    private static func styleNames(in root: URL) -> Set<String> {
        let folders = (try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        return Set(folders.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }.map { $0.lastPathComponent.lowercased() })
    }

    private static func readLevel(_ url: URL) -> NxlvLevel? {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        else { return nil }
        return NxlvLevel(text: text)
    }
}

private extension Array where Element == URL {
    func uniqued() -> [URL] {
        var seen: Set<String> = []
        return filter { seen.insert($0.standardizedFileURL.path).inserted }
    }
}
