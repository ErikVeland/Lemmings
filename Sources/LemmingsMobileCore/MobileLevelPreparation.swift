import Foundation
import NxlvKit

public struct MobileMenuPreview: Sendable {
    public let frame: MobilePixelFrame
    public let origin: MobilePoint
    public let snapshot: MobileGameSnapshot
}

/// A prepared session transfers to gameplay once. The loader then drops its reference.
public struct MobilePreparedLevel: @unchecked Sendable {
    public let content: MobileLevelContent
}

/// Keeps decoding, artwork preparation and saved-state restoration off the UI thread.
public actor MobileMenuPreviewLoader {
    private let makeLibrary: @Sendable () throws -> any MobileGameLibrary
    private var library: (any MobileGameLibrary)?
    private var frames: [Int: MobileMenuPreview] = [:]
    private var prepared: [Int: MobileLevelContent] = [:]
    private var recent: [Int] = []

    public init(makeLibrary: @escaping @Sendable () throws -> any MobileGameLibrary) { self.makeLibrary = makeLibrary }

    public func prepare(_ index: Int, settings: ClassicSettings = .init(),
                        checkpoint: MobileCheckpointEnvelope? = nil,
                        allowUnrelatedCheckpoint: Bool = false) throws -> MobilePreparedLevel {
        try Task.checkCancellation()
        let opened = try library ?? makeLibrary()
        library = opened
        let content = try prepared.removeValue(forKey: index) ?? opened.loadLevel(at: index)
        content.session.applySettings(settings)
        if let checkpoint, !allowUnrelatedCheckpoint || checkpoint.levelIdentifier == content.session.levelIdentifier {
            guard checkpoint.engine == content.session.engineIdentifier,
                  checkpoint.engineFingerprint == content.session.engineFingerprint,
                  checkpoint.levelIdentifier == content.session.levelIdentifier,
                  checkpoint.levelFingerprint == content.session.levelFingerprint else { throw MobileSessionError.changedLevel }
            try content.session.restoreCheckpointPayload(checkpoint.payload)
        }
        try Task.checkCancellation()
        return MobilePreparedLevel(content: content)
    }

    public func load(_ index: Int, settings: ClassicSettings = .init()) throws -> MobileMenuPreview {
        try Task.checkCancellation()
        if let cached = frames[index] { return cached }
        let opened = try library ?? makeLibrary()
        library = opened
        let content = try opened.loadLevel(at: index)
        let session = content.session
        let preview = MobileMenuPreview(frame: try session.render(highlight: nil),
                                        origin: session.initialCameraOrigin, snapshot: session.snapshot)
        // The preview keeps its existing source pixels. Prepare gameplay artwork on this worker.
        session.applySettings(settings)
        try Task.checkCancellation()
        recent.removeAll { $0 == index }; recent.append(index)
        prepared[index] = content
        frames[index] = preview
        while recent.count > 3 || frames.values.reduce(0, { $0 + $1.frame.rgba.count }) > 12 * 1024 * 1024 && recent.count > 1 {
            let oldest = recent.removeFirst()
            prepared.removeValue(forKey: oldest); frames.removeValue(forKey: oldest)
        }
        return preview
    }

    public func releaseCaches() { prepared.removeAll(); frames.removeAll(); recent.removeAll() }
}
