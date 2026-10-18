import AppKit
import LemmingsAppCore
import LemmingsGameArt
import LemmingsMobileCore
import NxlvKit

/// iOS and tvOS sessions: shared action capture, ghost drawing, roster storage and the Records replay action.
@MainActor func runMobileGhostChecks() throws {
    let output = URL(fileURLWithPath: ".build/hot-seat-ghosts/screens")
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    let storage = MobileStorage(directory: FileManager.default.temporaryDirectory
        .appendingPathComponent("mobile-ghosts-" + UUID().uuidString))
    let classic = try ClassicMobileLibrary(directory: URL(fileURLWithPath: "Sources/Ports/lemmings_dos_1991-07-30"))
    let l2 = try Lemmings2MobileLibrary(directory: URL(fileURLWithPath: "Sources/Ports/Lemm2"), storage: storage)
    let l3 = try Lemmings3MobileLibrary(directory: URL(fileURLWithPath: "Sources/Ports/LEM3CD"), storage: storage)
    let classicReplay = try mobileGhostCheck("classic", output: output) { try classic.loadLevel(at: 0).session }
    _ = try mobileGhostCheck("lemmings2", output: output) { try l2.loadLevel(at: 0).session }
    _ = try mobileGhostCheck("lemmings3", output: output) { try l3.loadLevel(at: 0).session }

    // Records play a saved Classic action file through the shared read-only player.
    let live = try classic.loadLevel(at: 0).session as! ClassicMobileSession
    let document = try classicReplay.replay.classicReplay(initial: live.initialSimulation, title: "Records")
    let player = try live.makeReplaySession(document: document)!
    try checkGhost(player.isReadOnly && player.seekReplay(to: classicReplay.replay.ticks)
        && player.snapshot.saved == classicReplay.replay.saved, "Records replay did not reach the saved result")
    // Watching an attempt keeps its ghosts. The setter accepts read-only playback.
    player.hotSeatGhosts = HotSeatGhostPlayback(attempts: [.init(playerID: "first", colour: .green,
        replay: classicReplay.replay)], initial: classicReplay.initial)
    try checkGhost(player.hotSeatGhosts?.count == 1, "Review dropped the Hot Seat ghost")

    // The mobile roster names the session. Only other players' turns come back, in roster colours.
    let store = ArcadeStore.shared
    let roster = ["host", "first", "third"]
    let run = ArcadeRun(profileID: "first", level: classicReplay.level, saved: classicReplay.replay.saved,
        didWin: classicReplay.replay.won, skills: ["skill": 1], seconds: 1)
    store.preserveHotSeatGhost(run: run, sessionID: "mobile-seat", players: roster, initial: classicReplay.initial,
        final: classicReplay.final, commands: classicReplay.replay.commands)
    let seen = store.hotSeatGhosts(initial: classicReplay.initial, level: classicReplay.level, playerID: "third",
        sessionID: "mobile-seat", players: roster)
    try checkGhost(seen?.count == 1, "Next player did not receive the earlier turn")
    var colours = seen!
    try checkGhost(colours.frames(at: 1).first?.colour == ReplayGhostColour.allCases[1], "Roster colour changed")
    try checkGhost(store.hotSeatGhosts(initial: classicReplay.initial, level: classicReplay.level, playerID: "first",
        sessionID: "mobile-seat", players: roster)?.count == 0, "Player saw their own turn")
    try checkGhost(store.hotSeatGhosts(initial: classicReplay.initial, level: classicReplay.level, playerID: "third",
        sessionID: "other-seat", players: roster)?.count == 0, "Ghost crossed mobile sessions")
    try checkGhost(store.hotSeatGhosts(initial: classicReplay.initial, level: classicReplay.level, playerID: "third",
        sessionID: "mobile-seat", players: ["third"]) == nil, "Solo play loaded ghosts")

    // The Records level page offers Replay only when a playable action file exists.
    let recorded = ArcadeRun(profileID: store.records.activeProfileID, level: classicReplay.level,
        saved: classicReplay.replay.saved, didWin: classicReplay.replay.won, skills: ["skill": 1], seconds: 1)
    _ = store.record(recorded)
    let key = classicReplay.level.boardID
    let without = MobileCareerArt.recordLevelPage(key, records: store.records, profileID: recorded.profileID,
        profileName: "P1", subtitle: "")
    let with = MobileCareerArt.recordLevelPage(key, records: store.records, profileID: recorded.profileID,
        profileName: "P1", subtitle: "", replayRunID: recorded.id)
    try checkGhost(!without.footer.contains { $0.id.hasPrefix("recordReplay.") }, "Replay offered without a file")
    try checkGhost(with.footer.map(\.id) == ["recordReplay." + recorded.id.uuidString, "records"]
        && with.footer.first?.title == L10n.text("Replay"), "Records page lacks the Replay action")
    print("PASS mobile: roster storage, Records replay and review ghosts")
}

struct MobileGhostCapture {
    let replay: LeaderboardActionReplay
    let level: ArcadeLevel
    let initial: ActionReplayState
    let final: ActionReplayState
}

/// Plays one turn with a skill and an end-run, then draws it as a ghost behind a second, independent turn.
@MainActor func mobileGhostCheck(_ engine: String, output: URL,
                                 make: () throws -> any MobileGameSession) throws -> MobileGhostCapture {
    let first = try make()
    var assignedAt: Int?
    for _ in 0..<3_000 where assignedAt == nil {
        first.tick()
        for control in first.snapshot.skills.indices where assignedAt == nil {
            for candidate in first.targetCandidates(for: control) where candidate.assignment == .eligible {
                if first.assign(control: control, to: candidate.id) { assignedAt = first.snapshot.tick; break }
            }
        }
    }
    guard let assigned = assignedAt else { throw NSError(domain: "mobile", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "No skill was accepted in \(engine)"]) }
    for _ in 0..<40 { first.tick() }
    try checkGhost(first.beginEndRun(), "\(engine) end-run refused")
    for _ in 0..<20_000 where !first.snapshot.isComplete { first.tick() }
    try checkGhost(first.snapshot.isComplete, "\(engine) turn did not finish")

    // The mobile command log must pass the same validation as Mac and hosted replays.
    guard let capture = try first.actionCapture() else { throw NSError(domain: "mobile", code: 2,
        userInfo: [NSLocalizedDescriptionKey: "\(engine) has no action capture"]) }
    let initial = capture.initial, final = capture.final
    let conditions = TrolleyConditions(gameID: engine == "classic" ? "lemmings" : engine,
        packID: "ghost-tests", levelID: "1", levelFingerprint: try initial.hash(), rulesetVersion: "test",
        physicsMode: "test", population: initial.population, rescueRequirement: 1, startingSkills: [:],
        timeLimitSeconds: nil)
    let level = ArcadeLevel(id: "mobile-\(engine)", title: "Mobile \(engine)", game: engine, rules: "test",
        total: initial.population, required: 1, conditions: conditions)
    let skillActions = engine == "lemmings3" ? ["walker", "blocker", "jumper", "use", "drop"] : ["assign"]
    let run = ArcadeRun(profileID: "first", level: level, saved: final.saved, didWin: final.didWin,
        skills: ["skill": capture.commands.filter { skillActions.contains($0.action) }.count],
        seconds: Double(final.tick) / final.ticksPerSecond)
    let replay = try LeaderboardActionReplay.capture(run: run, initial: initial, final: final, commands: capture.commands)
    _ = try replay.checked(initial: initial)

    let ghosted = try make(), plain = try make()
    ghosted.hotSeatGhosts = HotSeatGhostPlayback(
        attempts: [.init(playerID: "first", colour: .pink, replay: replay)], initial: initial)
    try checkGhost(ghosted.hotSeatGhosts?.count == 1, "\(engine) ghost rejected")
    while ghosted.snapshot.tick < assigned + 20 { ghosted.tick(); plain.tick() }
    let ghostFrame = try ghosted.render(highlight: nil), plainFrame = try plain.render(highlight: nil)
    try checkGhost(ghostFrame.rgba != plainFrame.rgba, "\(engine) ghost not drawn")
    for control in plain.snapshot.skills.indices {
        try checkGhost(ghosted.targetCandidates(for: control).map(\.id) == plain.targetCandidates(for: control).map(\.id),
                       "\(engine) ghost changed input targets")
    }
    try checkGhost(ghosted.snapshot == plain.snapshot, "\(engine) ghost changed the live game")
    try writeMobileFrames(ghostFrame, plainFrame, to: output.appendingPathComponent("mobile-\(engine).png"))

    // Rewind follows simulation time. The ghost is drawn again at the earlier tick.
    try checkGhost(ghosted.rewind(seconds: 10 / ghosted.ticksPerSecond) && plain.rewind(seconds: 10 / plain.ticksPerSecond),
                   "\(engine) rewind refused")
    try checkGhost(try ghosted.render(highlight: nil).rgba != plain.render(highlight: nil).rgba, "\(engine) ghost lost after rewind")
    print("PASS mobile \(engine): exact action capture, ghost pixels, unchanged targets and rewind")
    return .init(replay: replay, level: level, initial: initial, final: final)
}

/// Ghost frame on the left, plain frame on the right, so a reviewer can compare them.
func writeMobileFrames(_ ghost: MobilePixelFrame, _ plain: MobilePixelFrame, to url: URL) throws {
    let rowBytes = ghost.width * 4
    var pixels = Data(count: rowBytes * 2 * ghost.height)
    for row in 0..<ghost.height {
        pixels.replaceSubrange((row * rowBytes * 2)..<(row * rowBytes * 2 + rowBytes),
                               with: ghost.rgba[(row * rowBytes)..<((row + 1) * rowBytes)])
        pixels.replaceSubrange((row * rowBytes * 2 + rowBytes)..<((row + 1) * rowBytes * 2),
                               with: plain.rgba[(row * rowBytes)..<((row + 1) * rowBytes)])
    }
    guard let provider = CGDataProvider(data: pixels as CFData),
          let image = CGImage(width: ghost.width * 2, height: ghost.height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: rowBytes * 2, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue), provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent),
          let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return }
    try data.write(to: url)
}
