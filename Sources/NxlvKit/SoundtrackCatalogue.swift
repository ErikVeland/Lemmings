import Foundation

/// Composition identity is separate from its port, source fidelity and arrangement.
public struct SoundtrackCatalogue: Codable, Sendable {
    public struct Variant: Codable, Equatable, Sendable {
        public let id: String
        public let path: String
        public let port: String
        public let quality: String
        public let remix: String
        public let confidence: String
        public let sourcePath: String
    }
    public struct Track: Codable, Sendable {
        public let id: String
        public let game: String
        public let title: String
        public let role: String
        public let variants: [Variant]
    }
    public let schemaVersion: Int
    public let tracks: [Track]

    public init(data: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: data)
        guard schemaVersion == 1 else { throw CatalogueError.unsupportedVersion }
        let paths = tracks.flatMap(\.variants).map(\.path)
        guard Set(tracks.map(\.id)).count == tracks.count,
              Set(paths).count == paths.count,
              Set(tracks.flatMap(\.variants).map(\.id)).count == paths.count,
              paths.allSatisfy({ !$0.hasPrefix("/") && !$0.split(separator: "/").contains("..") })
        else { throw CatalogueError.invalidEntries }
    }
    private enum CatalogueError: Error { case unsupportedVersion, invalidEntries }

    public static func load(at root: URL) -> Self? {
        guard let data = try? Data(contentsOf: root.appendingPathComponent("catalogue.json")) else { return nil }
        return try? Self(data: data)
    }

    public func track(id: String) -> Track? { tracks.first { $0.id == id } }

    public func entry(path: String) -> (track: Track, variant: Variant)? {
        for track in tracks {
            if let variant = track.variants.first(where: { $0.path == path }) { return (track, variant) }
        }
        return nil
    }

    /// First occurrence uses the original preferred port. Later score cycles visit
    /// other versions of this composition. Retries never advance the cycle.
    public func select(trackID: String, cycle: Int, preferredPort: String = "amiga",
                       availablePaths: Set<String>, includeAlternates: Bool = true) -> Variant? {
        guard let track = track(id: trackID), track.role != "unverified" else { return nil }
        let variants = track.variants.filter {
            $0.confidence == "documented" && availablePaths.contains($0.path)
        }.sorted { rank($0, preferredPort: preferredPort) < rank($1, preferredPort: preferredPort) }
        guard !variants.isEmpty else { return nil }
        // Menus, medals, endings and bonus tracks require explicit events.
        let canTravel = ["level", "special", "seasonal"].contains(track.role) && includeAlternates
        guard canTravel else { return variants[0] }
        // Introduce a port, a composer recording and a remix early enough to
        // hear them within a campaign. Then visit the remaining versions.
        var journey: [Variant] = []
        func append(_ variant: Variant?) {
            if let variant, !journey.contains(where: { $0.id == variant.id }) { journey.append(variant) }
        }
        append(variants.first)
        append(variants.first { $0.port != preferredPort && $0.remix == "original" })
        append(variants.first { $0.quality == "composer-recording" && $0.remix == "original" })
        append(variants.first { $0.remix != "original" })
        for variant in variants { append(variant) }
        return journey[max(0, cycle) % journey.count]
    }

    /// Generic results may use only an identified result cue from the current
    /// game and port. Endings, medals and special-level music are not win jingles.
    public func result(won: Bool, currentPath: String, availablePaths: Set<String>) -> Variant? {
        guard let current = entry(path: currentPath) else { return nil }
        return tracks.filter { $0.game == current.track.game && $0.role == (won ? "victory" : "failure") }
            .flatMap(\.variants)
            .filter { $0.port == current.variant.port && $0.remix == "original" &&
                $0.confidence == "documented" && availablePaths.contains($0.path) }
            .sorted { $0.id < $1.id }.first
    }

    private func rank(_ variant: Variant, preferredPort: String) -> String {
        let ports = [preferredPort, "amiga", "dos-opl2", "tandy", "x68000", "fm-towns", "pc-98", "lynx", "archimedes", "nes", "snes", "master-system", "game-boy", "spectrum", "arcade", "mega-drive", "dos-opl3"]
        let port = ports.firstIndex(of: variant.port) ?? ports.count
        let quality = ["native-module", "chip-render", "composer-recording", "lossy-source"].firstIndex(of: variant.quality) ?? 4
        // Remixes are a later chapter, not an upgrade over the original hardware.
        return String(format: "%d-%02d-%d-", variant.remix == "original" ? 0 : 1, port, quality) + variant.remix + "-" + variant.id
    }
}
