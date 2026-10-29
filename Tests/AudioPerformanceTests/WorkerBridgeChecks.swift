import Foundation

extension SoundEffectPlayer {
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
        print("PASS worker-owned playheads, camera/gain updates, rescue merging, 10,000 bounded commands and silence")
    }
}

SoundEffectPlayer.checkWorkerBridge()
