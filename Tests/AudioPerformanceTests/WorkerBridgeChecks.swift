import Foundation

extension SoundEffectPlayer {
    static func checkRepeatedSuspensionDoesNotWaitForVoiceHandoff() throws {
        let player = SoundEffectPlayer(voiceCount: 2)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        try player.engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 512)
        try player.start()
        defer { player.stop(); player.engine.disableManualRenderingMode() }
        player.suspendOutput()
        player.bufferedSource?.drain()
        let completed = DispatchSemaphore(value: 0)
        player.voiceBridge.lock.lock()
        DispatchQueue.global().async { player.suspendOutput(); completed.signal() }
        let result = completed.wait(timeout: .now() + .milliseconds(250))
        player.voiceBridge.lock.unlock()
        if result != .success { _ = completed.wait(timeout: .now() + 2) }
        precondition(result == .success, "Repeated suspension waited for the voice handoff")
        try player.engine.start()
        precondition(player.engine.isRunning)
        player.suspendOutput()
        precondition(!player.engine.isRunning, "Suspension failed to stop an unexpectedly running engine")
        try player.resumeOutput()
        precondition(player.engine.isRunning && !player.outputSuspended)
        print("PASS repeated suspension avoids the voice handoff and output resumes")
    }

    static func checkUnchangedViewportDoesNotWaitForWorker() {
        let budget = DeviceEffectResources(physicalMemory: 8 * 1_073_741_824, processorCount: 8)
        let player = SoundEffectPlayer(voiceCount: 2, resources: budget)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        player.bufferedSource = BufferedAudioSource(label: "test.viewport.noop", format: format) { _, _, _ in }
        let viewport = GameplaySoundViewport(x: 0, y: 0, width: 100, height: 100)
        player.setViewport(viewport)
        let completed = DispatchSemaphore(value: 0)
        player.voiceBridge.lock.lock()
        DispatchQueue.global().async { player.setViewport(viewport); completed.signal() }
        let result = completed.wait(timeout: .now() + .milliseconds(250))
        player.voiceBridge.lock.unlock()
        if result != .success { _ = completed.wait(timeout: .now() + 2) }
        precondition(result == .success, "Unchanged viewport waited for the audio worker")
        player.activeVoiceLimit = 1
        player.setViewport(viewport)
        precondition(player.activeVoiceLimit == 2, "Unchanged viewport failed to refresh the audio budget")
        let moved = GameplaySoundViewport(x: 10, y: 0, width: 100, height: 100)
        player.setViewport(moved)
        precondition(player.viewport == moved, "Moved viewport was not applied")
        print("PASS unchanged viewport avoids the handoff and preserves budget and camera updates")
    }

    static func checkWorkerBridge() {
        let bridge = VoiceBridge(count: 2)
        let samples: [Float] = [0.25, -0.25, 0.5, -0.5]
        var controls = [Voice(identity: 1, samples: samples, isActive: true), Voice()]
        bridge.publish(controls, previous: [], muted: false, gain: 0.75)
        var worker = Voice()
        worker.rescueLayers.reserveCapacity(64)
        let state = bridge.consume(0, into: &worker)
        precondition(state.0 == false && state.1 == 0.75 && worker.samples == samples)
        worker.position = 2; worker.lastSample = 0.5
        bridge.report(0, voice: worker)
        bridge.progress(into: &controls)
        precondition(controls[0].position == 2 && controls[0].lastSample == 0.5)
        let previous = controls
        controls[0].distanceGain = 0.25
        controls[0].rescueLayers.append(RescueLayer(identity: 2, samples: samples, increment: 1,
            gain: 0.6, distanceGain: 0.5))
        bridge.publish(controls, previous: previous, muted: false, gain: 1)
        _ = bridge.consume(0, into: &worker)
        precondition(worker.position == 2 && worker.distanceGain == 0.25)
        precondition(worker.rescueLayers.count == 1 && worker.rescueLayers[0].position == 0)
        worker.rescueLayers[0].position = 1
        bridge.report(0, voice: worker)
        bridge.progress(into: &controls)
        let beforeCamera = controls
        controls[0].distanceGain = 0.8
        controls[0].rescueLayers[0].distanceGain = 0.2
        bridge.publish(controls, previous: beforeCamera, muted: false, gain: 1)
        _ = bridge.consume(0, into: &worker)
        precondition(worker.position == 2 && worker.rescueLayers[0].position == 1)
        precondition(worker.rescueLayers[0].distanceGain == 0.2)
        // A layer completed and removed by PCM must not be resurrected by a
        // later camera command using the control side's older layer list.
        worker.rescueLayers.removeAll(keepingCapacity: true)
        bridge.report(0, voice: worker)
        bridge.progress(into: &controls)
        precondition(controls[0].rescueLayers.isEmpty)
        let completed = controls
        controls[0].distanceGain = 0.4
        bridge.publish(controls, previous: completed, muted: false, gain: 1)
        _ = bridge.consume(0, into: &worker)
        precondition(worker.rescueLayers.isEmpty && worker.position == 2)
        // Progress from the previous worker voice cannot overwrite an
        // unconsumed replacement command.
        controls[0] = Voice(identity: 3, samples: samples, isActive: true)
        bridge.publish(controls, previous: [], muted: false, gain: 1)
        bridge.progress(into: &controls)
        precondition(controls[0].identity == 3 && controls[0].position == 0)
        // Latest commands replace pending commands within one fixed slot.
        for identity in 3...10_000 {
            controls[0] = Voice(identity: UInt64(identity), samples: samples, isActive: true)
            bridge.publish(controls, previous: [], muted: false, gain: 1)
        }
        _ = bridge.consume(0, into: &worker)
        precondition(worker.identity == 10_000 && worker.position == 0 && worker.rescueLayers.isEmpty)
        let beforeSilence = controls
        controls[0].isActive = false
        bridge.publish(controls, previous: beforeSilence, muted: true, gain: 0)
        let silent = bridge.consume(0, into: &worker)
        precondition(silent.0 && silent.1 == 0 && !worker.isActive)
        print("PASS worker-owned playheads, camera/gain updates, rescue completion, pending replacement, 10,000 bounded commands and silence")
    }
}

extension SoundEffectPlayer {
    static func checkUnchangedVoiceLimitDoesNotWaitForWorker() {
        let budget = DeviceEffectResources(physicalMemory: 8 * 1_073_741_824, processorCount: 8)
        let player = SoundEffectPlayer(voiceCount: 2, resources: budget)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        player.bufferedSource = BufferedAudioSource(label: "test.voice-limit.noop", format: format) { _, _, _ in }
        let completed = DispatchSemaphore(value: 0)
        player.voiceBridge.lock.lock()
        DispatchQueue.global().async { player.setVoiceLimit(2); completed.signal() }
        let result = completed.wait(timeout: .now() + .milliseconds(250))
        player.voiceBridge.lock.unlock()
        if result != .success { _ = completed.wait(timeout: .now() + 2) }
        precondition(result == .success, "Unchanged voice limit waited for the audio worker")
        player.setVoiceLimit(1)
        precondition(player.requestedVoiceLimit == 1 && player.activeVoiceLimit == 1 && player.activeRescueLimit == 1)
        player.setVoiceLimit(2)
        precondition(player.requestedVoiceLimit == 2 && player.activeVoiceLimit == 2)
        print("PASS unchanged voice limit avoids the handoff and real limit changes still apply")
    }

    static func checkActiveResumeDoesNotWaitForVoiceHandoff() throws {
        let player = SoundEffectPlayer(voiceCount: 2)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        try player.engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 512)
        try player.start()
        defer { player.stop(); player.engine.disableManualRenderingMode() }
        let completed = DispatchSemaphore(value: 0)
        player.voiceBridge.lock.lock()
        DispatchQueue.global().async {
            try? player.resumeOutput()
            completed.signal()
        }
        let result = completed.wait(timeout: .now() + .milliseconds(250))
        player.voiceBridge.lock.unlock()
        if result != .success { _ = completed.wait(timeout: .now() + 2) }
        precondition(result == .success, "Active resume waited for the voice handoff")
        print("PASS active resume avoids the busy voice handoff")
    }

    static func checkUnchangedNukeDoesNotWaitForWorker() {
        let player = SoundEffectPlayer(voiceCount: 2)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        player.bufferedSource = BufferedAudioSource(label: "test.nuke.noop", format: format) { _, _, _ in }
        let completed = DispatchSemaphore(value: 0)
        player.voiceBridge.lock.lock()
        DispatchQueue.global().async {
            player.setNukeActive(false)
            completed.signal()
        }
        let result = completed.wait(timeout: .now() + .milliseconds(250))
        player.voiceBridge.lock.unlock()
        if result != .success { _ = completed.wait(timeout: .now() + 2) }
        precondition(result == .success, "Unchanged nuke state waited for the audio worker")
        player.setNukeActive(true)
        precondition(player.nukeActive && player.voices.contains(where: { $0.isActive }))
        player.setNukeActive(false)
        precondition(!player.nukeActive)
        print("PASS unchanged nuke state avoids the audio handoff; state changes still play")
    }
}

SoundEffectPlayer.checkWorkerBridge()
SoundEffectPlayer.checkUnchangedNukeDoesNotWaitForWorker()
try SoundEffectPlayer.checkActiveResumeDoesNotWaitForVoiceHandoff()
try SoundEffectPlayer.checkRepeatedSuspensionDoesNotWaitForVoiceHandoff()
SoundEffectPlayer.checkUnchangedViewportDoesNotWaitForWorker()
SoundEffectPlayer.checkUnchangedVoiceLimitDoesNotWaitForWorker()
