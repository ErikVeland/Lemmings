import AVFoundation
import Foundation
import NxlvKit

extension ModuleMusicPlayer {
    func checkResumeDoesNotWaitForQueuedSynthesis() throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 512)
        try start()
        synthesisQueue.sync {}
        sourceNode!.stop()
        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        synthesisQueue.async { entered.signal(); release.wait() }
        precondition(entered.wait(timeout: .now() + 2) == .success)
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(300)) { release.signal() }
        let began = ProcessInfo.processInfo.systemUptime
        try resumeOutput()
        let elapsed = ProcessInfo.processInfo.systemUptime - began
        synthesisQueue.sync {}
        let restarted = sourceNode!.isPlaying
        sourceNode!.stop()
        let blocked = DispatchSemaphore(value: 0)
        let unblock = DispatchSemaphore(value: 0)
        synthesisQueue.async { blocked.signal(); unblock.wait() }
        precondition(blocked.wait(timeout: .now() + 2) == .success)
        try resumeOutput()
        suspendOutput(immediately: true)
        unblock.signal()
        synthesisQueue.sync {}
        precondition(sourceNode?.isPlaying == false && !engine.isRunning,
                     "A pending music restart ignored a later suspension")
        try resumeOutput()
        synthesisQueue.sync {}
        precondition(sourceNode?.isPlaying == true && engine.isRunning,
                     "Music could not resume after a cancelled restart")
        stop()
        engine.disableManualRenderingMode()
        print("MUSIC RESUME seconds=\(elapsed) restarted=\(restarted)")
        precondition(elapsed < 0.05 && restarted, "Music Resume blocked on queued synthesis")
    }
}
try ModuleMusicPlayer().checkResumeDoesNotWaitForQueuedSynthesis()
