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

    func enqueue(
        _ operation: @escaping @Sendable () async throws -> Void,
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

    init(
        queue: MobileAudioSessionWorkQueue,
        perform: @escaping @Sendable (MobileAudioSessionOperation) async throws -> Void
    ) {
        self.queue = queue
        self.perform = perform
    }

    @discardableResult func prepare() -> Task<Void, Never> {
        let perform = perform
        return queue.enqueue({ try await perform(.prepare) }, completion: { _ in })
    }

    @discardableResult func resume(completion: @escaping @MainActor (Bool) -> Void) -> Task<Void, Never> {
        let id = UUID()
        resumeID = id
        let perform = perform
        return queue.enqueue({ try await perform(.resume) }) { [weak self] succeeded in
            guard self?.resumeID == id else { return }
            completion(succeeded)
        }
    }

    @discardableResult func suspend() -> Task<Void, Never> {
        resumeID = UUID()
        let perform = perform
        return queue.enqueue({ try await perform(.suspend) }, completion: { _ in })
    }
}
