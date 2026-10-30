import Foundation

/// Native sequel decoding and replay need more stack than the cooperative pool provides.
/// One serial worker bounds both stack reservation and concurrent preparation memory.
final class MobilePreparationExecutor: SerialExecutor, @unchecked Sendable {
    static let shared = MobilePreparationExecutor()

    private let condition = NSCondition()
    private var jobs: [UnownedJob] = []

    private init() {
        let worker = Thread { [self] in run() }
        worker.name = "Lemmings level preparation"
        worker.qualityOfService = .userInitiated
        worker.stackSize = 8 * 1024 * 1024
        worker.start()
    }

    func enqueue(_ job: UnownedJob) {
        condition.lock()
        jobs.append(job)
        condition.signal()
        condition.unlock()
    }

    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        UnownedSerialExecutor(ordinary: self)
    }

    private func run() {
        while true {
            condition.lock()
            while jobs.isEmpty { condition.wait() }
            let job = jobs.removeFirst()
            condition.unlock()
            autoreleasepool {
                job.runSynchronously(on: asUnownedSerialExecutor())
            }
        }
    }
}
