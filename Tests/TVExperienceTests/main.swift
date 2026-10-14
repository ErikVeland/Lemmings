import Foundation
import LemmingsMobileCore
import LemmingsTVCore
import NxlvKit

@main struct TVExperienceTests {
    enum Failure: Error { case check(String) }
    @MainActor static func main() async throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        var count = 0
        func check(_ condition: @autoclosure () -> Bool, _ name: String) throws {
            guard condition() else { throw Failure.check(name) }; count += 1
        }
        let classic = try ClassicMobileLibrary(directory: root.appendingPathComponent("Sources/Ports/lemmings_dos_1991-07-30"))
        let factories: [() throws -> MobileLevelContent] = [
            { try classic.loadLevel(at: 0) },
            { .init(summary: .init(index: 0, rank: "Classic", number: 1, title: "L2 fixture"), session: Lemmings2MobileSession(runtime: try l2(), engineFingerprint: "l2", levelIdentifier: "l2/1", levelIndex: 0, levelFingerprint: "l2-level")) },
            { .init(summary: .init(index: 0, rank: "Classic", number: 1, title: "L3 fixture"), session: Lemmings3MobileSession(runtime: try l3(), engineFingerprint: "l3", levelIdentifier: "l3/1", levelIndex: 0, levelFingerprint: "l3-level")) }
        ]
        for (index, factory) in factories.enumerated() {
            let content = try factory()
            let game = try TVGameExperience(content: content, owner: "host", scope: "hotseat.fixture")
            let initialSkill = content.session.snapshot.skills[game.selectedControl]
            try check(initialSkill.count > 0 || initialSkill.isUnlimited, "Ready selects available native action \(index)")
            let tick = content.session.snapshot.tick
            game.selectSkill(0); _ = game.assign(); game.step(); _ = game.advance(at: 10)
            try check(game.awaitsFirstStart && game.play.phase == .ready && content.session.snapshot.tick == tick, "Fresh Ready blocks input in engine \(index)")
            try check(game.capabilities.releaseRate == (index == 0), "Rate capability \(index)")
            try check(game.capabilities.rewind == (index == 0), "Rewind capability \(index)")
            try check(game.capabilities.nuke == (index != 2), "Nuke capability \(index)")
            try check(game.capabilities.carriedTools == (index == 2), "Native tools capability \(index)")
            try check(game.resume(), "Explicit Ready starts \(index)")
            try check(game.startNumber == 3 && !game.canInteract, "Fresh start countdown blocks assignments \(index)")
            for second in 0...3 { _ = game.advance(at: Double(second)) }
            try check(game.startNumber == nil && content.session.snapshot.tick == tick, "Countdown holds native simulation \(index)")
            game.selectSkill(0)
            try check(game.play.phase == .running, "Skill selection stays continuous by default \(index)")
            game.preferences.planningOnSkillChange = true
            game.selectSkill(0)
            try check(game.play.phase == .planning, "Explicit pause preference works \(index)")
            try check(game.resume(), "Player resumes after skill planning \(index)")
            _ = game.advance(at: 10); _ = game.advance(at: 10.2)
            try check(content.session.snapshot.tick > tick, "Native clock advances \(index)")
            game.pause(); let pausedTick = content.session.snapshot.tick
            _ = game.advance(at: 80)
            try check(content.session.snapshot.tick == pausedTick, "Planning holds tick \(index)")
            game.step()
            try check(content.session.snapshot.tick == pausedTick + 1, "One forward step \(index)")
            game.setCamera(.precision)
            let draft = try game.prepareCheckpoint()
            game.step()
            let saved = try await Task.detached { try draft.encode() }.value
            let restored = try TVGameExperience(content: factory(), owner: "host", scope: "hotseat.fixture", checkpoint: saved)
            try check(restored.session.snapshot.tick == game.session.snapshot.tick - 1, "Background encoding keeps captured tick \(index)")
            try check(!restored.awaitsFirstStart && restored.play.phase == .ready && restored.session.snapshot.tick == saved.tick, "Restore waits for Resume at exact tick \(index)")
            _ = restored.resume()
            try check(restored.startNumber == nil, "Saved run resumes without fresh countdown \(index)")
            try check(restored.viewport.origin == saved.camera.origin && restored.viewport.zoom == saved.camera.zoom, "Camera restored \(index)")
            do {
                _ = try TVGameExperience(content: factory(), owner: "guest", scope: "hotseat.fixture", checkpoint: saved)
                throw Failure.check("Foreign owner accepted")
            } catch MobileSessionError.changedLevel { count += 1 }
            game.suspend(inactive: true)
            try check(!game.resume(), "Inactive cannot resume \(index)")
            game.becameActive(); try check(game.play.phase == .suspended, "Foreground remains paused \(index)")
            try check(game.resume(), "Explicit foreground resume \(index)")
            game.suspend(interruption: true); try check(!game.resume(), "Audio interruption cannot resume \(index)")
            game.interruptionEnded(); try check(game.play.phase == .suspended && game.resume(), "Audio end requires resume \(index)")
            game.suspend(); try check(game.resume(), "Disconnect can recover without app foreground event \(index)")
        }
        var bindings = ControllerBindings()
        try check(bindings.update(pressed: [.a, .rightTrigger]).isEmpty, "Held input is primed")
        try check(bindings.update(pressed: [.a, .rightTrigger]).isEmpty, "Held input cannot assign again")
        _ = bindings.update(pressed: []); try check(bindings.update(pressed: [.a]) == [.assign], "Fresh assignment press")
        bindings.reset(); try check(bindings.update(pressed: [.a]).isEmpty, "Handover consumes held assignment")
        var preferences = TVPreferences()
        try check(preferences.stickVelocity(0.1) == 0, "Dead zone")
        try check(preferences.stickVelocity(-0.5) == -preferences.stickVelocity(0.5), "Symmetric curve")
        try check(abs(preferences.stickVelocity(0.3)) < abs(preferences.stickVelocity(0.9)) / 8, "Fine aim at centre")
        preferences.aimSensitivity = .infinity; preferences.deadZone = .nan
        try check(preferences.validated.aimSensitivity == 1 && preferences.validated.deadZone == 0.15, "Invalid preferences bounded")
        var seat = MobileHotSeat(host: "host", players: ["host", "guest"])!
        let next = seat.choices(didWin: false).first(where: \.primary)!
        seat.pass(to: next.player)
        let handover = try TVGameExperience(content: factories[0](), owner: seat.turn, scope: seat.scope)
        try check(handover.owner == "guest" && !handover.canInteract && handover.play.phase == .ready, "Handover waits for incoming player")
        let storage = MobileCheckpointStore(url: root.appendingPathComponent(".build/tv-experience-test/current.json"))
        let value = try handover.checkpoint(); try await storage.save(value)
        let read = try await storage.load()
        try check(read?.runID == value.runID && read?.owner == "guest", "Checkpoint keeps turn owner")
        try await storage.retire(runID: value.runID); try await storage.save(value)
        let afterRetirement = try await storage.load()
        try check(afterRetirement == nil, "Late save cannot resurrect completed attempt")
        let crowd = CrowdSession()
        let crowdGame = try TVGameExperience(content: .init(summary: .init(index: 0, rank: "Test", number: 1, title: "Crossing"), session: crowd), owner: "host")
        _ = crowdGame.resume(); crowdGame.pause(); crowdGame.cycleTarget(1)
        try check(crowdGame.target?.id == 1, "Cycling chooses stable actor")
        crowd.positions = [1: .init(x: 42, y: 40), 2: .init(x: 40, y: 40)]
        crowdGame.refreshTarget()
        try check(crowdGame.target?.id == 1, "Crossing cannot steal locked target")
        try check(crowdGame.assign() && crowd.assigned == [1], "Assignment reaches selected actor")
        crowd.positions.removeValue(forKey: 1); crowdGame.refreshTarget()
        try check(crowdGame.target == nil && !crowdGame.assign() && crowd.assigned == [1], "Lost target cannot assign to neighbour")
        crowdGame.cycleTarget(1)
        try check(crowdGame.target?.id == 2 && crowdGame.assign(), "Deliberate cycling selects next survivor")
        print("PASS \(count) TV experience checks across Classic, native L2 and native L3 sessions")
    }
    static func l2() throws -> Lemmings2Runtime {
        let width = 120, height = 80
        var pixels = [UInt8](repeating: 0, count: width * height)
        var solid = [Bool](repeating: false, count: width * height)
        for y in 60..<height { for x in 0..<width { pixels[y * width + x] = 6; solid[y * width + x] = true } }
        let frame = Lemmings2SpriteFrame(x: 0, y: 0, width: 1, height: 1, pixels: [7], opaque: [true])
        let masks = try Lemmings2TerrainMasks(digger: frame, basher: Array(repeating: frame, count: 8), miner: Array(repeating: frame, count: 4), exploder: frame, brick: frame, stacker: Array(repeating: frame, count: 2), platformer: frame)
        return try Lemmings2Runtime(configuration: .init(width: width, height: height, pixels: pixels, solid: solid, palette: [UInt8](repeating: 255, count: 1024), entrance: .init(x: 20, y: 45, width: 1, height: 1), exits: [.init(x: 100, y: 50, width: 16, height: 16)], skills: [.jumper], supplies: [3], total: 2, timeLimit: 120, releaseInterval: 20, terrainMasks: masks, firstReleaseTick: 1))
    }
    static func l3() throws -> Lemmings3Runtime {
        let width = 128, height = 64
        var attributes = [UInt16](repeating: 0x1000, count: width * height)
        for y in 48..<height { for x in 0..<width { attributes[y * width + x] = 0x20 } }
        return try Lemmings3Runtime(configuration: .init(width: width, height: height, attributes: attributes, entrance: .init(x: 20, y: 40), exits: [.init(x: 110, y: 46)], total: 2, releaseInterval: 20, releaseDelay: 0))
    }
}

/// Controllable crowd positions isolate the wrong-actor regression from engine timing.
final class CrowdSession: MobileGameSession {
    let engineIdentifier = "crowd", engineFingerprint = "crowd", levelIdentifier = "crowd/1", levelFingerprint = "crowd/1"
    let levelIndex = 0, ticksPerSecond = 17.0
    let levelSize = MobileSize(width: 160, height: 80)
    var positions: [Int: MobilePoint] = [1: .init(x: 40, y: 40), 2: .init(x: 42, y: 40)]
    var assigned: [Int] = []
    var snapshot: MobileGameSnapshot { .init(tick: 0, released: 2, total: 2, saved: 0, required: 2, remainingSeconds: nil, releaseRate: nil, isComplete: false, didWin: false, isEndingRun: false, skills: [.init(name: "Climber", count: 10)]) }
    func targetCandidates(for control: Int) -> [MobileTargetCandidate] {
        positions.map { .init(id: $0.key, point: $0.value, direction: 1, assignment: .eligible) }
    }
    func assign(control: Int, to target: Int) -> Bool { guard positions[target] != nil else { return false }; assigned.append(target); return true }
    func tick() {}
    func adjustReleaseRate(by delta: Int) -> Bool { false }
    func beginEndRun() -> Bool { false }
    func undoEndRun() -> Bool { false }
    func render(highlight: MobileTargetSelection?) throws -> MobilePixelFrame { throw MobileSessionError.frameUnavailable }
    func checkpointPayload() throws -> Data { Data() }
    func restoreCheckpointPayload(_ data: Data) throws {}
}
