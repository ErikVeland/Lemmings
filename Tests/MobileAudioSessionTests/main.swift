import Foundation

private actor SessionProbe {
    enum Failure: Error { case activation }
    private var events: [String] = []
    private var holdResume: Bool
    private var failResume: Bool
    private var resumeStarted = false
    private var startedWaiter: CheckedContinuation<Void, Never>?
    private var resumeWaiter: CheckedContinuation<Void, Never>?

    init(holdResume: Bool = false, failResume: Bool = false) {
        self.holdResume = holdResume
        self.failResume = failResume
    }

    func perform(_ operation: MobileAudioSessionOperation) async throws {
        precondition(!Thread.isMainThread, "Session work ran on the main thread")
        events.append("\(operation):start")
        if case .resume = operation {
            resumeStarted = true
            startedWaiter?.resume()
            startedWaiter = nil
            if holdResume {
                holdResume = false
                await withCheckedContinuation { resumeWaiter = $0 }
            }
            if failResume { throw Failure.activation }
        }
        events.append("\(operation):end")
    }

    func waitForResume() async {
        if resumeStarted { return }
        await withCheckedContinuation { startedWaiter = $0 }
    }

    func releaseResume() {
        resumeWaiter?.resume()
        resumeWaiter = nil
    }

    func log() -> [String] { events }
}

@main private struct MobileAudioSessionChecks {
    @MainActor static func main() async {
        precondition(ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] == "muted")
        await checkLevelTransitionOrder()
        await checkSupersededResume()
        await checkActivationFailure()
        await checkReleasedController()
        print("PASS audio session ordering, stale activation, failure and controller lifetime (silent, headless)")
    }

    @MainActor private static func checkLevelTransitionOrder() async {
        let queue = MobileAudioSessionWorkQueue()
        let probe = SessionProbe(holdResume: true)
        let first = MobileAudioSessionRequests(queue: queue) { try await probe.perform($0) }
        let next = MobileAudioSessionRequests(queue: queue) { try await probe.perform($0) }
        var callbacks: [String] = []
        first.prepare()
        first.resume { _ in callbacks.append("old level") }
        await probe.waitForResume()
        // The main actor can handle suspension while activation remains unfinished.
        first.suspend()
        next.prepare()
        let finished = next.resume { succeeded in
            precondition(Thread.isMainThread && succeeded)
            callbacks.append("next level")
        }
        let blockedLog = await probe.log()
        precondition(blockedLog == ["prepare:start", "prepare:end", "resume:start"],
                     "Session changes overlapped an unfinished activation")
        await probe.releaseResume()
        await finished.value
        let log = await probe.log()
        precondition(log == ["prepare:start", "prepare:end", "resume:start", "resume:end",
                             "suspend:start", "suspend:end", "prepare:start", "prepare:end",
                             "resume:start", "resume:end"])
        precondition(callbacks == ["next level"], "A departed level restarted its audio")
    }

    @MainActor private static func checkSupersededResume() async {
        let probe = SessionProbe(holdResume: true)
        let requests = MobileAudioSessionRequests(queue: MobileAudioSessionWorkQueue()) {
            try await probe.perform($0)
        }
        var callbacks: [Int] = []
        requests.resume { _ in callbacks.append(1) }
        await probe.waitForResume()
        let finished = requests.resume { succeeded in
            precondition(succeeded)
            callbacks.append(2)
        }
        await probe.releaseResume()
        await finished.value
        precondition(callbacks == [2], "A replaced activation started audio twice")
    }

    @MainActor private static func checkActivationFailure() async {
        let probe = SessionProbe(failResume: true)
        let requests = MobileAudioSessionRequests(queue: MobileAudioSessionWorkQueue()) {
            try await probe.perform($0)
        }
        var succeeded: Bool?
        await requests.resume { succeeded = $0 }.value
        precondition(succeeded == false, "Failed activation was reported as ready for playback")
        await requests.suspend().value
        let log = await probe.log()
        precondition(log.suffix(2) == ["suspend:start", "suspend:end"],
                     "Activation failure blocked later session work")
    }

    @MainActor private static func checkReleasedController() async {
        let probe = SessionProbe(holdResume: true)
        var requests: MobileAudioSessionRequests? = MobileAudioSessionRequests(queue: MobileAudioSessionWorkQueue()) {
            try await probe.perform($0)
        }
        weak let weakRequests = requests
        var callbackRan = false
        let finished = requests!.resume { _ in callbackRan = true }
        await probe.waitForResume()
        requests = nil
        precondition(weakRequests == nil, "Activation retained a departed controller")
        await probe.releaseResume()
        await finished.value
        precondition(!callbackRan, "A released controller received an activation callback")
    }
}
