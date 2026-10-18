import Foundation
import NxlvKit

/// Scenery identity is separate from checkpoints and never restores a live attempt.
public struct MobileHomeBackdropReference: Codable, Equatable, Sendable {
    public let kind: MobileGameDataKind
    public let pack: String?
    public let level: String
    public init(kind: MobileGameDataKind, pack: String? = nil, level: String) {
        self.kind = kind; self.pack = pack; self.level = level
    }
}

public struct MobileHomeBackdrop: Sendable {
    public let frame: MobilePixelFrame
    public let start: MobilePoint
    public let goal: MobilePoint
    public internal(set) var title: String?
    public init(session: any MobileGameSession) throws {
        frame = try session.render(highlight: nil)
        let scale = session.renderScale
        let opening = session.engineIdentifier.hasPrefix("classic")
            ? MobilePoint(x: session.initialCameraOrigin.x + 160, y: session.initialCameraOrigin.y + 80)
            : session.entrancePoint
        start = .init(x: opening.x * scale, y: opening.y * scale)
        goal = .init(x: session.goalPoint.x * scale, y: session.goalPoint.y * scale)
    }
}

/// A worker opens scenery without recording visits, applying a checkpoint or ticking physics.
public actor MobileHomeBackdropLoader {
    public init() {}

    public func load(preferred: MobileHomeBackdropReference?, recent: MobileFavourites.Entry?,
                     ports: URL?, fanFolders: [URL], native: [MobileGameDataKind: URL],
                     classicDirectory: URL?, storage: MobileStorage, settings: ClassicSettings,
                     neoLibrary: (@Sendable (URL, MobileStorage) throws -> any MobileGameLibrary)? = nil) throws -> MobileHomeBackdrop? {
        let catalogue = ports.map { MobileCatalogue(portsRoot: $0, fanFolders: fanFolders) }
        func open(_ reference: MobileHomeBackdropReference) throws -> any MobileGameLibrary {
            switch reference.kind {
            case .classic:
                if let id = reference.pack, let pack = catalogue?.pack(id: id), let catalogue {
                    return try catalogue.library(for: pack)
                }
                guard reference.pack == nil, let classicDirectory else { throw MobileSessionError.changedLevel }
                return try ClassicMobileLibrary(directory: classicDirectory)
            case .lemmings2:
                guard let root = native[.lemmings2] else { throw MobileSessionError.changedLevel }
                return try Lemmings2MobileLibrary(directory: root, storage: storage)
            case .lemmings3:
                guard let root = native[.lemmings3] else { throw MobileSessionError.changedLevel }
                return try Lemmings3MobileLibrary(directory: root, storage: storage)
            case .neoLemmix:
                guard let root = native[.neoLemmix], let neoLibrary else { throw MobileSessionError.changedLevel }
                return try neoLibrary(root, storage)
            }
        }
        func scenery(_ library: any MobileGameLibrary, index: Int) throws -> MobileHomeBackdrop {
            try Task.checkCancellation()
            let session = try library.loadLevel(at: index).session
            session.applySettings(settings)
            try Task.checkCancellation()
            var result = try MobileHomeBackdrop(session: session)
            result.title = library.levels.indices.contains(index) ? library.levels[index].title : nil
            return result
        }
        let last = preferred ?? recent.map { MobileHomeBackdropReference(kind: .classic, pack: $0.pack, level: $0.level) }
        if let last, let library = try? open(last),
           let index = library.levels.indices.first(where: {
               library.levelKey(at: $0) == last.level || (try? library.checkpointLevelIdentifier(at: $0)) == last.level
           }), let result = try? scenery(library, index: index) { return result }
        try Task.checkCancellation()
        var choices = (catalogue?.families.flatMap { catalogue?.packs(in: $0) ?? [] } ?? []).map {
            MobileHomeBackdropReference(kind: .classic, pack: $0.id, level: "")
        }
        choices += native.keys.map { .init(kind: $0, level: "") }
        if classicDirectory != nil { choices.append(.init(kind: .classic, level: "")) }
        for choice in choices.shuffled() {
            try Task.checkCancellation()
            guard let library = try? open(choice) else { continue }
            for index in library.levels.indices.shuffled().prefix(8) {
                if let result = try? scenery(library, index: index) { return result }
                try Task.checkCancellation()
            }
        }
        return nil
    }
}
