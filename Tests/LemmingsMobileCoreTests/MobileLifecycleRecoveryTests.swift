import Testing
@testable import LemmingsMobileCore

struct MobileLifecycleRecoveryTests {
    @Test(arguments: [
        [MobileLifecycleEvent.audioInterruptionBegan, .becameInactive, .enteredBackground, .becameActive],
        [.becameInactive, .audioInterruptionBegan, .enteredBackground, .becameActive],
        [.becameInactive, .enteredBackground, .audioInterruptionBegan, .becameActive],
        [.becameInactive, .enteredBackground, .becameActive, .audioInterruptionBegan],
    ])
    func explicitResumeRecoversWithoutInterruptionEnd(events: [MobileLifecycleEvent]) {
        var lifecycle = MobileLifecycleState()
        var play = MobilePlayState()
        #expect(play.resume(isForeground: true, isInterrupted: false) == true)
        for event in events {
            let effects = lifecycle.handle(event)
            if effects.contains(.pauseSimulation) { play.suspend() }
            #expect(!effects.contains(.resumeSimulation))
            #expect(!effects.contains(.resumeAudio))
            #expect(play.isPaused)
        }
        #expect(lifecycle.isInterrupted)
        #expect(lifecycle.requiresPlayerResume)
        #expect(lifecycle.acceptsInput(menuVisible: true))
        #expect(!lifecycle.acceptsInput(menuVisible: false))

        let effects = lifecycle.handle(.playerRequestedResume)
        #expect(effects == [.resumeSimulation, .resumeAudio])
        #expect(play.resume(isForeground: lifecycle.isForeground, isInterrupted: lifecycle.isInterrupted) == true)
        #expect(!lifecycle.isPaused && !play.isPaused)
        #expect(!lifecycle.isInterrupted && !lifecycle.requiresPlayerResume)
        #expect(lifecycle.acceptsInput(menuVisible: false))
        #expect(lifecycle.handle(.playerRequestedResume).isEmpty)
        // A delayed notification cannot reopen Pause after the player resumed.
        #expect(lifecycle.handle(.audioInterruptionEnded).isEmpty)
        #expect(!lifecycle.isPaused)
    }

    @Test func routeLossCanResumeWithoutAnEndNotification() {
        var state = MobileLifecycleState()
        // The audio adapter maps a lost output route to the same suspension event.
        let effects = state.handle(.audioInterruptionBegan)
        #expect(effects.contains(.showResumeControl))
        #expect(effects.contains(.suspendAudio))
        #expect(state.acceptsInput(menuVisible: true))
        #expect(!state.acceptsInput(menuVisible: false))
        #expect(state.handle(.playerRequestedResume) == [.resumeSimulation, .resumeAudio])
        #expect(!state.isInterrupted && !state.isPaused)
    }

    @Test func backgroundResumeCannotClearTheInterruption() {
        var state = MobileLifecycleState()
        _ = state.handle(.audioInterruptionBegan)
        _ = state.handle(.becameInactive)
        _ = state.handle(.enteredBackground)
        #expect(!state.acceptsInput(menuVisible: true))
        #expect(!state.acceptsInput(menuVisible: false))
        #expect(state.handle(.playerRequestedResume).isEmpty)
        #expect(state.isInterrupted && state.isPaused && state.requiresPlayerResume)
        #expect(state.handle(.becameActive) == [.prepareAudio, .showResumeControl])
        #expect(state.isInterrupted && state.isPaused && state.requiresPlayerResume)
    }

    @Test func normalInterruptionEndStillWaitsForThePlayer() {
        var state = MobileLifecycleState()
        _ = state.handle(.audioInterruptionBegan)
        #expect(state.handle(.audioInterruptionEnded) == [.prepareAudio, .showResumeControl])
        #expect(!state.isInterrupted && state.isPaused && state.requiresPlayerResume)
        #expect(state.handle(.playerRequestedResume) == [.resumeSimulation, .resumeAudio])
    }

    @Test(arguments: [false, true])
    func sleepAndAudioRecoveryPreserveReadyHandover(receivesEnd: Bool) {
        var lifecycle = MobileLifecycleState()
        var play = MobilePlayState()
        for event in [MobileLifecycleEvent.becameInactive, .enteredBackground, .audioInterruptionBegan, .becameActive] {
            let effects = lifecycle.handle(event)
            if effects.contains(.pauseSimulation) { play.suspend() }
            #expect(play.phase == .ready)
            #expect(!effects.contains(.resumeSimulation))
        }
        if receivesEnd {
            #expect(lifecycle.handle(.audioInterruptionEnded) == [.prepareAudio, .showResumeControl])
        }
        #expect(play.phase == .ready)
        #expect(lifecycle.handle(.playerRequestedResume) == [.resumeSimulation, .resumeAudio])
        #expect(play.resume(isForeground: lifecycle.isForeground, isInterrupted: lifecycle.isInterrupted) == true)
        #expect(play.phase == .running)
    }
}
