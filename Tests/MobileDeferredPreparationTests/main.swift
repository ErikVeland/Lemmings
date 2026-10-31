import Foundation

@main struct Checks {
    static func main() async {
        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let completion = DispatchSemaphore(value: 0)
        let loader = await MainActor.run { MobileDeferredPreparation<Int>() }
        await MainActor.run {
            loader.request({ precondition(!Thread.isMainThread); entered.signal(); release.wait(); return 42 }) { value in
                precondition(value == 42)
                completion.signal()
            }
            loader.request({ preconditionFailure("Duplicate preparation started") }) { _ in
                preconditionFailure("Duplicate preparation completed")
            }
        }
        precondition(entered.wait(timeout: .now() + 2) == .success)
        await MainActor.run { precondition(completion.wait(timeout: .now()) != .success) }
        release.signal()
        let completionDeadline = ProcessInfo.processInfo.systemUptime + 2
        while !isSignalled(completion) { precondition(ProcessInfo.processInfo.systemUptime < completionDeadline); await Task.yield() }

        let enteredAgain = DispatchSemaphore(value: 0)
        let releaseAgain = DispatchSemaphore(value: 0)
        let stale = DispatchSemaphore(value: 0)
        await MainActor.run {
            loader.request({ enteredAgain.signal(); releaseAgain.wait(); return 99 }) { _ in stale.signal() }
        }
        precondition(enteredAgain.wait(timeout: .now() + 2) == .success)
        await MainActor.run { loader.cancel() }
        let replacement = DispatchSemaphore(value: 0)
        await MainActor.run {
            loader.request({ 7 }) { value in precondition(value == 7); replacement.signal() }
        }
        let replacementDeadline = ProcessInfo.processInfo.systemUptime + 2
        while !isSignalled(replacement) { precondition(ProcessInfo.processInfo.systemUptime < replacementDeadline); await Task.yield() }
        releaseAgain.signal()
        try? await Task.sleep(nanoseconds: 100_000_000)
        precondition(stale.wait(timeout: .now()) != .success)
        print("PASS preparation runs off the UI actor and cancellation discards stale results")
    }
    static func isSignalled(_ semaphore: DispatchSemaphore) -> Bool {
        semaphore.wait(timeout: .now()) == .success
    }
}
