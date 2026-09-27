import Foundation

private final class PlayCount: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func record() { lock.lock(); value += 1; lock.unlock() }
    var count: Int { lock.lock(); defer { lock.unlock() }; return value }
}

let player = try Lemmings2SoundPlayer(root: URL(fileURLWithPath: "Sources/Ports/Lemm2"))
try player.start()
player.setVolume(0.25)
private let plays = PlayCount()
player.onPlay = { _, _, _ in plays.record() }
player.play([.init(.builderWarning)])
precondition(plays.count == 1)
player.suspendOutput()
player.play([.init(.builderWarning)])
precondition(plays.count == 1)
try player.resumeOutput()
player.play([.init(.builderWarning)])
precondition(plays.count == 2)
player.setMuted(true)
player.stop()
try player.start()
player.stop()
print("Lemmings 2 spatial graph start, stop, restart, mute and pause backlog passed")
