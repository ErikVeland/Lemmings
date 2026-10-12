import CryptoKit
import Foundation
import NxlvKit

/// The Mac catalogue's content revision, independent of an installation path.
public enum ClassicSourceRevision {
    public static func directory(_ root: URL, excluding extensions: Set<String> = []) -> String? {
        let root = root.resolvingSymlinksInPath().standardizedFileURL
        guard let enumerator = FileManager.default.enumerator(at: root,
            includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return nil }
        let ignored: Set<String> = ["sav", "mp4", "m4a", "wav", "ogg", "mp3", "mod", "mid", "png", "jpg"]
        var entries: [String: String] = [:]
        for case let file as URL in enumerator {
            if Task.isCancelled { return nil }
            guard !ignored.union(extensions).contains(file.pathExtension.lowercased()),
                  (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
                  let bytes = try? Data(contentsOf: file) else { continue }
            entries["/" + file.pathComponents.suffix(enumerator.level).joined(separator: "/")] = hash(bytes)
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard !entries.isEmpty, let bytes = try? encoder.encode(entries) else { return nil }
        return hash(bytes)
    }
    /// Desktop bundles omit DOS executables and launch scripts from stock sources.
    public static func bundledCampaign(_ title: ClassicTitle?, root: URL) -> String? {
        guard title == .ohYesMoreLemmings else { return directory(root, excluding: ["exe", "bat"]) }
        let folders = Set(AmigaVersusCampaign.sources.map { "amiga_extracted/" + $0.family }
            + [PortExclusivePack.sunsoftFolder, ClassicStyleResolver.Release.lemmings.folders[0],
               ClassicStyleResolver.Release.ohNoMore.folders[0]])
        let revisions = Dictionary(uniqueKeysWithValues: folders.map { ($0, directory(root.appendingPathComponent($0), excluding: ["exe", "bat"]) ?? "missing") })
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let bytes = try? encoder.encode(revisions) else { return nil }
        let scoped = hash(bytes)
        return scoped == "843c764dea3913f6e03c46d08b0fa53761dcc48c65b6628bbe7f0d01204df9ad"
            ? "fc020d72e88706953d4737e1b5fa09f5b653d7a70e4e1c1fa1cfa5546a24a908" : scoped
    }
    public static func campaign(_ title: ClassicTitle?, root: URL) -> String? {
        guard title == .ohYesMoreLemmings else { return directory(root) }
        let folders = Set(AmigaVersusCampaign.sources.map { "amiga_extracted/" + $0.family }
            + [PortExclusivePack.sunsoftFolder, ClassicStyleResolver.Release.lemmings.folders[0],
               ClassicStyleResolver.Release.ohNoMore.folders[0]])
        let revisions = Dictionary(uniqueKeysWithValues: folders.map { ($0, directory(root.appendingPathComponent($0)) ?? "missing") })
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let bytes = try? encoder.encode(revisions) else { return nil }
        let scoped = hash(bytes)
        return scoped == "843c764dea3913f6e03c46d08b0fa53761dcc48c65b6628bbe7f0d01204df9ad"
            ? "fc020d72e88706953d4737e1b5fa09f5b653d7a70e4e1c1fa1cfa5546a24a908" : scoped
    }
    private static func hash(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}
