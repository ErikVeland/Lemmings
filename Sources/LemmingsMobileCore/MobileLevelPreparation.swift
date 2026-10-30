import Foundation
import NxlvKit

private final class MobilePreparationCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    func check() throws {
        lock.lock(); let value = cancelled; lock.unlock()
        if value { throw CancellationError() }
        try Task.checkCancellation()
    }
}

/// Transfers a newly opened library from its worker to the menu once.
/// The worker does not retain or use the library after returning it.
public struct MobileOpenedLibrary: @unchecked Sendable {
    public let library: (any MobileGameLibrary)?
}

public actor MobileLibraryLoader {
    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        MobilePreparationExecutor.shared.asUnownedSerialExecutor()
    }

    public init() {}

    public nonisolated func open(_ makeLibrary: @escaping @Sendable () throws -> (any MobileGameLibrary)?) async throws -> MobileOpenedLibrary {
        let cancellation = MobilePreparationCancellation()
        return try await withTaskCancellationHandler {
            try await openOnWorker(makeLibrary, cancellation: cancellation)
        } onCancel: { cancellation.cancel() }
    }

    private func openOnWorker(_ makeLibrary: @Sendable () throws -> (any MobileGameLibrary)?,
                              cancellation: MobilePreparationCancellation) throws -> MobileOpenedLibrary {
        try cancellation.check()
        let library = try makeLibrary()
        try cancellation.check()
        return MobileOpenedLibrary(library: library)
    }
}

public struct MobileMenuPreview: Sendable {
    public let frame: MobilePixelFrame
    public let origin: MobilePoint
    public let snapshot: MobileGameSnapshot
    public let renderScale: Double

    public var sourceRect: MobileRect {
        Self.sourceRect(frame: frame, origin: origin, renderScale: renderScale)
    }

    public static func sourceRect(frame: MobilePixelFrame, origin: MobilePoint, renderScale: Double) -> MobileRect {
        let width = min(320 * renderScale, Double(frame.width))
        let height = min(160 * renderScale, Double(frame.height))
        return .init(x: max(0, min(Double(frame.width) - width, origin.x * renderScale)),
                     y: max(0, min(Double(frame.height) - height, origin.y * renderScale)), width: width, height: height)
    }
}

/// A prepared session transfers to gameplay once. The loader then drops its reference.
public struct MobilePreparedLevel: @unchecked Sendable {
    public let content: MobileLevelContent
}

/// Keeps decoding, artwork preparation and saved-state restoration off the UI thread.
public actor MobileMenuPreviewLoader {
    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        MobilePreparationExecutor.shared.asUnownedSerialExecutor()
    }

    private let makeLibrary: @Sendable () throws -> any MobileGameLibrary
    private var library: (any MobileGameLibrary)?
    private var frames: [Int: MobileMenuPreview] = [:]
    private var previewSettings: ClassicSettings?
    private var prepared: [Int: MobileLevelContent] = [:]
    private var recent: [Int] = []

    public init(makeLibrary: @escaping @Sendable () throws -> any MobileGameLibrary) { self.makeLibrary = makeLibrary }

    public nonisolated func prepare(_ index: Int, settings: ClassicSettings = .init(),
                        checkpoint: MobileCheckpointEnvelope? = nil,
                        allowUnrelatedCheckpoint: Bool = false) async throws -> MobilePreparedLevel {
        let cancellation = MobilePreparationCancellation()
        return try await withTaskCancellationHandler {
            try await prepareOnWorker(index, settings: settings, checkpoint: checkpoint,
                allowUnrelatedCheckpoint: allowUnrelatedCheckpoint, cancellation: cancellation)
        } onCancel: { cancellation.cancel() }
    }

    private func prepareOnWorker(_ index: Int, settings: ClassicSettings,
                        checkpoint: MobileCheckpointEnvelope?, allowUnrelatedCheckpoint: Bool,
                        cancellation: MobilePreparationCancellation) throws -> MobilePreparedLevel {
        try cancellation.check()
        let opened = try library ?? makeLibrary()
        library = opened
        try cancellation.check()
        let content = try prepared.removeValue(forKey: index) ?? opened.loadLevel(at: index)
        try cancellation.check()
        content.session.applySettings(settings)
        try cancellation.check()
        if let checkpoint, !allowUnrelatedCheckpoint || checkpoint.levelIdentifier == content.session.levelIdentifier {
            guard checkpoint.engine == content.session.engineIdentifier,
                  checkpoint.engineFingerprint == content.session.engineFingerprint,
                  checkpoint.levelIdentifier == content.session.levelIdentifier,
                  checkpoint.levelFingerprint == content.session.levelFingerprint else { throw MobileSessionError.changedLevel }
            try content.session.restoreCheckpointPayload(checkpoint.payload)
        }
        try cancellation.check()
        return MobilePreparedLevel(content: content)
    }

    public nonisolated func load(_ index: Int, settings: ClassicSettings = .init()) async throws -> MobileMenuPreview {
        let cancellation = MobilePreparationCancellation()
        return try await withTaskCancellationHandler {
            try await loadOnWorker(index, settings: settings, cancellation: cancellation)
        } onCancel: { cancellation.cancel() }
    }

    private func loadOnWorker(_ index: Int, settings: ClassicSettings,
                              cancellation: MobilePreparationCancellation) throws -> MobileMenuPreview {
        try cancellation.check()
        if previewSettings != settings {
            frames.removeAll()
            previewSettings = settings
        }
        if let cached = frames[index] { return cached }
        let opened = try library ?? makeLibrary()
        library = opened
        try cancellation.check()
        let content = try prepared[index] ?? opened.loadLevel(at: index)
        try cancellation.check()
        let session = content.session
        session.applySettings(settings)
        try cancellation.check()
        let preview = MobileMenuPreview(frame: try session.render(highlight: nil),
                                        origin: session.menuPreviewOrigin, snapshot: session.snapshot,
                                        renderScale: session.renderScale)
        try cancellation.check()
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
