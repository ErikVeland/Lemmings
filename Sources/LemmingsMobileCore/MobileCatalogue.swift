import Foundation
import NxlvKit

/// A group of packs the player picks from on the home page.
public enum MobileFamily: String, CaseIterable, Codable, Sendable {
    case classic
    case ohNo
    case holiday
    case ohYes
    case fan

    public var title: String {
        switch self {
        case .classic: return L10n.text("Classic Lemmings")
        case .ohNo: return L10n.text("Oh No! More Lemmings")
        case .holiday: return L10n.text("Holiday Lemmings")
        case .ohYes: return L10n.text("Oh Yes! More Lemmings")
        case .fan: return L10n.text("Fan Lemmings")
        }
    }
}

/// One playable collection of levels: an official release or a fan pack.
public struct MobileContentPack: Equatable, Sendable {
    public enum Source: Equatable, Sendable {
        /// A stock release folder under the ports root.
        case release(folder: String, title: ClassicTitle)
        case fan(file: URL)
    }

    /// Stable across launches and across the folder a pack happens to live in.
    public let id: String
    public let family: MobileFamily
    public let title: String
    public let source: Source
    /// Known without opening the pack. Nil when it has not been measured.
    public let levelCount: Int?
}

/// Lists every pack the app can play and opens them on demand.
///
/// Official releases come from small stock folders. Fan packs come from any
/// number of folders, such as the bundled set, downloads and player imports.
public final class MobileCatalogue {
    private static let releases: [(family: MobileFamily, title: ClassicTitle, folder: String, count: Int)] = [
        (.classic, .lemmings, "lemmings_dos_1991-07-30", 120),
        (.ohNo, .ohNoMoreLemmings, "oh_no_more_lemmings_dos-1991-11-14_2232", 100),
        (.holiday, .xmasLemmings1991, "xmas_dos_XmasLemmingsV1.9", 4),
        (.holiday, .xmasLemmings1992, "xmas_dos_XmasLemmingsV1.9a1", 4),
        (.holiday, .holidayLemmings1993, "holiday_native_1993", 32),
        (.holiday, .holidayLemmings1994, "holiday_native_1994", 32),
        (.ohYes, .ohYesMoreLemmings, "amiga_extracted", 60),
    ]

    public let portsRoot: URL
    public let fanFolders: [URL]
    private var measuredCounts: [String: Int]
    private var opened: [(id: String, library: any MobileGameLibrary)] = []

    /// - Parameters:
    ///   - portsRoot: Holds the stock release folders.
    ///   - fanFolders: Folders of fan pack ZIPs, most preferred first. A folder may hold a
    ///     `level-counts.json` that maps file names to level counts.
    public init(portsRoot: URL, fanFolders: [URL] = []) {
        self.portsRoot = portsRoot
        self.fanFolders = fanFolders
        var counts: [String: Int] = [:]
        for folder in fanFolders {
            guard let data = try? Data(contentsOf: folder.appendingPathComponent("level-counts.json")),
                  let index = try? JSONDecoder().decode([String: Int].self, from: data) else { continue }
            for (name, count) in index where count >= 0 && counts[name] == nil { counts[name] = count }
        }
        measuredCounts = counts
    }

    public func updateMeasuredCounts(_ counts: [String: Int]) { measuredCounts.merge(counts) { _, measured in measured } }

    // MARK: - Packs

    /// Families that have at least one pack present, in display order.
    public var families: [MobileFamily] {
        MobileFamily.allCases.filter { !packs(in: $0).isEmpty }
    }

    public func packs(in family: MobileFamily) -> [MobileContentPack] {
        switch family {
        case .classic, .ohNo, .holiday, .ohYes:
            return Self.releases.filter { $0.family == family }.compactMap { release in
                let folder = portsRoot.appendingPathComponent(release.folder)
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory),
                      isDirectory.boolValue else { return nil }
                return MobileContentPack(id: "release/" + release.title.rawValue, family: family,
                                         title: release.title.displayName,
                                         source: .release(folder: release.folder, title: release.title),
                                         levelCount: release.count)
            }
        case .fan:
            return fanFiles().map { file in
                MobileContentPack(id: ClassicFanPack.catalogueID(file), family: .fan,
                                  title: ClassicFanPack.displayName(of: file), source: .fan(file: file),
                                  levelCount: measuredCounts[file.lastPathComponent])
            }
        }
    }

    public func pack(id: String) -> MobileContentPack? {
        if id.hasPrefix("release/") {
            return MobileFamily.allCases.lazy.filter { $0 != .fan }.flatMap { self.packs(in: $0) }.first { $0.id == id }
        }
        return packs(in: .fan).first { $0.id == id }
    }

    /// The pack a saved level identifier belongs to.
    public func pack(forLevelIdentifier identifier: String) -> MobileContentPack? {
        let parts = identifier.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        if parts.first == "fan", parts.count > 1 { return pack(id: parts[1]) }
        // Official identifiers start with the release name: "lemmings-LEVEL-120/Fun/1".
        guard let key = parts.first?.split(separator: "-").first,
              let title = ClassicTitle(rawValue: String(key)) else { return nil }
        return pack(id: "release/" + title.rawValue)
    }

    private func fanFiles() -> [URL] {
        var result: [String: URL] = [:]
        for folder in fanFolders {
            let files = (try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])) ?? []
            for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            where file.pathExtension.lowercased() == "zip"
                && (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                // The earlier folder wins, so a bundled pack is never replaced by a download.
                let key = ClassicFanPack.catalogueID(file)
                if result[key] == nil { result[key] = file }
            }
        }
        return result.values.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Every installed fan level, for a run that visits each once. Reading all packs takes a few seconds,
    /// so call it away from the main thread.
    public func fanPool() -> (entries: [MobileFavourites.Entry], packs: Int) {
        var pool: [MobileFavourites.Entry] = []
        var packs = 0
        for pack in self.packs(in: .fan) {
            guard case let .fan(file) = pack.source, let reader = try? ClassicFanPack(url: file) else { continue }
            let found = reader.entries()
            guard !found.isEmpty else { continue }
            packs += 1
            pool += found.map { MobileFavourites.Entry(pack: pack.id, level: $0.key, title: $0.label) }
        }
        return (pool, packs)
    }

    // MARK: - Opening

    /// Opens a pack. The last few stay in memory, so paging back and forth is instant.
    public func library(for pack: MobileContentPack) throws -> any MobileGameLibrary {
        if let hit = opened.first(where: { $0.id == pack.id }) { return hit.library }
        let library: any MobileGameLibrary
        switch pack.source {
        case let .release(_, title) where title == .ohYesMoreLemmings:
            library = try ClassicOhYesMobileLibrary(portsRoot: portsRoot)
        case let .release(folder, _):
            library = try ClassicMobileLibrary(directory: portsRoot.appendingPathComponent(folder))
        case let .fan(file):
            library = try ClassicFanMobileLibrary(packURL: file, portsRoot: portsRoot)
        }
        opened.append((pack.id, library))
        if opened.count > 3 { opened.removeFirst() }
        return library
    }
}
