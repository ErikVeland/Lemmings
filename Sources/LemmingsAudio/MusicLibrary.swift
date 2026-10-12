import Foundation
import NxlvKit

/// Optional soundtrack libraries and the rhythm loops that ride beside recordings.
public enum MusicLibrary {
    public static let changed = Notification.Name("MusicLibraryChanged")

    public static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Ultimate Lemmings/MusicLibraries", isDirectory: true)
    }

    public static func catalogue(at musicRoot: URL? = Bundle.main.resourceURL?.appendingPathComponent("Music")) -> MusicLibraryCatalogue? {
        guard let url = musicRoot?.appendingPathComponent("libraries.json"), let data = try? Data(contentsOf: url) else { return nil }
        return try? MusicLibraryCatalogue(data: data)
    }

    public static func installedRoots(in directory: URL = directory) -> [URL] {
        MusicLibraryStore.installedRoots(in: directory)
    }

    public static func isInstalled(_ pack: MusicLibraryCatalogue.Pack, in directory: URL = directory) -> Bool {
        MusicLibraryStore.isInstalled(pack, in: directory)
    }

    public static func hash(_ url: URL) throws -> String { try MusicLibraryStore.hash(url) }

    public static func rhythmURL(for source: URL, musicRoot: URL? = Bundle.main.resourceURL?.appendingPathComponent("Music")) -> URL? {
        for root in [musicRoot].compactMap({ $0 }) + installedRoots() {
            let prefix = root.standardizedFileURL.path + "/"
            guard source.standardizedFileURL.path.hasPrefix(prefix),
                  let data = try? Data(contentsOf: root.appendingPathComponent("rhythm.json")),
                  let catalogue = try? MusicRhythmCatalogue(data: data),
                  let entry = catalogue.variants.first(where: { $0.path == String(source.standardizedFileURL.path.dropFirst(prefix.count)) }),
                  (try? hash(source)) == entry.expectedSHA256 else { continue }
            let loop = root.appendingPathComponent(entry.loopPath)
            if (try? hash(loop)) == entry.sha256 { return loop }
        }
        return nil
    }
}
