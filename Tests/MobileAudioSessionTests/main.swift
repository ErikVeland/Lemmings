import Foundation

private actor SessionProbe {
    enum Failure: Error { case activation, deactivation }
    private var events: [String] = []
    private var holdResume: Bool
    private var failResume: Bool
    private var failNextSuspend = false
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
        if case .suspend = operation, failNextSuspend {
            failNextSuspend = false
            throw Failure.deactivation
        }
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
    func failOneSuspend() { failNextSuspend = true }
}

@main private struct MobileAudioSessionChecks {
    @MainActor static func main() async {
        precondition(ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] == "muted")
        await checkLevelTransitionOrder()
        await checkSupersededResume()
        await checkActivationFailure()
        await checkReleasedController()
        await checkHomeOwnership()
        await checkAbandonedOwner()
        await checkBackgroundDuringActivation()
        await checkBackgroundBlocksPlayback()
        await checkBackgroundReleasesEveryOwner()
        await checkRapidFoldReactivation()
        await checkRepeatedBackgroundDeactivation()
        await checkFailedDeactivationRetries()
        print("PASS audio session ordering, Home ownership, phone background/foreground, stale activation, failure and controller lifetime (silent, headless)")
    }

    @MainActor private static func checkFailedDeactivationRetries() async {
        let queue = MobileAudioSessionWorkQueue()
        let probe = SessionProbe()
        let owner = MobileAudioSessionRequests(queue: queue) { try await probe.perform($0) }
        await owner.resume { precondition($0) }.value
        await probe.failOneSuspend()
        await owner.suspend().value
        await owner.suspend().value
        let log = await probe.log()
        precondition(log.filter { $0 == "suspend:start" }.count == 2 && log.last == "suspend:end",
                     "A failed session deactivation was not retried")
    }

    @MainActor private static func checkRepeatedBackgroundDeactivation() async {
        let queue = MobileAudioSessionWorkQueue()
        let probe = SessionProbe()
        let level = MobileAudioSessionRequests(queue: queue) { try await probe.perform($0) }
        let menu = MobileAudioSessionRequests(queue: queue) { try await probe.perform($0) }
        await level.resume { precondition($0) }.value
        await menu.resume { precondition($0) }.value
        queue.setPlaybackAllowed(false)
        await level.suspend().value
        let backgroundEvents = await probe.log()
        precondition(backgroundEvents.filter { $0 == "suspend:start" }.count == 1,
                     "One background transition deactivated the session more than once")
        queue.setPlaybackAllowed(true)
        await menu.resume { precondition($0) }.value
        await menu.suspend().value
        let finalEvents = await probe.log()
        precondition(finalEvents.filter { $0 == "suspend:start" }.count == 2,
                     "A later active session was not deactivated")
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
                             "prepare:start", "prepare:end",
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
        let queue = MobileAudioSessionWorkQueue()
        let requests = MobileAudioSessionRequests(queue: queue) {
            try await probe.perform($0)
        }
        var succeeded: Bool?
        await requests.resume { succeeded = $0 }.value
        precondition(succeeded == false, "Failed activation was reported as ready for playback")
        let next = MobileAudioSessionRequests(queue: queue) { try await probe.perform($0) }
        await next.suspend().value
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

    @MainActor private static func checkHomeOwnership() async {
        let queue = MobileAudioSessionWorkQueue()
        let probe = SessionProbe()
        let level = MobileAudioSessionRequests(queue: queue) { try await probe.perform($0) }
        let home = MobileAudioSessionRequests(queue: queue) { try await probe.perform($0) }
        await level.resume { precondition($0) }.value
        let departure = level.suspend()
        let activation = home.resume { precondition($0) }
        await departure.value
        await activation.value
        // UIKit may deliver both disappearance callbacks after Home has appeared.
        await level.suspend().value
        await level.suspend().value
        let homeLog = await probe.log()
        precondition(!homeLog.contains("suspend:start"), "Departing level deactivated Home music")
        await home.suspend().value
        let finalLog = await probe.log()
        precondition(finalLog.suffix(2) == ["suspend:start", "suspend:end"],
                     "Final audio owner failed to release the session")
    }

    @MainActor private static func checkAbandonedOwner() async {
        let queue = MobileAudioSessionWorkQueue()
        let probe = SessionProbe()
        var abandoned: MobileAudioSessionRequests? = MobileAudioSessionRequests(queue: queue) {
            try await probe.perform($0)
        }
        await abandoned!.resume { precondition($0) }.value
        abandoned = nil
        let home = MobileAudioSessionRequests(queue: queue) { try await probe.perform($0) }
        await home.resume { precondition($0) }.value
        await home.suspend().value
        let log = await probe.log()
        precondition(log.suffix(2) == ["suspend:start", "suspend:end"],
                     "A released controller left the audio session permanently claimed")
    }

    @MainActor private static func checkBackgroundDuringActivation() async {
        let queue = MobileAudioSessionWorkQueue()
        let probe = SessionProbe(holdResume: true)
        let level = MobileAudioSessionRequests(queue: queue) { try await probe.perform($0) }
        let menu = MobileAudioSessionRequests(queue: queue) { try await probe.perform($0) }
        var staleCallbacks = 0
        level.resume { _ in staleCallbacks += 1 }
        await probe.waitForResume()
        let queued = menu.resume { _ in staleCallbacks += 1 }
        queue.setPlaybackAllowed(false)
        precondition(!queue.hasActiveOwners, "Phone background left live audio owners")
        await probe.releaseResume()
        await queued.value
        await menu.suspend().value
        let log = await probe.log()
        precondition(log.filter { $0 == "resume:start" }.count == 1,
                     "A queued activation ran after the phone returned to its Home Screen")
        precondition(log.suffix(2) == ["suspend:start", "suspend:end"])
        precondition(staleCallbacks == 0, "An in-flight activation restarted background music")
        // Returning to the foreground grants permission, but never resumes a level itself.
        queue.setPlaybackAllowed(true)
        precondition(!queue.hasActiveOwners && staleCallbacks == 0)
        var ready = false
        await menu.resume { ready = $0 }.value
        precondition(ready, "Foreground menu could not reactivate audio")
        await menu.suspend().value
    }

    @MainActor private static func checkBackgroundBlocksPlayback() async {
        let queue = MobileAudioSessionWorkQueue()
        let probe = SessionProbe()
        let menu = MobileAudioSessionRequests(queue: queue) { try await probe.perform($0) }
        queue.setPlaybackAllowed(false)
        await menu.prepare().value
        var ready: Bool?
        await menu.resume { ready = $0 }.value
        let log = await probe.log()
        precondition(log.isEmpty && ready == false && !queue.hasActiveOwners,
                     "A delayed menu update activated audio while the app was backgrounded")
        queue.setPlaybackAllowed(true)
        await menu.prepare().value
        await menu.resume { ready = $0 }.value
        precondition(ready == true && queue.hasActiveOwners)
        await menu.suspend().value
    }

    @MainActor private static func checkBackgroundReleasesEveryOwner() async {
        let queue = MobileAudioSessionWorkQueue()
        let probe = SessionProbe()
        let level = MobileAudioSessionRequests(queue: queue) { try await probe.perform($0) }
        let menu = MobileAudioSessionRequests(queue: queue) { try await probe.perform($0) }
        await level.resume { precondition($0) }.value
        await menu.resume { precondition($0) }.value
        queue.setPlaybackAllowed(false)
        await menu.suspend().value
        let log = await probe.log()
        precondition(!queue.hasActiveOwners && log.suffix(2) == ["suspend:start", "suspend:end"],
                     "An overlapping owner prevented background session deactivation")
    }

    @MainActor private static func checkRapidFoldReactivation() async {
        let queue = MobileAudioSessionWorkQueue()
        let probe = SessionProbe(holdResume: true)
        let menu = MobileAudioSessionRequests(queue: queue) { try await probe.perform($0) }
        var callbacks: [String] = []
        menu.resume { _ in callbacks.append("before fold") }
        await probe.waitForResume()
        menu.suspend()
        menu.resume { _ in callbacks.append("unfold") }
        menu.suspend()
        let ready = menu.resume { succeeded in
            precondition(succeeded)
            callbacks.append("active")
        }
        await probe.releaseResume()
        await ready.value
        let log = await probe.log()
        precondition(callbacks == ["active"], "A fold/unfold restarted a superseded transport")
        precondition(log.filter { $0 == "resume:start" }.count == 2,
                     "A superseded fold activation reconfigured the audio session")
        precondition(!log.contains("suspend:start"),
                     "A transient fold deactivated the session after reactivation")
        await menu.suspend().value
    }
}
