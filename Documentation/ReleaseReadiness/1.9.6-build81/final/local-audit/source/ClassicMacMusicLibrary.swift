import Foundation

/// Build-time renders of the Macintosh SONG sequences and their INST samples.
public struct ClassicMacMusicLibrary: Sendable {
    public let root: URL
    public let songCount: Int

    private struct Manifest: Decodable {
        struct Song: Decodable {
            let path: String
            let frames: Int
            let sampleRate: Int
        }
        let version: Int
        let songs: [Song]
    }

    public static let seasonal = ["jangle", "rudy", "frosto", "re-jangle"]
    public static var requiredPaths: Set<String> {
        Set((LevelMusicSelection.classic + ["awesome", "beasti", "beastii", "menace"])
            .map { "classic/\($0).m4a" }
            + (1...6).map { "ohno/tune\($0).m4a" }
            + seasonal.map { "xmas/\($0).m4a" })
    }

    /// Offer the source only when its complete, prepared bank is installed.
    public init?(root: URL) {
        guard let data = try? Data(contentsOf: root.appendingPathComponent("manifest.json")),
            let manifest = try? JSONDecoder().decode(Manifest.self, from: data),
            manifest.version == 1, manifest.songs.count == Self.requiredPaths.count,
            Set(manifest.songs.map(\.path)) == Self.requiredPaths,
            manifest.songs.allSatisfy({ $0.frames > 0 && $0.sampleRate == 22050
                && FileManager.default.isReadableFile(atPath: root.appendingPathComponent($0.path).path) })
        else { return nil }
        self.root = root
        songCount = manifest.songs.count
    }

    /// The Mac seasonal bank includes Frosto and Re-Jangle.
    /// Keep its selected cycle separate from the Amiga's three compositions.
    public func track(index: Int, levelTitle: String, title: ClassicTitle?) -> URL? {
        let family: String
        let name: String
        switch title {
        case .xmasLemmings1991, .xmasLemmings1992, .holidayLemmings1993, .holidayLemmings1994:
            family = "xmas"
            name = Self.seasonal[max(0, index) % Self.seasonal.count]
        case .ohNoMoreLemmings:
            family = "ohno"
            name = LevelMusicSelection.track(index: index, title: levelTitle, holiday: false, ohNo: true)
        default:
            family = "classic"
            name = LevelMusicSelection.track(index: index, title: levelTitle, holiday: false, ohNo: false).lowercased()
        }
        let path = "\(family)/\(name).m4a"
        guard Self.requiredPaths.contains(path) else { return nil }
        let url = root.appendingPathComponent(path)
        return FileManager.default.isReadableFile(atPath: url.path) ? url : nil
    }
}
