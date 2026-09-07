import Foundation

/// Finds the ground set a fan level asks for by name.
///
/// A classic level record names its ground set by number, but the text levels
/// the fan packs ship name it in words: `style = Crystal`. The numbers differ
/// between releases, so a name has to say both which release the set belongs to
/// and which slot it sits in.
///
/// The names below are the ones the level editors write and the ones the
/// community uses. They are not stored anywhere in the game data, so this table
/// is convention rather than something read off a disk. A pack that ships its
/// own ground files overrides all of it.
public struct ClassicStyleResolver: Sendable {
    /// Which release a ground set belongs to.
    public enum Release: String, Sendable, CaseIterable {
        case lemmings
        case ohNoMore
        case holiday

        /// Folder names under the ports tree that hold this release's data,
        /// most preferred first.
        public var folders: [String] {
            switch self {
            case .lemmings: ["lemmings_dos_1991-07-30"]
            case .ohNoMore: ["oh_no_more_lemmings_dos-1991-11-14_2232"]
            case .holiday: ["xmas_dos_XmasLemmingsV1.9", "xmas_dos_XmasLemmingsV1.9a1"]
            }
        }
    }

    /// Where a named style lives.
    public struct Location: Sendable, Equatable {
        public let release: Release
        /// The `GROUNDxO.DAT` slot, counting from zero.
        public let index: Int
    }

    /// The style names the fan packs use, lowercased.
    ///
    /// `Special` is not a ground set. A level using it draws its picture from a
    /// `VGASPEC` file instead, so it resolves to no ground set on purpose.
    public static let knownStyles: [String: Location] = [
        "dirt": Location(release: .lemmings, index: 0),
        "fire": Location(release: .lemmings, index: 1),
        "marble": Location(release: .lemmings, index: 2),
        "pillar": Location(release: .lemmings, index: 3),
        "crystal": Location(release: .lemmings, index: 4),
        "brick": Location(release: .ohNoMore, index: 0),
        "rock": Location(release: .ohNoMore, index: 1),
        "snow": Location(release: .ohNoMore, index: 2),
        "bubble": Location(release: .ohNoMore, index: 3),
        "xmas": Location(release: .holiday, index: 0),
        "christmas": Location(release: .holiday, index: 0),
    ]

    /// What happened when a style was looked up.
    public enum Resolution: Sendable, Equatable {
        /// The set was found, and here is the folder and slot to load it from.
        case found(directory: URL, index: Int)
        /// The pack ships this set itself.
        case packSupplied(directory: URL, index: Int)
        /// The name is known but the release's data is not installed.
        case notInstalled(Location)
        /// The level draws from a special graphic rather than a ground set.
        case specialGraphic
        /// The name is not one this resolver knows.
        case unknown(String)
    }

    public let portsRoot: URL
    /// A folder belonging to the pack, searched before the shipped releases.
    public let packRoot: URL?

    public init(portsRoot: URL, packRoot: URL? = nil) {
        self.portsRoot = portsRoot
        self.packRoot = packRoot
    }

    /// Looks a style name up, ignoring case and surrounding space.
    public func resolve(styleNamed name: String) -> Resolution {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if key == "special" { return .specialGraphic }
        guard let location = Self.knownStyles[key] else { return .unknown(name) }

        // A pack that ships ground files uses them, whatever the name means
        // elsewhere. Fan packs often replace a set while keeping its name.
        if let packRoot, groundFileExists(in: packRoot, index: location.index) {
            return .packSupplied(directory: packRoot, index: location.index)
        }
        for folder in location.release.folders {
            let directory = portsRoot.appendingPathComponent(folder, isDirectory: true)
            if groundFileExists(in: directory, index: location.index) {
                return .found(directory: directory, index: location.index)
            }
        }
        return .notInstalled(location)
    }

    /// Whether a folder holds the ground file for a slot.
    ///
    /// Both spellings turn up, because the fan packs are not consistent about
    /// case and some were made on case-sensitive systems.
    private func groundFileExists(in directory: URL, index: Int) -> Bool {
        let manager = FileManager.default
        for name in ["GROUND\(index)O.DAT", "ground\(index)o.dat"] {
            if manager.fileExists(atPath: directory.appendingPathComponent(name).path) {
                return true
            }
        }
        return false
    }

    /// Loads the ground set a name refers to, or reports why it could not.
    public func groundSet(styleNamed name: String) throws -> ClassicGroundSet? {
        switch resolve(styleNamed: name) {
        case let .found(directory, index), let .packSupplied(directory, index):
            return try ClassicGroundSet.load(style: index, from: directory)
        case .specialGraphic, .notInstalled, .unknown:
            return nil
        }
    }
}
