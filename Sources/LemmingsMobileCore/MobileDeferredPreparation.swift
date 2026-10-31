import Foundation

@MainActor public final class MobileDeferredPreparation<Value: Sendable> {
    private var generation: UInt64 = 0
    private var task: Task<Value?, Never>?

    public init() {}

    public func request(_ build: @escaping @Sendable () -> Value?,
                        completion: @escaping @MainActor @Sendable (Value?) -> Void) {
        guard task == nil else { return }
        generation &+= 1
        let request = generation
        let worker = Task.detached(priority: .utility) { build() }
        task = worker
        Task { @MainActor [weak self] in
            let result = await worker.value
            guard let self, self.generation == request else { return }
            self.task = nil
            completion(result)
        }
    }

    public func cancel() {
        generation &+= 1
        task?.cancel()
        task = nil
    }
}
