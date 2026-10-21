import Foundation
import NxlvKit

@main private enum L3ReplayStateHashTests {
    static func main() throws {
        let attributes = Array(repeating: UInt16(0x20), count: 64 * 48)
        let ready = Lemmings3Runtime.Creature(id: 1, kind: .mole, x: 32, y: 40)
        var delayed = ready
        delayed.moleDropDelay = 1
        var patrolling = ready
        patrolling.molePatrolTick = 2

        func game(_ creature: Lemmings3Runtime.Creature) throws -> Lemmings3Runtime {
            try Lemmings3Runtime(configuration: .init(width: 64, height: 48, attributes: attributes,
                entrance: .init(x: 4, y: 40), exits: [.init(x: 56, y: 40)], total: 1,
                releaseInterval: 1, releaseDelay: 1000, creatures: [creature]))
        }

        let readyHash = L3Replay.stateHash(try game(ready))
        let delayedHash = L3Replay.stateHash(try game(delayed))
        let patrollingHash = L3Replay.stateHash(try game(patrolling))
        guard readyHash != delayedHash, readyHash != patrollingHash else {
            throw SequelDataError.invalid("Replay state hash ignored Mole movement state.")
        }
        print("PASS L3 replay state hash includes Mole movement state")
    }
}
