import Foundation

/// Local game assets copied into the app at build time. Resolution never
/// depends on the working directory or on the original source checkout.
public enum BundledGameResources {
    public static func lemmings2(in bundle: Bundle = .main) throws -> URL {
        try directory("Ports/Lemm2", requiring: ["LEVELS/LEVEL000.DAT", "STYLES/CLASSIC.DAT",
            "VLEMMS.DAT", "MASKS.DAT", "INTERN.DAT", "FONT.DAT", "PANEL.DAT", "ICONS.DAT",
            "FRONTEND/GFXIFFS/MENU.IFF", "FRONTEND/SCREENS/MENU.DAT"], in: bundle)
    }

    public static func lemmings3(in bundle: Bundle = .main) throws -> URL {
        try directory("Ports/LEM3CD", requiring: ["LEVELS/LEVEL001.DAT", "STYLES", "GRAPHICS"], in: bundle)
    }

    public static func music(_ name: String, in bundle: Bundle = .main) -> URL? {
        guard !name.contains("/"), name != ".", name != ".." else { return nil }
        return try? directory("Music/" + name, requiring: [], in: bundle)
    }

    public static func classicDirectories(in bundle: Bundle = .main) -> [URL] {
        guard let root = bundle.resourceURL?.appendingPathComponent("Ports"),
              let directories = try? FileManager.default.contentsOfDirectory(at: root,
                includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return [] }
        return directories.filter { directory in
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return false }
            return contents.contains { $0.lowercased() == "main.dat" }
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    public static func macintoshSoundImage(in bundle: Bundle = .main) -> URL? {
        guard let root = bundle.resourceURL else { return nil }
        let image = root.appendingPathComponent("Ports/lemmings_1_5_2/Lemmings_1_5_2.dsk")
        return FileManager.default.fileExists(atPath: image.path) ? image : nil
    }

    private static func directory(_ path: String, requiring files: [String], in bundle: Bundle) throws -> URL {
        guard let resources = bundle.resourceURL else {
            throw SequelDataError.invalid("This app has no embedded game resources. Rebuild the app with its game data.")
        }
        let root = resources.appendingPathComponent(path, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue,
              files.allSatisfy({ FileManager.default.fileExists(atPath: root.appendingPathComponent($0).path) }) else {
            throw SequelDataError.invalid("The app is missing embedded game data (\(path)). Rebuild the app with its game data.")
        }
        return root
    }
}
