import Foundation

final class CommandResults: @unchecked Sendable {
    let lock = NSLock()
    var values: [Int] = []
    func append(_ value: Int) { lock.lock(); values.append(value); lock.unlock() }
}
let queue = AudioPlaybackQueue(label: "test.audio-control")
let entered = DispatchSemaphore(value: 0)
let release = DispatchSemaphore(value: 0)
let finished = DispatchSemaphore(value: 0)
let results = CommandResults()
queue.submit(persistent: true) { entered.signal(); release.wait(); results.append(1) }
precondition(entered.wait(timeout: .now() + 2) == .success)
let began = ProcessInfo.processInfo.systemUptime
queue.submit { results.append(2) }
queue.cancelPending()
queue.submit(persistent: true) { results.append(3) }
queue.submit { results.append(4); finished.signal() }
precondition(ProcessInfo.processInfo.systemUptime - began < 0.05, "Audio submission waited for the busy worker")
release.signal()
precondition(finished.wait(timeout: .now() + 2) == .success)
precondition(results.values == [1, 3, 4], "Pause lost preparation or replayed an obsolete cue")
print("PASS nonblocking audio commands, preserved preparation/shutdown order and cancelled obsolete cues")
