import Foundation

enum MobileAudioSessionOperation: Sendable {
    case prepare
    case resume
    case suspend
}

/// Orders session changes across level controllers, including asynchronous activation.
@MainActor final class MobileAudioSessionWorkQueue {
    static let shared = MobileAudioSessionWorkQueue()
    private var pending: Task<Void, Never>?
    private struct Owner {
        weak var requests: MobileAudioSessionRequests?
    }
    private var owners: [UUID: Owner] = [:]
    private(set) var playbackAllowed = true

    func setPlaybackAllowed(_ allowed: Bool) {
        playbackAllowed = allowed
        guard !allowed else { return }
        // Invalidate activations already running as well as queued requests.
        let requests = owners.values.compactMap { $0.requests }
        for request in requests { request.suspend() }
    }

    func claim(_ id: UUID, requests: MobileAudioSessionRequests) {
        owners = owners.filter { $0.value.requests != nil }
        owners[id] = Owner(requests: requests)
    }

    func release(_ id: UUID) {
        owners[id] = nil
    }

    var hasActiveOwners: Bool { owners.values.contains { $0.requests != nil } }

    func enqueue(
        _ operation: @escaping @MainActor @Sendable () async throws -> Void,
        completion: @escaping @MainActor (Bool) -> Void
    ) -> Task<Void, Never> {
        let previous = pending
        let task = Task {
            await previous?.value
            let succeeded: Bool
            do {
                try await operation()
                succeeded = true
            } catch {
                succeeded = false
            }
            completion(succeeded)
        }
        pending = task
        return task
    }
}

/// A suspended or replaced request must not restart its level's audio.
@MainActor final class MobileAudioSessionRequests {
    private let queue: MobileAudioSessionWorkQueue
    private let perform: @Sendable (MobileAudioSessionOperation) async throws -> Void
    private var resumeID = UUID()
    private let ownerID = UUID()

    init(
        queue: MobileAudioSessionWorkQueue,
        perform: @escaping @Sendable (MobileAudioSessionOperation) async throws -> Void
    ) {
        self.queue = queue
        self.perform = perform
    }

    @discardableResult func prepare() -> Task<Void, Never> {
        let perform = perform
        let queue = queue
        return queue.enqueue({
            guard queue.playbackAllowed else { return }
            try await perform(.prepare)
        }, completion: { _ in })
    }

    @discardableResult func resume(completion: @escaping @MainActor (Bool) -> Void) -> Task<Void, Never> {
        let id = UUID()
        resumeID = id
        guard queue.playbackAllowed else {
            return queue.enqueue({}) { [weak self] _ in
                guard self?.resumeID == id else { return }
                completion(false)
            }
        }
        queue.claim(ownerID, requests: self)
        let perform = perform
        let queue = queue
        return queue.enqueue({ [weak self] in
            guard self?.resumeID == id, queue.playbackAllowed else { return }
            try await perform(.resume)
        }) { [weak self] succeeded in
            guard let self, self.resumeID == id else { return }
            if !succeeded { self.queue.release(self.ownerID) }
            completion(succeeded)
        }
    }

    @discardableResult func suspend() -> Task<Void, Never> {
        resumeID = UUID()
        queue.release(ownerID)
        let perform = perform
        let queue = queue
        return queue.enqueue({
            // A departing level must not deactivate Home or its replacement level.
            guard !queue.hasActiveOwners else { return }
            try await perform(.suspend)
        }, completion: { _ in })
    }
}
