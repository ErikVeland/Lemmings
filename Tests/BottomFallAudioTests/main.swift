import Foundation
import NxlvKit

final class PlayedClips: @unchecked Sendable {
    private let lock = NSLock()
    private var clips = 0
    func record(_ samples: [Float], _ rate: Double, _ gain: Float) {
        precondition(!samples.isEmpty && rate > 0 && gain > 0)
        lock.lock(); defer { lock.unlock() }; clips += 1
    }
    var count: Int { lock.lock(); defer { lock.unlock() }; return clips }
}
func check(_ value: Bool, _ message: String) {
    if !value { fatalError(message) }
}
let resources = URL(fileURLWithPath: CommandLine.arguments[1])
let mac = resources.appendingPathComponent("Ports/lemmings_1_5_2/Lemmings_1_5_2.dsk")
do {
    // The Mac disk has no Pop. The Mac set borrows the named Amiga sample.
    let player = SoundEffectPlayer()
    let alone = try player.loadMacintoshSounds(imageURL: mac)
    check(!alone.contains(.pop), "The Mac disk unexpectedly gained a Pop sound")
    let filled = try player.loadMacintoshSounds(imageURL: mac,
        amigaFallbackDirectory: resources.appendingPathComponent("Ports/amiga_extracted/lemmings"))
    check(filled.contains(.pop) && Set(alone).isSubset(of: Set(filled)), "The Mac set did not fill Pop from the Amiga bank")
    print("PASS Mac sound set fills Pop from the Amiga bank")
}
for source in 0..<3 {
    let player = SoundEffectPlayer()
    if source == 0 { try player.loadMacintoshSounds(imageURL: mac) }
    if source == 1 { try player.loadAmigaSounds(directory: resources.appendingPathComponent("Ports/amiga_extracted/lemmings"), deathFallbackImage: mac) }
    if source == 2 { try player.loadLemmings3Sounds(root: resources.appendingPathComponent("Ports/LEM3CD")) }
    let clips = PlayedClips()
    player.onPlay = { clips.record($0, $1, $2) }
    player.play(.fallOut)
    check(clips.count == 1, "Bottom death must play by default for bank \(source)")
    player.setBottomFallSounds(false)
    player.play(.fallOut)
    check(clips.count == 1, "Opt-out must suppress bottom death")
    player.play(.splat)
    check(clips.count == 2, "Opt-out must preserve other deaths")
    player.setBottomFallSounds(true)
    player.play(.fallOut)
    check(clips.count == 3, "Re-enabling must restore bottom death")
    player.setMuted(true)
    player.play(.fallOut)
    check(clips.count == 3, "Global mute must suppress bottom death")
}
let l2 = try Lemmings2SoundPlayer(root: resources.appendingPathComponent("Ports/Lemm2"))
let clips = PlayedClips()
l2.onPlay = { clips.record($0, $1, $2) }
let bottom = Lemmings2SoundRequest(.fallOut, isBottomFall: true)
l2.play([bottom, bottom])
check(clips.count == 1, "L2 simultaneous bottom deaths must share one voice")
l2.setBottomFallSounds(false)
l2.play([bottom])
check(clips.count == 1, "L2 opt-out must suppress bottom death")
l2.play([.init(.fallOut), .init(.splat)])
check(clips.count == 3, "L2 opt-out must preserve side-boundary and splat deaths")
l2.setBottomFallSounds(true)
l2.play([bottom])
check(clips.count == 4, "L2 bottom death must resume")
l2.setMuted(true)
l2.play([bottom])
check(clips.count == 4, "L2 global mute must suppress bottom death")
print("PASS default, opt-out, re-enable, other deaths and global mute across Macintosh, Amiga fallback, L2 and L3")
