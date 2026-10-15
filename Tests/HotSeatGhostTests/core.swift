import Foundation
import NxlvKit
import LemmingsAppCore

func checkGhost(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    guard try condition() else { throw NSError(domain: "HotSeatGhostTests", code: 1,
        userInfo: [NSLocalizedDescriptionKey: message]) }
}

func validateHotSeatGhosts(initial: ActionReplayState) throws -> LeaderboardActionReplay {
    var final = initial
    for _ in 0..<120 where !final.complete { final.step() }
    let end = LeaderboardActionReplay.Command(tick: final.tick,
        action: initial.engine == "lemmings3" ? "abort" : "nuke")
    let commands: [LeaderboardActionReplay.Command] = final.complete ? [] : [end]
    if !final.complete { try final.apply(end) }
    for _ in 0..<5000 where !final.complete { final.step() }
    try checkGhost(final.complete, "Fixture did not complete: \(initial.engine)")
    let conditions = TrolleyConditions(gameID: initial.engine == "classic" ? "lemmings" : initial.engine,
        packID: "ghost-tests", levelID: "1", levelFingerprint: try initial.hash(), rulesetVersion: "test", physicsMode: "test",
        population: initial.population, rescueRequirement: 1, startingSkills: [:], timeLimitSeconds: nil)
    let level = ArcadeLevel(id: "ghost", title: "Ghost", game: initial.engine, rules: "test",
        total: initial.population, required: 1, conditions: conditions)
    let run = ArcadeRun(profileID: "first", level: level, saved: final.saved, didWin: final.didWin,
        skills: [:], seconds: Double(final.tick) / final.ticksPerSecond)
    let replay = try LeaderboardActionReplay.capture(run: run, initial: initial, final: final, commands: commands)
    let attempts = [HotSeatGhostAttempt(playerID: "first", colour: .blue, replay: replay),
                    HotSeatGhostAttempt(playerID: "second", colour: .pink, replay: replay)]
    var ghosts = HotSeatGhostPlayback(attempts: attempts, initial: initial)
    var reference = try ActionReplayCursor(replay: replay, initial: initial)
    let originalHash = try initial.hash()
    for tick in [0, 80, 80, 119, replay.ticks + 100, 20, 100, 0, 119] {
        let frames = ghosts.frames(at: tick)
        if tick >= replay.ticks { try checkGhost(frames.isEmpty, "Finished ghost stayed visible"); continue }
        try reference.seek(to: tick)
        try checkGhost(frames.count == 2, "Earlier players missing")
        try checkGhost(frames.map(\.playerID) == ["first", "second"], "Ghost identity changed")
        try checkGhost(Set(frames.map(\.colour)).count == 2, "Ghost colours collide")
        for frame in frames { try checkGhost(try frame.state.hash() == reference.state.hash(), "Ghost timeline diverged") }
    }
    try checkGhost(try initial.hash() == originalHash, "Ghost changed live state")
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let archive = HotSeatGhostArchive(directory: root)
    try archive.save(attempts[0], sessionID: "session", players: ["first", "second", "third"])
    try archive.save(attempts[1], sessionID: "session", players: ["first", "second", "third"])
    try archive.save(attempts[0], sessionID: "session", players: ["first", "second", "third"])
    let reloaded = HotSeatGhostArchive(directory: root)
    func load(_ session: String = "session", _ owner: String = "third", _ roster: [String] = ["first", "second", "third"], _ hash: String? = nil) -> [HotSeatGhostAttempt] {
        reloaded.attempts(sessionID: session, conditions: conditions.fingerprint, initialHash: hash ?? originalHash,
                          excluding: owner, players: roster)
    }
    try checkGhost(load().count == 2, "Relaunch lost ghosts or retained duplicate retries")
    try checkGhost(load("session", "first").map(\.playerID) == ["second"], "Player saw their own ghost")
    try checkGhost(load("other").isEmpty, "Ghost crossed sessions")
    try checkGhost(load("session", "third", ["first", "third"]).count == 1, "Removed player stayed visible")
    try checkGhost(load("session", "third", ["first", "second", "third"], "changed").isEmpty, "Ghost crossed starting states")
    try checkGhost(reloaded.attempts(sessionID: "session", conditions: "other-level", initialHash: originalHash,
        excluding: "third", players: ["first", "second", "third"]).isEmpty, "Ghost crossed levels")
    try reloaded.remove(playerID: "first")
    try checkGhost(load().map(\.playerID) == ["second"], "Deleted player's ghost remained on disk")
    var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(replay)) as! [String: Any]
    object["initialStateHash"] = String(repeating: "0", count: 64)
    let bad = try JSONDecoder().decode(LeaderboardActionReplay.self, from: JSONSerialization.data(withJSONObject: object))
    try checkGhost(HotSeatGhostPlayback(attempts: [.init(playerID: "bad", colour: .red, replay: bad)], initial: initial).count == 0,
                   "Changed data accepted a ghost")
    object["initialStateHash"] = replay.initialStateHash
    object["commands"] = [["tick": 5, "action": "invalid-command"]]
    let broken = try JSONDecoder().decode(LeaderboardActionReplay.self, from: JSONSerialization.data(withJSONObject: object))
    var unavailable = HotSeatGhostPlayback(attempts: [.init(playerID: "bad", colour: .red, replay: broken)], initial: initial)
    try checkGhost(unavailable.frames(at: 4).count == 1, "Valid ghost prefix missing")
    try checkGhost(unavailable.frames(at: 6).isEmpty && unavailable.frames(at: 7).isEmpty,
                   "Invalid ghost continued after a rejected command")
    print("PASS \(initial.engine): two ghosts, pause, rewind, end, isolation, persistence and latest-per-player")
    return replay
}

@MainActor func validateStoreGhosts(initial: ActionReplayState, replay: LeaderboardActionReplay) throws {
    let storage = try AppStorage.temporary(named: "ghost-ownership")
    defer { storage.removeTemporaryFiles() }
    let store = ArcadeStore(storage: storage, bundledProofs: nil)
    let first = store.records.activeProfileID
    let second = store.addProfile(initials: "TWO", portrait: 1, select: false)!.id
    let third = store.addProfile(initials: "THR", portrait: 2, select: false)!.id
    store.toggleSessionProfile(second); store.toggleSessionProfile(third)
    let session = store.hotSeatID!
    let level = ArcadeLevel(id: "ghost", title: "Ghost", game: initial.engine, rules: "test",
        total: initial.population, required: 1, conditions: replay.conditions)
    var final = try ActionReplayCursor(replay: replay, initial: initial)
    try final.seek(to: replay.ticks)
    for player in [first, second] {
        let run = ArcadeRun(profileID: player, level: level, saved: replay.saved, didWin: replay.won,
            skills: [:], seconds: Double(replay.ticks) / initial.ticksPerSecond)
        store.preserveHotSeatGhost(run: run, sessionID: session, initial: initial, final: final.state, commands: replay.commands)
    }
    try checkGhost(store.hotSeatGhosts(initial: initial, level: level, playerID: third, sessionID: session)?.count == 2,
                   "Store did not attach both earlier players")
    try checkGhost(store.hotSeatGhosts(initial: initial, level: level, playerID: first, sessionID: session)?.count == 1,
                   "Store attached the current player's old turn")
    let reopened = ArcadeStore(storage: storage, bundledProofs: nil)
    try checkGhost(reopened.hotSeatGhosts(initial: initial, level: level, playerID: third, sessionID: session)?.count == 2,
                   "Resumed Hot Seat lost its ghosts")
    try checkGhost(store.startNewHotSeat(), "Could not start a fresh session")
    try checkGhost(store.hotSeatGhosts(initial: initial, level: level, playerID: third, sessionID: store.hotSeatID)?.count == 0,
                   "New Hot Seat inherited ghosts")
    store.endHotSeat()
    try checkGhost(store.hotSeatGhosts(initial: initial, level: level, playerID: first, sessionID: nil) == nil,
                   "Solo play inherited ghosts")
    print("PASS \(initial.engine): store ownership, resumed session, new session and solo boundaries")
}
