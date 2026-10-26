import Foundation
import LemmingsAppCore
import NxlvKit

/// A bounded input recording. Assets and saved player state never enter the document.
public struct MobileActionReplayDocument: Codable, Sendable {
    public let version: Int
    public let engine: String
    public let engineFingerprint: String
    public let levelFingerprint: String
    public let initialHash: String
    public let finalHash: String
    public let endTick: Int
    public let commands: [LeaderboardActionReplay.Command]

    public init(session: any MobileGameSession, capture: MobileActionCapture) throws {
        version = 1; engine = session.engineIdentifier; engineFingerprint = session.engineFingerprint
        levelFingerprint = session.levelFingerprint
        initialHash = try capture.initial.hash(); finalHash = try capture.final.hash()
        endTick = capture.final.tick; commands = capture.commands
        guard capture.initial.tick == 0 else { throw MobileSessionError.invalidCheckpoint }
        try validate()
    }

    public func validate() throws {
        guard version == 1, !engine.isEmpty, !engineFingerprint.isEmpty, !levelFingerprint.isEmpty,
              initialHash.count == 64, finalHash.count == 64, (0...120_000).contains(endTick),
              commands.count <= 100_000, commands.allSatisfy({ (0...endTick).contains($0.tick) }),
              zip(commands, commands.dropFirst()).allSatisfy({ $0.tick <= $1.tick }) else {
            throw MobileSessionError.invalidCheckpoint
        }
    }

    public static func checked(_ replay: LeaderboardActionReplay, session: any MobileGameSession) throws -> Data {
        guard let initial = session.actionReplayInitial else { throw MobileSessionError.unsupportedControl }
        var cursor = try replay.checked(initial: initial)
        try cursor.seek(to: replay.ticks)
        let document = try Self(session: session,
            capture: .init(initial: initial, final: cursor.state, commands: replay.commands))
        return try JSONEncoder().encode(document)
    }
}

/// Plays a private engine copy through its normal input/audio/render paths, without progress callbacks.
public final class MobileActionReplaySession: MobileGameSession {
    private let document: MobileActionReplayDocument
    private let factory: () -> (any MobileGameSession)?
    private var native: any MobileGameSession
    private var next = 0
    private var uses: [MobileReplaySkillUse] = []
    private var playbackError: Error?
    private var settings: ClassicSettings?
    public var availableGraphics: [ClassicGraphicsSource] { native.availableGraphics }
    public var engineSession: any MobileGameSession { native }
    public var hotSeatGhosts: HotSeatGhostPlayback? {
        get { native.hotSeatGhosts }
        set { native.hotSeatGhosts = newValue }
    }

    public init(document: Data, source: any MobileGameSession) throws {
        guard document.count <= LeaderboardActionReplay.byteLimit else { throw MobileSessionError.invalidCheckpoint }
        let recording = try JSONDecoder().decode(MobileActionReplayDocument.self, from: document)
        try recording.validate()
        guard recording.engine == source.engineIdentifier, recording.engineFingerprint == source.engineFingerprint,
              recording.levelFingerprint == source.levelFingerprint, let initial = source.actionReplayInitial,
              initial.tick == 0, try initial.hash() == recording.initialHash,
              let copy = source.makeReplayClone() else { throw MobileSessionError.changedLevel }
        self.document = recording; factory = { source.makeReplayClone() }; native = copy
        try applyCurrent()
    }

    public var engineIdentifier: String { native.engineIdentifier }
    public var engineFingerprint: String { native.engineFingerprint }
    public var levelIdentifier: String { native.levelIdentifier }
    public var levelIndex: Int { native.levelIndex }
    public var levelFingerprint: String { native.levelFingerprint }
    public var levelSize: MobileSize { native.levelSize }
    public var initialCameraOrigin: MobilePoint { native.initialCameraOrigin }
    public var entrancePoint: MobilePoint { native.entrancePoint }
    public var goalPoint: MobilePoint { native.goalPoint }
    public var ticksPerSecond: Double { native.ticksPerSecond }
    public var renderScale: Double { native.renderScale }
    public var panelFrame: MobilePixelFrame? { native.panelFrame }
    public var spriteActorIDs: [Int] { native.spriteActorIDs }
    public var activeLemmingCount: Int { native.activeLemmingCount }
    public var lostLemmingCount: Int { native.lostLemmingCount }
    public var explosions: [MobileExplosion] { native.explosions }
    public var bombCountdowns: [MobileBombCountdown] { native.bombCountdowns }
    public var nukeRemainingTicks: Int? { native.nukeRemainingTicks }
    public var allNukeExplosionsPlayed: Bool { native.allNukeExplosionsPlayed }
    public var selectionSprite: MobileSpriteHighlight? { native.selectionSprite }
    public var assignmentSprite: MobileSpriteHighlight? { native.assignmentSprite }
    public var assignmentProgress: Double? { native.assignmentProgress }
    public var assignedSkillCount: Int { native.assignedSkillCount }
    public var assignedSkills: [String: Int] { native.assignedSkills }
    public var supportsRewind: Bool { true }
    public var isReadOnly: Bool { true }
    public var replayEndTick: Int? { document.endTick }
    public var replaySkillUses: [MobileReplaySkillUse] { Array(uses.suffix(3)) }
    public var replayMoveNavigation: ReplayMoveNavigation {
        .init(ticks: document.commands.filter { isSkill($0) }.map(\.tick))
    }
    public var snapshot: MobileGameSnapshot {
        let value = native.snapshot
        return .init(tick: value.tick, released: value.released, total: value.total, saved: value.saved,
            required: value.required, remainingSeconds: value.remainingSeconds, releaseRate: value.releaseRate,
            isComplete: value.isComplete || value.tick >= document.endTick || playbackError != nil,
            didWin: value.didWin, isEndingRun: value.isEndingRun, skills: value.skills)
    }
    public func tick() {
        guard !snapshot.isComplete else { return }
        native.tick()
        do { try applyCurrent() } catch { playbackError = error }
    }
    private func isSkill(_ command: LeaderboardActionReplay.Command) -> Bool {
        command.action == "assign" || (engineIdentifier == "lemmings3" && Lemmings3Runtime.Action(rawValue: command.action) != nil)
    }
    private func applyCurrent() throws {
        while next < document.commands.count, document.commands[next].tick == native.snapshot.tick {
            let command = document.commands[next]
            let name = command.skill.flatMap { native.snapshot.skills.indices.contains($0) ? native.snapshot.skills[$0].name : nil }
            try apply(command)
            if isSkill(command) { uses.append(.init(tick: command.tick, name: name ?? command.action.capitalized)) }
            next += 1
        }
        if native.snapshot.tick == document.endTick {
            guard next == document.commands.count, let capture = try native.actionCapture(),
                  try capture.final.hash() == document.finalHash else { throw MobileSessionError.invalidCheckpoint }
        } else if native.snapshot.isComplete { throw MobileSessionError.invalidCheckpoint }
    }
    private func apply(_ command: LeaderboardActionReplay.Command) throws {
        var accepted = false
        switch command.action {
        case "assign":
            if let control = command.skill, let target = command.lemming { accepted = native.assign(control: control, to: target) }
        case "bonusSkill", "bonusTool":
            if let choice = native.extraSkillChoices.first(where: {
                command.action == "bonusTool" ? $0.target == command.lemming : $0.control == command.skill
            }) { accepted = native.grantExtraSkill(choice) }
        case "nuke", "abort": accepted = native.beginEndRun()
        case "fan", "aim":
            if let game = native as? Lemmings2MobileSession, let x = command.x, let y = command.y, let held = command.held {
                let point = MobilePoint(x: Double(x), y: Double(y))
                if command.action == "fan" { game.setFan(at: point, active: held) } else { game.setAim(at: point, held: held) }
                accepted = true
            }
        case "releasePointer":
            if let game = native as? Lemmings2MobileSession { game.releasePointerInput(); accepted = true }
        case "machine", "chain":
            if let game = native as? Lemmings2MobileSession, let x = command.x, let y = command.y {
                accepted = game.interact(at: .init(x: Double(x), y: Double(y)))
            }
        case "rate":
            if let game = native as? NeoLemmixMobileSession, let delta = command.value {
                accepted = game.setSpawnInterval(game.actualSpawnInterval + delta)
            }
        default:
            if let game = native as? Lemmings3MobileSession, let action = Lemmings3Runtime.Action(rawValue: command.action),
               let target = command.lemming, let control = Lemmings3Runtime.Action.allCases.firstIndex(of: action) {
                if action == .use, let raw = command.direction, let direction = Lemmings3Runtime.Direction(rawValue: raw) {
                    accepted = game.useTool(direction: direction, to: target)
                } else { accepted = game.assign(control: control, to: target) }
            }
        }
        guard accepted else { throw MobileSessionError.invalidCheckpoint }
    }
    public func seekReplay(to tick: Int) -> Bool {
        guard (0...document.endTick).contains(tick) else { return false }
        do {
            if tick < native.snapshot.tick || playbackError != nil {
                let ghosts = native.hotSeatGhosts
                guard let copy = factory() else { return false }
                native = copy; native.hotSeatGhosts = ghosts
                if let settings { native.applySettings(settings) }
                next = 0; uses.removeAll(keepingCapacity: true); playbackError = nil
                try applyCurrent()
            }
            while native.snapshot.tick < tick, !snapshot.isComplete { self.tick() }
            _ = native.drainSoundCues(); _ = native.drainLemmings2SoundRequests()
            return playbackError == nil && native.snapshot.tick == tick
        } catch { playbackError = error; return false }
    }
    public func rewind(seconds: Double) -> Bool {
        guard seconds.isFinite, seconds >= 0 else { return false }
        return seekReplay(to: max(0, snapshot.tick - Int(min(Double(snapshot.tick), seconds * ticksPerSecond))))
    }
    public func stepBackward() -> Bool { snapshot.tick > 0 && seekReplay(to: snapshot.tick - 1) }
    public func stepForward() -> Bool { guard !snapshot.isComplete else { return false }; tick(); return playbackError == nil }
    public func render(highlight: MobileTargetSelection?) throws -> MobilePixelFrame {
        if let playbackError { throw playbackError }
        return try native.render(highlight: highlight)
    }
    public func applySettings(_ settings: ClassicSettings) { self.settings = settings; native.applySettings(settings) }
    public func skillCursorFrame(control: Int) -> MobilePixelFrame? { native.skillCursorFrame(control: control) }
    public func skillCursorRemaining(control: Int, target: Int?) -> Int? { native.skillCursorRemaining(control: control, target: target) }
    public func spriteHighlight(for actor: Int) -> MobileSpriteHighlight? { native.spriteHighlight(for: actor) }
    public func drainSoundCues() -> [PositionedSoundCue] { native.drainSoundCues() }
    public func drainLemmings2SoundRequests() -> [Lemmings2SoundRequest] { native.drainLemmings2SoundRequests() }
    public func targetCandidates(for control: Int) -> [MobileTargetCandidate] { [] }
    public func assign(control: Int, to target: Int) -> Bool { false }
    public func adjustReleaseRate(by delta: Int) -> Bool { false }
    public func beginEndRun() -> Bool { false }
    public func undoEndRun() -> Bool { false }
    public func checkpointPayload() throws -> Data { throw MobileSessionError.unsupportedControl }
    public func restoreCheckpointPayload(_ data: Data) throws { throw MobileSessionError.unsupportedControl }
    public func replayDocument() throws -> Data? { try JSONEncoder().encode(document) }
}
