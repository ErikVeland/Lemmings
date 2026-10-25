import Foundation
import LemmingsAppCore
import NxlvKit

public typealias Lemmings2MobileRenderer = (
    _ runtime: Lemmings2Runtime,
    _ highlight: MobileTargetSelection?
) throws -> MobilePixelFrame

/// Draws earlier Hot Seat turns behind the live lemmings.
public typealias Lemmings2MobileGhostRenderer = (
    _ runtime: Lemmings2Runtime,
    _ highlight: MobileTargetSelection?,
    _ ghosts: [MobileReplayGhost<Lemmings2Runtime>]
) throws -> MobilePixelFrame

public final class Lemmings2MobileSession: MobileGameSession {
    public var artworkRenderer: ((Lemmings2Runtime, MobileTargetSelection?, [MobileReplayGhost<Lemmings2Runtime>], Bool) throws -> MobilePixelFrame)?
    private var macArtwork = false
    private let macSpriteCache = MobileSequelArtworkCache()
    public var renderScale: Double { macArtwork && artworkRenderer != nil ? 2 : 1 }
    public var availableGraphics: [ClassicGraphicsSource] { artworkRenderer == nil ? [] : [.dosVGA, .macintosh] }
    private func artworkSprite(_ value: MobileSpriteHighlight?) -> MobileSpriteHighlight? {
        guard macArtwork else { return value }
        return macSpriteCache.sprite(value, category: value?.cacheKey.contains("walker-") == true ? .lemmings2Walker : .sprite)
    }
    public func makeReplayClone() -> (any MobileGameSession)? {
        let copy = Lemmings2MobileSession(runtime: initial, engineFingerprint: engineFingerprint,
            levelIdentifier: levelIdentifier, levelIndex: levelIndex, levelFingerprint: levelFingerprint,
            renderer: renderer, ghostRenderer: ghostRenderer, soundBank: soundBank)
        copy.skillCursorFrames = skillCursorFrames
        copy.spriteProvider = spriteProvider
        copy.artworkRenderer = artworkRenderer
        copy.applySettings(spriteFeedback.settings)
        return copy
    }

    private var spriteFeedback = MobileSpriteFeedback<Lemmings2Runtime>()
    public var spriteProvider: ((Lemmings2Runtime, Int) -> MobileSpriteHighlight?)? {
        get { spriteFeedback.provider }
        set { spriteFeedback.provider = newValue }
    }
    public func applySettings(_ settings: ClassicSettings) {
        spriteFeedback.settings = settings
        macArtwork = settings.graphics == .macintosh || settings.graphics == .macintoshMonochrome
    }
    public func spriteHighlight(for actor: Int) -> MobileSpriteHighlight? {
        artworkSprite(spriteFeedback.sprite(in: runtime, id: actor, tick: runtime.tick, ticksPerSecond: ticksPerSecond))
    }
    public var selectionSprite: MobileSpriteHighlight? {
        artworkSprite(spriteFeedback.selection(in: runtime, tick: runtime.tick, ticksPerSecond: ticksPerSecond))
    }
    public var assignmentProgress: Double? { spriteFeedback.progress(at: runtime.tick, ticksPerSecond: ticksPerSecond) }
    public var assignmentSprite: MobileSpriteHighlight? {
        artworkSprite(spriteFeedback.acknowledgement(in: runtime, tick: runtime.tick, ticksPerSecond: ticksPerSecond))
    }

    public var familiarNamesStore: FamiliarNamesStore? = .shared
    private enum Input: Codable, Sendable {
        case assign(tick: Int, control: Int, target: Int)
        case endRun(tick: Int)
        case fan(tick: Int, x: Int, y: Int, active: Bool)
        case bonusSkill(tick: Int, control: Int)
        case aim(tick: Int, x: Int, y: Int, held: Bool)
        case machine(tick: Int, x: Int, y: Int)
        case chain(tick: Int, x: Int, y: Int)
        case releasePointer(tick: Int)
    }

    private struct Checkpoint: Codable, Sendable {
        var version = 1
        let initialFingerprint: String
        let tick: Int
        let inputs: [Input]
        var rewindCount: Int? = nil
        var usedRewind: Bool? = nil
        var nukeCount: Int? = nil
        var undoCount: Int? = nil
        var bonusSkillID: String? = nil
    }

    public var goalPoint: MobilePoint {
        guard let point = initial.configuration.exits.first else { return entrancePoint }
        return .init(x: Double(point.x + point.width / 2), y: Double(point.y + point.height / 2))
    }

    public var lostLemmingCount: Int { runtime.lost }
    public let engineIdentifier = "lemmings2"
    public let engineFingerprint: String
    public let levelIdentifier: String
    public let levelIndex: Int
    public let levelFingerprint: String
    public let levelSize: MobileSize
    public let ticksPerSecond = Lemmings2Runtime.ticksPerSecond

    public var skillCursorFrames: [MobilePixelFrame?] = []
    public func skillCursorFrame(control: Int) -> MobilePixelFrame? {
        skillCursorFrames.indices.contains(control) ? skillCursorFrames[control] : nil
    }

    private let initial: Lemmings2Runtime
    private let renderer: Lemmings2MobileRenderer?
    private let ghostRenderer: Lemmings2MobileGhostRenderer?
    public var hotSeatGhosts: HotSeatGhostPlayback?
    private var runtime: Lemmings2Runtime
    public let soundBank: Lemmings2SoundBank?
    private var soundRequests: [Lemmings2SoundRequest] = []
    private var explosionTimeline = PixelExplosionTimeline()
    public var explosions: [MobileExplosion] {
        explosionTimeline.update(tick: runtime.tick, bursts: PixelExplosion.lemmings2(runtime))
        return explosionTimeline.bursts.map { MobileExplosion($0, at: runtime.tick) }
    }
    private var beforeEndRun: Lemmings2Runtime?
    private var inputs: [Input] = []
    private var pointerAim: (x: Int, y: Int, held: Bool)?
    private let onCompletion: ((Lemmings2Runtime) -> Void)?
    private var didNotifyCompletion = false
    public private(set) var rewindCount = 0
    public private(set) var usedRewind = false
    public private(set) var nukeCount = 0
    public private(set) var undoCount = 0
    public private(set) var bonusSkillID: String?
    public var initialRuntime: Lemmings2Runtime { initial }
    public var existingLevelSkills: Set<String> {
        Set(zip(initial.configuration.skills, initial.configuration.supplies)
            .filter { $0.1 > 0 }.map { Self.skillKey($0.0.name) })
    }
    private static func skillKey(_ name: String) -> String {
        name.lowercased().replacingOccurrences(of: " ", with: "_")
    }
    public var extraSkillChoices: [MobileExtraSkillChoice] {
        guard bonusSkillID == nil else { return [] }
        return runtime.configuration.skills.enumerated().compactMap { index, skill in
            guard runtime.canGrantBonusSkill(slot: index) else { return nil }
            return .init(skillID: Self.skillKey(skill.name), title: SkillVocabulary.title(skill.name), control: index)
        }
    }
    @discardableResult public func grantExtraSkill(_ choice: MobileExtraSkillChoice) -> Bool {
        guard extraSkillChoices.contains(choice), runtime.grantBonusSkill(slot: choice.control) else { return false }
        inputs.append(.bonusSkill(tick: runtime.tick, control: choice.control))
        bonusSkillID = choice.skillID
        return true
    }
    @discardableResult public func retainExtraSkillUse(_ skillID: String) -> Bool {
        guard existingLevelSkills.contains(skillID), bonusSkillID == nil || bonusSkillID == skillID else { return false }
        bonusSkillID = skillID
        return true
    }
    public var assignedSkills: [String: Int] {
        inputs.reduce(into: [:]) { counts, input in
            guard case let .assign(_, control, _) = input,
                  runtime.configuration.skills.indices.contains(control) else { return }
            counts[Self.skillKey(runtime.configuration.skills[control].name), default: 0] += 1
        }
    }

    public init(
        runtime: Lemmings2Runtime,
        engineFingerprint: String,
        levelIdentifier: String,
        levelIndex: Int,
        levelFingerprint: String,
        renderer: Lemmings2MobileRenderer? = nil,
        ghostRenderer: Lemmings2MobileGhostRenderer? = nil,
        soundBank: Lemmings2SoundBank? = nil,
        onCompletion: ((Lemmings2Runtime) -> Void)? = nil
    ) {
        self.ghostRenderer = ghostRenderer
        initial = runtime
        self.runtime = runtime
        self.engineFingerprint = engineFingerprint
        self.levelIdentifier = levelIdentifier
        self.levelIndex = levelIndex
        self.levelFingerprint = levelFingerprint
        self.renderer = renderer
        self.soundBank = soundBank
        self.onCompletion = onCompletion
        levelSize = MobileSize(
            width: Double(runtime.configuration.width),
            height: Double(runtime.configuration.height)
        )
    }

    public var entrancePoint: MobilePoint {
        let point = initial.configuration.entrance
        return MobilePoint(x: Double(point.x), y: Double(point.y))
    }

    public var activeLemmingCount: Int { runtime.lemmings.reduce(0) { $0 + ($1.active ? 1 : 0) } }
    public var assignedSkillCount: Int {
        inputs.filter { if case .assign = $0 { return true }; return false }.count
    }
    public var supportsRewind: Bool { true }

    public var isFanActive: Bool {
        for input in inputs.reversed() {
            if case .releasePointer = input { return false }
            if case let .fan(_, _, _, active) = input { return active }
        }
        return false
    }

    /// Fan input belongs to the native replay, so checkpoints and rewinds keep its physics.
    public func setFan(at point: MobilePoint, active: Bool) {
        guard !runtime.isComplete, !runtime.isNuking || !active,
              point.x.isFinite, point.y.isFinite else { return }
        let x = Int(min(levelSize.width - 1, max(0, point.x)))
        let y = Int(min(levelSize.height - 1, max(0, point.y)))
        if let previous = inputs.last, case let .fan(_, oldX, oldY, oldActive) = previous,
           oldActive == active, (!active || (oldX == x && oldY == y)) { return }
        if !active && !isFanActive { return }
        runtime.setFan(x: x, y: y, active: active)
        inputs.append(.fan(tick: runtime.tick, x: x, y: y, active: active))
    }

    public func setAim(at point: MobilePoint, held: Bool) {
        guard !runtime.isComplete, !runtime.isNuking, point.x.isFinite, point.y.isFinite else { return }
        let x = Int(min(levelSize.width - 1, max(0, point.x)))
        let y = Int(min(levelSize.height - 1, max(0, point.y)))
        guard pointerAim?.x != x || pointerAim?.y != y || pointerAim?.held != held else { return }
        pointerAim = (x, y, held)
        runtime.setAim(x: x, y: y, held: held)
        inputs.append(.aim(tick: runtime.tick, x: x, y: y, held: held))
    }

    @discardableResult public func interact(at point: MobilePoint) -> Bool {
        guard !runtime.isComplete, !runtime.isNuking, point.x.isFinite, point.y.isFinite else { return false }
        let x = Int(min(levelSize.width - 1, max(0, point.x)))
        let y = Int(min(levelSize.height - 1, max(0, point.y)))
        if runtime.moveMachine(x: x, y: y) { inputs.append(.machine(tick: runtime.tick, x: x, y: y)) }
        else if runtime.releaseChain(x: x, y: y) { inputs.append(.chain(tick: runtime.tick, x: x, y: y)) }
        else { return false }
        appendSoundRequests(runtime.drainSoundEvents())
        return true
    }

    public func releasePointerInput() {
        guard pointerAim != nil || isFanActive else { return }
        runtime.releasePointerInput()
        pointerAim = nil
        inputs.append(.releasePointer(tick: runtime.tick))
    }

    public var snapshot: MobileGameSnapshot {
        MobileGameSnapshot(
            tick: runtime.tick,
            released: runtime.released,
            total: runtime.configuration.total,
            saved: runtime.saved,
            required: 1,
            remainingSeconds: runtime.remainingSeconds,
            releaseRate: nil,
            isComplete: runtime.isComplete,
            didWin: runtime.didWin,
            isEndingRun: runtime.isNuking,
            skills: runtime.configuration.skills.enumerated().map { index, skill in
                MobileSkillState(name: skill.name, count: runtime.supplies[index])
            }
        )
    }

    public func tick() {
        runtime.step()
        appendSoundRequests(runtime.drainSoundEvents())
        explosionTimeline.update(tick: runtime.tick, bursts: PixelExplosion.lemmings2(runtime))
        if runtime.isComplete, !didNotifyCompletion {
            didNotifyCompletion = true
            onCompletion?(runtime)
        }
        if !runtime.isNuking { beforeEndRun = nil }
    }

    public func targetWallDirection(for target: Int) -> Int? {
        guard let lemming = runtime.lemmings.first(where: { $0.id == target }) else { return nil }
        return LemmingApproachTargeting.wallDirection(x: lemming.x, footY: lemming.y, isSolid: runtime.isSolid)
    }

    public func targetCandidates(for control: Int) -> [MobileTargetCandidate] {
        guard runtime.configuration.skills.indices.contains(control) else { return [] }
        let results = runtime.assignmentResults(slot: control)
        return runtime.lemmings.enumerated().compactMap { index, lemming in
            guard lemming.active else { return nil }
            return MobileTargetCandidate(
                id: lemming.id,
                point: MobilePoint(x: Double(lemming.x), y: Double(lemming.y - 5)),
                direction: lemming.direction,
                assignment: results[index] ? .eligible : .unavailable,
                isBuilding: lemming.state == .building,
                pointerBounds: MobileRect(x: -9, y: -12, width: 18, height: 24)
            )
        }
    }

    @discardableResult
    public func assign(control: Int, to target: Int) -> Bool {
        guard runtime.assign(slot: control, to: target) else { return false }
        appendSoundRequests(runtime.drainSoundEvents())
        inputs.append(.assign(tick: runtime.tick, control: control, target: target))
        spriteFeedback.assigned(to: target, tick: runtime.tick)
        return true
    }

    public func drainLemmings2SoundRequests() -> [Lemmings2SoundRequest] {
        defer { soundRequests.removeAll(keepingCapacity: true) }
        return soundRequests
    }

    private func appendSoundRequests(_ requests: [Lemmings2SoundRequest]) {
        soundRequests += requests
        if soundRequests.count > 256 { soundRequests.removeFirst(soundRequests.count - 256) }
    }

    public func adjustReleaseRate(by delta: Int) -> Bool { false }

    @discardableResult
    public func beginEndRun() -> Bool {
        guard !runtime.isComplete, !runtime.isNuking, beforeEndRun == nil else { return false }
        beforeEndRun = runtime
        runtime.nuke()
        appendSoundRequests(runtime.drainSoundEvents())
        inputs.append(.endRun(tick: runtime.tick))
        nukeCount += 1
        return true
    }

    @discardableResult
    public func undoEndRun() -> Bool {
        guard let beforeEndRun else { return false }
        runtime = beforeEndRun
        soundRequests.removeAll(keepingCapacity: true)
        explosionTimeline.reset()
        spriteFeedback.reset()
        pointerAim = nil
        self.beforeEndRun = nil
        if let index = inputs.lastIndex(where: { if case .endRun = $0 { true } else { false } }) {
            inputs.removeSubrange(index...)
        }
        pointerAim = nil
        usedRewind = true
        undoCount += 1
        return true
    }

    public func render(highlight: MobileTargetSelection?) throws -> MobilePixelFrame {
        spriteFeedback.selected = highlight?.id
        if let artworkRenderer {
            let ghosts = hotSeatGhosts?.states(at: runtime.tick) { state -> Lemmings2Runtime? in
                if case let .lemmings2(ghost) = state { return ghost }; return nil
            } ?? []
            return try artworkRenderer(runtime, highlight, ghosts, macArtwork)
        }
        guard let renderer else { throw MobileSessionError.frameUnavailable }
        if let ghostRenderer, hotSeatGhosts != nil {
            let ghosts = hotSeatGhosts!.states(at: runtime.tick) { state -> Lemmings2Runtime? in
                if case let .lemmings2(ghost) = state { return ghost }
                return nil
            }
            if !ghosts.isEmpty { return try ghostRenderer(runtime, highlight, ghosts) }
        }
        return try renderer(runtime, highlight)
    }

    public var actionReplayInitial: ActionReplayState? { .lemmings2(initial) }

    public var lemmingInspection: LemmingInspection? {
        guard let capture = actionCapture() else { return nil }
        return try? LemmingInspection(initial: capture.initial, current: capture.final, commands: capture.commands, familiarNames: familiarNamesStore)
    }

    public func actionCapture() -> MobileActionCapture? {
        let commands = inputs.map { input -> LeaderboardActionReplay.Command in
            switch input {
            case let .assign(tick, control, target): .init(tick: tick, action: "assign", lemming: target, skill: control)
            case let .endRun(tick): .init(tick: tick, action: "nuke")
            case let .fan(tick, x, y, active): .init(tick: tick, action: "fan", x: x, y: y, held: active)
            case let .bonusSkill(tick, control): .init(tick: tick, action: "bonusSkill", skill: control)
            case let .aim(tick, x, y, held): .init(tick: tick, action: "aim", x: x, y: y, held: held)
            case let .machine(tick, x, y): .init(tick: tick, action: "machine", x: x, y: y)
            case let .chain(tick, x, y): .init(tick: tick, action: "chain", x: x, y: y)
            case let .releasePointer(tick): .init(tick: tick, action: "releasePointer")
            }
        }
        return .init(initial: .lemmings2(initial), final: .lemmings2(runtime), commands: commands)
    }

    public func checkpointPayload() throws -> Data {
        try prepareCheckpointPayload().encode()
    }

    public func prepareCheckpointPayload() -> MobileCheckpointPayload {
        MobileCheckpointPayload(Checkpoint(
            initialFingerprint: levelFingerprint,
            tick: runtime.tick,
            inputs: inputs,
            rewindCount: rewindCount,
            usedRewind: usedRewind,
            nukeCount: nukeCount,
            undoCount: undoCount,
            bonusSkillID: bonusSkillID
        ))
    }

    public func restoreCheckpointPayload(_ data: Data) throws {
        let checkpoint = try JSONDecoder().decode(Checkpoint.self, from: data)
        guard checkpoint.version == 1 else { throw MobileCheckpointError.version }
        guard checkpoint.initialFingerprint == levelFingerprint else { throw MobileSessionError.changedLevel }
        let (restored, restoredBeforeEndRun) = try replay(inputs: checkpoint.inputs, through: checkpoint.tick)
        runtime = restored
        soundRequests.removeAll(keepingCapacity: true)
        explosionTimeline.reset()
        spriteFeedback.reset()
        pointerAim = nil
        didNotifyCompletion = false
        inputs = checkpoint.inputs
        beforeEndRun = restoredBeforeEndRun
        rewindCount = checkpoint.rewindCount ?? 0
        usedRewind = checkpoint.usedRewind ?? false
        nukeCount = checkpoint.nukeCount ?? checkpoint.inputs.reduce(into: 0) { count, input in
            if case .endRun = input { count += 1 }
        }
        undoCount = checkpoint.undoCount ?? 0
        bonusSkillID = checkpoint.bonusSkillID
    }

    @discardableResult
    public func rewind(seconds: Double) -> Bool {
        guard seconds.isFinite, seconds >= 0 else { return false }
        let distance = Int(min(Double(runtime.tick), (seconds * ticksPerSecond).rounded()))
        guard distance > 0 else { return false }
        soundRequests.removeAll(keepingCapacity: true)
        return move(to: runtime.tick - distance)
    }

    @discardableResult
    public func stepBackward() -> Bool {
        soundRequests.removeAll(keepingCapacity: true)
        return move(to: runtime.tick - 1)
    }

    @discardableResult
    public func stepForward() -> Bool {
        guard !runtime.isComplete else { return false }
        tick()
        return true
    }

    public func resumeFromCurrentTick() {}

    private func move(to tick: Int) -> Bool {
        guard tick >= 0, tick < runtime.tick else { return false }
        do {
            let retainedInputs = inputs.filter { inputTick($0) <= tick }
            let (restored, restoredBeforeEndRun) = try replay(inputs: retainedInputs, through: tick)
            runtime = restored
            inputs = retainedInputs
            beforeEndRun = restoredBeforeEndRun
            explosionTimeline.reset()
            spriteFeedback.reset()
            pointerAim = nil
            didNotifyCompletion = false
            usedRewind = true
            rewindCount += 1
            return true
        } catch {
            return false
        }
    }

    private func replay(inputs: [Input], through tick: Int) throws -> (Lemmings2Runtime, Lemmings2Runtime?) {
        var restored = initial
        var restoredBeforeEndRun: Lemmings2Runtime?
        var inputIndex = 0
        while restored.tick <= tick {
            while inputIndex < inputs.count, inputTick(inputs[inputIndex]) == restored.tick {
                switch inputs[inputIndex] {
                case let .assign(_, control, target):
                    guard restored.assign(slot: control, to: target) else { throw MobileSessionError.invalidCheckpoint }
                case .endRun:
                    guard !restored.isNuking else { throw MobileSessionError.invalidCheckpoint }
                    restoredBeforeEndRun = restored
                    restored.nuke()
                case let .fan(_, x, y, active):
                    restored.setFan(x: x, y: y, active: active)
                case let .aim(_, x, y, held): restored.setAim(x: x, y: y, held: held)
                case let .machine(_, x, y):
                    guard restored.moveMachine(x: x, y: y) else { throw MobileSessionError.invalidCheckpoint }
                case let .chain(_, x, y):
                    guard restored.releaseChain(x: x, y: y) else { throw MobileSessionError.invalidCheckpoint }
                case .releasePointer: restored.releasePointerInput()
                case let .bonusSkill(_, control):
                    guard restored.grantBonusSkill(slot: control) else { throw MobileSessionError.invalidCheckpoint }
                }
                inputIndex += 1
            }
            if restored.tick == tick { break }
            guard !restored.isComplete else { throw MobileSessionError.invalidCheckpoint }
            restored.step()
            _ = restored.drainSoundEvents()
        }
        guard restored.tick == tick, inputIndex == inputs.count, !restored.isComplete else {
            throw MobileSessionError.invalidCheckpoint
        }
        return (restored, restoredBeforeEndRun)
    }

    private func inputTick(_ input: Input) -> Int {
        switch input {
        case let .assign(tick, _, _), let .endRun(tick), let .fan(tick, _, _, _), let .bonusSkill(tick, _), let .aim(tick, _, _, _), let .machine(tick, _, _), let .chain(tick, _, _), let .releasePointer(tick): tick
        }
    }

    public func releaseTransientResources() {}
}

public typealias Lemmings3MobileRenderer = (
    _ runtime: Lemmings3Runtime,
    _ highlight: MobileTargetSelection?
) throws -> MobilePixelFrame

/// Draws earlier Hot Seat turns behind the live lemmings.
public typealias Lemmings3MobileGhostRenderer = (
    _ runtime: Lemmings3Runtime,
    _ highlight: MobileTargetSelection?,
    _ ghosts: [MobileReplayGhost<Lemmings3Runtime>]
) throws -> MobilePixelFrame

public final class Lemmings3MobileSession: MobileGameSession {
    public var artworkRenderer: ((Lemmings3Runtime, MobileTargetSelection?, [MobileReplayGhost<Lemmings3Runtime>], Bool) throws -> MobilePixelFrame)?
    private var macArtwork = false
    private let macSpriteCache = MobileSequelArtworkCache()
    public var renderScale: Double { macArtwork && artworkRenderer != nil ? 2 : 1 }
    public var availableGraphics: [ClassicGraphicsSource] { artworkRenderer == nil ? [] : [.dosVGA, .macintosh] }
    private func artworkSprite(_ value: MobileSpriteHighlight?) -> MobileSpriteHighlight? {
        guard macArtwork else { return value }
        return macSpriteCache.sprite(value, category: value?.cacheKey.contains("walker-") == true ? .lemmings2Walker : .sprite)
    }
    public func makeReplayClone() -> (any MobileGameSession)? {
        let copy = Lemmings3MobileSession(runtime: initial, engineFingerprint: engineFingerprint,
            levelIdentifier: levelIdentifier, levelIndex: levelIndex, levelFingerprint: levelFingerprint,
            panelFrame: panelFrame, directionPickerFrames: directionPickerFrames, renderer: renderer,
            ghostRenderer: ghostRenderer, soundBank: soundBank)
        copy.spriteProvider = spriteProvider
        copy.artworkRenderer = artworkRenderer
        copy.applySettings(spriteFeedback.settings)
        return copy
    }

    private var spriteFeedback = MobileSpriteFeedback<Lemmings3Runtime>()
    public var spriteProvider: ((Lemmings3Runtime, Int) -> MobileSpriteHighlight?)? {
        get { spriteFeedback.provider }
        set { spriteFeedback.provider = newValue }
    }
    public func applySettings(_ settings: ClassicSettings) {
        spriteFeedback.settings = settings
        macArtwork = settings.graphics == .macintosh || settings.graphics == .macintoshMonochrome
    }
    public func spriteHighlight(for actor: Int) -> MobileSpriteHighlight? {
        artworkSprite(spriteFeedback.sprite(in: runtime, id: actor, tick: runtime.tick, ticksPerSecond: ticksPerSecond))
    }
    public var selectionSprite: MobileSpriteHighlight? {
        artworkSprite(spriteFeedback.selection(in: runtime, tick: runtime.tick, ticksPerSecond: ticksPerSecond))
    }
    public var assignmentProgress: Double? { spriteFeedback.progress(at: runtime.tick, ticksPerSecond: ticksPerSecond) }
    public var assignmentSprite: MobileSpriteHighlight? {
        artworkSprite(spriteFeedback.acknowledgement(in: runtime, tick: runtime.tick, ticksPerSecond: ticksPerSecond))
    }

    public var familiarNamesStore: FamiliarNamesStore? = .shared
    private let skillStates = Lemmings3Runtime.Action.allCases.map {
        MobileSkillState(name: $0.rawValue.capitalized, count: 0, isUnlimited: true)
    }
    private struct Input: Codable, Sendable {
        let tick: Int
        let action: String
        let target: Int?
        var direction: String?
        var tool: Int? = nil
    }

    private struct Checkpoint: Codable, Sendable {
        var version = 1
        let initialFingerprint: String
        let tick: Int
        let inputs: [Input]
        var rewindCount: Int? = nil
        var usedRewind: Bool? = nil
        var bonusSkillID: String? = nil
    }

    public var goalPoint: MobilePoint {
        guard let point = initial.configuration.exits.first else { return entrancePoint }
        return .init(x: Double(point.x + 4), y: Double(point.y + 1))
    }

    public let engineIdentifier = "lemmings3"
    public let engineFingerprint: String
    public let levelIdentifier: String
    public let levelIndex: Int
    public let levelFingerprint: String
    public let levelSize: MobileSize
    public let ticksPerSecond = Lemmings3Runtime.ticksPerSecond
    public let panelFrame: MobilePixelFrame?
    public let directionPickerFrames: [MobilePixelFrame]

    public func skillCursorFrame(control: Int) -> MobilePixelFrame? {
        guard (0..<5).contains(control), let panelFrame else { return nil }
        return try? panelFrame.cropped(around: .init(x: Double(control * 35) + 17.5, y: 20), width: 35, height: 40)
    }
    public func skillCursorRemaining(control: Int, target: Int?) -> Int? {
        guard Lemmings3Runtime.Action.allCases.indices.contains(control),
              Lemmings3Runtime.Action.allCases[control] == .use, let target else { return nil }
        return runtime.lemmings.first { $0.id == target && $0.active }?.quantity
    }

    private let initial: Lemmings3Runtime
    private let renderer: Lemmings3MobileRenderer?
    private let ghostRenderer: Lemmings3MobileGhostRenderer?
    public var hotSeatGhosts: HotSeatGhostPlayback?
    private var runtime: Lemmings3Runtime
    public let soundBank: Lemmings3SoundBank?
    private var soundCues: [PositionedSoundCue] = []
    private var explosionTimeline = PixelExplosionTimeline()
    public var explosions: [MobileExplosion] {
        explosionTimeline.update(tick: runtime.tick, bursts: PixelExplosion.lemmings3(runtime))
        return explosionTimeline.bursts.map { MobileExplosion($0, at: runtime.tick) }
    }
    private var inputs: [Input] = []
    private let onCompletion: ((Lemmings3Runtime) -> Void)?
    private var didNotifyCompletion = false
    public private(set) var rewindCount = 0
    public private(set) var usedRewind = false
    public private(set) var bonusSkillID: String?
    public var initialRuntime: Lemmings3Runtime { initial }
    public var existingLevelSkills: Set<String> {
        Set(initial.configuration.pickups.map(\.tool).filter { $0 != .clock }.map { String(describing: $0) })
            .union(initial.lemmings.compactMap(\.tool).filter { $0 != .clock }.map { String(describing: $0) })
    }
    public var extraSkillChoices: [MobileExtraSkillChoice] {
        guard bonusSkillID == nil else { return [] }
        return runtime.lemmings.compactMap { lemming in
            guard runtime.canGrantBonusTool(to: lemming.id), let tool = lemming.tool else { return nil }
            let name = SkillVocabulary.title(String(describing: tool))
            return .init(skillID: String(describing: tool), title: L10n.text("\(name) - Lemming \(lemming.id + 1)"),
                control: Lemmings3Runtime.Action.allCases.firstIndex(of: .use) ?? 3, target: lemming.id)
        }
    }
    @discardableResult public func grantExtraSkill(_ choice: MobileExtraSkillChoice) -> Bool {
        guard extraSkillChoices.contains(choice), let target = choice.target,
              let tool = runtime.lemmings.first(where: { $0.id == target })?.tool,
              runtime.grantBonusTool(to: target) else { return false }
        inputs.append(.init(tick: runtime.tick, action: "bonusTool", target: target, tool: tool.rawValue))
        bonusSkillID = choice.skillID
        return true
    }
    @discardableResult public func retainExtraSkillUse(_ skillID: String) -> Bool {
        guard existingLevelSkills.contains(skillID), bonusSkillID == nil || bonusSkillID == skillID else { return false }
        bonusSkillID = skillID
        return true
    }
    public var assignedSkills: [String: Int] {
        inputs.reduce(into: [:]) { counts, input in
            guard Lemmings3Runtime.Action(rawValue: input.action) != nil else { return }
            counts[input.action, default: 0] += 1
        }
    }

    public init(
        runtime: Lemmings3Runtime,
        engineFingerprint: String,
        levelIdentifier: String,
        levelIndex: Int,
        levelFingerprint: String,
        panelFrame: MobilePixelFrame? = nil,
        directionPickerFrames: [MobilePixelFrame] = [],
        renderer: Lemmings3MobileRenderer? = nil,
        ghostRenderer: Lemmings3MobileGhostRenderer? = nil,
        soundBank: Lemmings3SoundBank? = nil,
        onCompletion: ((Lemmings3Runtime) -> Void)? = nil
    ) {
        self.ghostRenderer = ghostRenderer
        initial = runtime
        self.runtime = runtime
        self.engineFingerprint = engineFingerprint
        self.levelIdentifier = levelIdentifier
        self.levelIndex = levelIndex
        self.levelFingerprint = levelFingerprint
        self.panelFrame = panelFrame
        self.directionPickerFrames = directionPickerFrames
        self.renderer = renderer
        self.soundBank = soundBank
        self.onCompletion = onCompletion
        levelSize = MobileSize(
            width: Double(runtime.configuration.width),
            height: Double(runtime.configuration.height)
        )
    }

    public var entrancePoint: MobilePoint {
        let point = initial.configuration.entrance
        return MobilePoint(x: Double(point.x), y: Double(point.y))
    }

    public var activeLemmingCount: Int { runtime.lemmings.reduce(0) { $0 + ($1.active ? 1 : 0) } }
    public var assignedSkillCount: Int { assignedSkills.values.reduce(0, +) }
    /// Extras start on the map and are not included in the entrance's released count.
    public var lostLemmingCount: Int { runtime.lost }
    public var supportsRewind: Bool { true }

    public var snapshot: MobileGameSnapshot {
        MobileGameSnapshot(
            tick: runtime.tick,
            released: runtime.released,
            total: runtime.configuration.total,
            saved: runtime.saved,
            required: 1,
            remainingSeconds: runtime.remainingSeconds,
            releaseRate: nil,
            isComplete: runtime.isComplete,
            didWin: runtime.isComplete && runtime.saved > 0,
            isEndingRun: false,
            skills: skillStates
        )
    }

    public func tick() {
        let before = Lemmings3SoundCue.Snapshot(runtime)
        runtime.step()
        soundCues += Lemmings3SoundCue.positionedCues(before: before, after: .init(runtime))
        explosionTimeline.update(tick: runtime.tick, bursts: PixelExplosion.lemmings3(runtime))
        if runtime.isComplete, !didNotifyCompletion {
            didNotifyCompletion = true
            onCompletion?(runtime)
        }
    }

    public func targetWallDirection(for target: Int) -> Int? {
        guard let lemming = runtime.lemmings.first(where: { $0.id == target }) else { return nil }
        return LemmingApproachTargeting.wallDirection(x: lemming.x, footY: lemming.y, isSolid: runtime.isSolid)
    }

    public func targetCandidates(for control: Int) -> [MobileTargetCandidate] {
        guard Lemmings3Runtime.Action.allCases.indices.contains(control) else { return [] }
        let action = Lemmings3Runtime.Action.allCases[control]
        return runtime.lemmings.filter(\.active).map { lemming in
            let accepted: Bool
            if action == .use {
                accepted = Lemmings3Runtime.Direction.allCases.contains { direction in
                    runtime.canUseTool(lemming, direction: direction)
                }
            } else {
                accepted = runtime.canAssign(action, to: lemming)
            }
            return MobileTargetCandidate(
                id: lemming.id,
                point: MobilePoint(x: Double(lemming.x), y: Double(lemming.y - 8)),
                direction: lemming.direction,
                assignment: accepted ? .eligible : .unavailable,
                isBuilding: lemming.state == .building,
                hasTool: lemming.tool != nil,
                pointerBounds: MobileRect(x: -9, y: -12, width: 18, height: 24)
            )
        }
    }

    @discardableResult
    public func assign(control: Int, to target: Int) -> Bool {
        guard Lemmings3Runtime.Action.allCases.indices.contains(control) else { return false }
        let action = Lemmings3Runtime.Action.allCases[control]
        let lemming = runtime.lemmings.first { $0.id == target }
        let before = Lemmings3SoundCue.Snapshot(runtime)
        guard runtime.assign(action, to: target) else { return false }
        spriteFeedback.assigned(to: target, tick: runtime.tick)
        if let lemming {
            soundCues.append(.init(action == .use && lemming.tool == .bomb ? .ohNo : .assignSkill,
                at: .init(x: Double(lemming.x), y: Double(lemming.y))))
        }
        soundCues += Lemmings3SoundCue.positionedCues(before: before, after: .init(runtime))
        // A tool use follows the facing direction. Recording it keeps the shared action format exact.
        let facing = action == .use ? lemming.map { ($0.direction > 0 ? Lemmings3Runtime.Direction.right : .left).rawValue } : nil
        inputs.append(Input(tick: runtime.tick, action: action.rawValue, target: target, direction: facing,
            tool: action == .use ? lemming?.tool?.rawValue : nil))
        return true
    }

    /**
     * Uses the selected tool in a requested direction and records it for replay.
     */
    @discardableResult
    public func useTool(direction: Lemmings3Runtime.Direction, to target: Int) -> Bool {
        guard !runtime.isComplete else { return false }
        let lemming = runtime.lemmings.first { $0.id == target }
        let before = Lemmings3SoundCue.Snapshot(runtime)
        guard runtime.useTool(to: target, direction: direction) else { return false }
        spriteFeedback.assigned(to: target, tick: runtime.tick)
        if let lemming {
            soundCues.append(.init(lemming.tool == .bomb ? .ohNo : .assignSkill,
                at: .init(x: Double(lemming.x), y: Double(lemming.y))))
        }
        soundCues += Lemmings3SoundCue.positionedCues(before: before, after: .init(runtime))
        inputs.append(Input(tick: runtime.tick, action: Lemmings3Runtime.Action.use.rawValue,
                            target: target, direction: direction.rawValue, tool: lemming?.tool?.rawValue))
        return true
    }

    public func drainSoundCues() -> [PositionedSoundCue] {
        defer { soundCues.removeAll(keepingCapacity: true) }
        return soundCues
    }

    public func adjustReleaseRate(by delta: Int) -> Bool { false }

    @discardableResult
    public func beginEndRun() -> Bool {
        guard !runtime.isComplete else { return false }
        let before = Lemmings3SoundCue.Snapshot(runtime)
        inputs.append(Input(tick: runtime.tick, action: "abort", target: nil))
        runtime.abort()
        soundCues += Lemmings3SoundCue.positionedCues(before: before, after: .init(runtime))
        return true
    }

    public func undoEndRun() -> Bool { false }

    public func render(highlight: MobileTargetSelection?) throws -> MobilePixelFrame {
        spriteFeedback.selected = highlight?.id
        if let artworkRenderer {
            let ghosts = hotSeatGhosts?.states(at: runtime.tick) { state -> Lemmings3Runtime? in
                if case let .lemmings3(ghost) = state { return ghost }; return nil
            } ?? []
            return try artworkRenderer(runtime, highlight, ghosts, macArtwork)
        }
        guard let renderer else { throw MobileSessionError.frameUnavailable }
        if let ghostRenderer, hotSeatGhosts != nil {
            let ghosts = hotSeatGhosts!.states(at: runtime.tick) { state -> Lemmings3Runtime? in
                if case let .lemmings3(ghost) = state { return ghost }
                return nil
            }
            if !ghosts.isEmpty { return try ghostRenderer(runtime, highlight, ghosts) }
        }
        return try renderer(runtime, highlight)
    }

    public var actionReplayInitial: ActionReplayState? { .lemmings3(initial) }

    public var lemmingInspection: LemmingInspection? {
        let commands = inputs.map {
            LeaderboardActionReplay.Command(tick: $0.tick, action: $0.action, lemming: $0.target, skill: $0.tool, direction: $0.direction)
        }
        return try? LemmingInspection(initial: .lemmings3(initial), current: .lemmings3(runtime), commands: commands, familiarNames: familiarNamesStore)
    }

    public func actionCapture() -> MobileActionCapture? {
        // Runs saved before tool directions were recorded cannot be expressed exactly.
        guard inputs.allSatisfy({ $0.action != Lemmings3Runtime.Action.use.rawValue || $0.direction != nil }) else { return nil }
        let commands = inputs.map {
            LeaderboardActionReplay.Command(tick: $0.tick, action: $0.action, lemming: $0.target, skill: $0.tool, direction: $0.direction)
        }
        return .init(initial: .lemmings3(initial), final: .lemmings3(runtime), commands: commands)
    }

    public func checkpointPayload() throws -> Data {
        try prepareCheckpointPayload().encode()
    }

    public func prepareCheckpointPayload() throws -> MobileCheckpointPayload {
        guard !runtime.isComplete else { throw MobileSessionError.invalidCheckpoint }
        return MobileCheckpointPayload(Checkpoint(
            initialFingerprint: levelFingerprint,
            tick: runtime.tick,
            inputs: inputs,
            rewindCount: rewindCount,
            usedRewind: usedRewind,
            bonusSkillID: bonusSkillID
        ))
    }

    public func restoreCheckpointPayload(_ data: Data) throws {
        let checkpoint = try JSONDecoder().decode(Checkpoint.self, from: data)
        guard checkpoint.version == 1 else { throw MobileCheckpointError.version }
        guard checkpoint.initialFingerprint == levelFingerprint else { throw MobileSessionError.changedLevel }
        let restored = try replay(inputs: checkpoint.inputs, through: checkpoint.tick)
        runtime = restored
        soundCues.removeAll(keepingCapacity: true)
        explosionTimeline.reset()
        spriteFeedback.reset()
        inputs = checkpoint.inputs
        didNotifyCompletion = false
        rewindCount = checkpoint.rewindCount ?? 0
        usedRewind = checkpoint.usedRewind ?? false
        bonusSkillID = checkpoint.bonusSkillID
    }

    @discardableResult
    public func rewind(seconds: Double) -> Bool {
        guard seconds.isFinite, seconds >= 0 else { return false }
        let distance = Int(min(Double(runtime.tick), (seconds * ticksPerSecond).rounded()))
        guard distance > 0 else { return false }
        soundCues.removeAll(keepingCapacity: true)
        return move(to: runtime.tick - distance)
    }

    @discardableResult
    public func stepBackward() -> Bool {
        soundCues.removeAll(keepingCapacity: true)
        return move(to: runtime.tick - 1)
    }

    @discardableResult
    public func stepForward() -> Bool {
        guard !runtime.isComplete else { return false }
        tick()
        return true
    }

    public func resumeFromCurrentTick() {}

    private func move(to tick: Int) -> Bool {
        guard tick >= 0, tick < runtime.tick else { return false }
        do {
            let retainedInputs = inputs.filter { $0.tick <= tick }
            let restored = try replay(inputs: retainedInputs, through: tick)
            runtime = restored
            inputs = retainedInputs
            explosionTimeline.reset()
            spriteFeedback.reset()
            didNotifyCompletion = false
            usedRewind = true
            rewindCount += 1
            return true
        } catch {
            return false
        }
    }

    private func replay(inputs: [Input], through tick: Int) throws -> Lemmings3Runtime {
        var restored = initial
        var inputIndex = 0
        while restored.tick <= tick {
            while inputIndex < inputs.count, inputs[inputIndex].tick == restored.tick {
                let input = inputs[inputIndex]
                if input.action == "abort" {
                    restored.abort()
                } else if input.action == "bonusTool", let target = input.target,
                          restored.lemmings.first(where: { $0.id == target })?.tool?.rawValue == input.tool,
                          restored.grantBonusTool(to: target) {
                    // The extra charge belongs to this point in the attempt.
                } else if input.action == Lemmings3Runtime.Action.use.rawValue,
                          let target = input.target,
                          let rawDirection = input.direction,
                          let direction = Lemmings3Runtime.Direction(rawValue: rawDirection) {
                    _ = restored.useTool(to: target, direction: direction)
                } else if let action = Lemmings3Runtime.Action(rawValue: input.action),
                          let target = input.target,
                          restored.assign(action, to: target) {
                    // The input is now part of the reconstructed timeline.
                } else {
                    throw MobileSessionError.invalidCheckpoint
                }
                inputIndex += 1
            }
            if restored.tick == tick { break }
            guard !restored.isComplete else { throw MobileSessionError.invalidCheckpoint }
            restored.step()
        }
        guard restored.tick == tick, inputIndex == inputs.count, !restored.isComplete else {
            throw MobileSessionError.invalidCheckpoint
        }
        return restored
    }

    public func releaseTransientResources() {}
}

public typealias NeoLemmixMobileRenderer = (
    _ simulation: NeoLemmixSimulation,
    _ highlight: MobileTargetSelection?
) throws -> MobilePixelFrame

/**
 * Adapts the supported NeoLemmix simulation to the shared mobile session contract.
 */
public final class NeoLemmixMobileSession: MobileGameSession {
    public func makeReplayClone() -> (any MobileGameSession)? {
        let copy = NeoLemmixMobileSession(simulation: initial, controls: controls, engineFingerprint: engineFingerprint,
            levelIdentifier: levelIdentifier, levelIndex: levelIndex, levelFingerprint: levelFingerprint,
            renderer: renderer, ghostRenderer: ghostRenderer, gadgetSounds: gadgetSounds, soundDirectory: soundDirectory)
        copy.spriteProvider = spriteProvider
        copy.applySettings(spriteFeedback.settings)
        return copy
    }

    private var spriteFeedback = MobileSpriteFeedback<NeoLemmixSimulation>()
    public var spriteProvider: ((NeoLemmixSimulation, Int) -> MobileSpriteHighlight?)? {
        get { spriteFeedback.provider }
        set { spriteFeedback.provider = newValue }
    }
    public func applySettings(_ settings: ClassicSettings) { spriteFeedback.settings = settings }
    public func spriteHighlight(for actor: Int) -> MobileSpriteHighlight? {
        spriteFeedback.sprite(in: simulation, id: actor, tick: simulation.tickCount, ticksPerSecond: ticksPerSecond)
    }
    public var selectionSprite: MobileSpriteHighlight? {
        spriteFeedback.selection(in: simulation, tick: simulation.tickCount, ticksPerSecond: ticksPerSecond)
    }
    public var assignmentProgress: Double? { spriteFeedback.progress(at: simulation.tickCount, ticksPerSecond: ticksPerSecond) }
    public var assignmentSprite: MobileSpriteHighlight? {
        spriteFeedback.acknowledgement(in: simulation, tick: simulation.tickCount, ticksPerSecond: ticksPerSecond)
    }

    private enum Input: Codable, Sendable {
        case assign(tick: Int, skill: NeoLemmixSkill, target: Int)
        case spawnInterval(tick: Int, value: Int)
        case nuke(tick: Int)
        case bonusSkill(tick: Int, skill: NeoLemmixSkill)
    }

    private struct Checkpoint: Codable, Sendable {
        var version = 1
        let levelFingerprint: String
        let simulation: NeoLemmixSimulation
        let simulationBeforeNuke: NeoLemmixSimulation?
        let requestedSpawnInterval: Int?
        var inputs: [Input]? = nil
        var historyBase: NeoLemmixSimulation? = nil
        var historyBaseBeforeNuke: NeoLemmixSimulation? = nil
        var historyBaseRequestedInterval: Int? = nil
        var rewindCount: Int? = nil
        var usedRewind: Bool? = nil
        var nukeCount: Int? = nil
        var undoCount: Int? = nil
        var bonusSkillID: String? = nil
    }

    public var entrancePoint: MobilePoint {
        guard let point = initial.configuration.entrances.first?.position else { return .init(x: 160, y: 80) }
        return .init(x: Double(point.x), y: Double(point.y))
    }
    public var goalPoint: MobilePoint {
        guard let zone = initial.configuration.zones.first(where: { $0.effect == .exit || $0.effect == .lockedExit }) else { return entrancePoint }
        return .init(x: Double(zone.bounds.x + zone.bounds.width / 2), y: Double(zone.bounds.y + zone.bounds.height / 2))
    }

    public var lostLemmingCount: Int { simulation.lostCount }
    public let engineIdentifier = "neolemmix"
    public let engineFingerprint: String
    public let levelIdentifier: String
    public let levelIndex: Int
    public let levelFingerprint: String
    public let levelSize: MobileSize
    public let ticksPerSecond = Double(NeoLemmixRules.ticksPerSecond)
    public let gadgetSounds: [Int: String]
    public let soundDirectory: URL?

    private let initial: NeoLemmixSimulation
    private let controls: [NeoLemmixSkill]
    private let renderer: NeoLemmixMobileRenderer?
    private let ghostRenderer: ((_ simulation: NeoLemmixSimulation, _ highlight: MobileTargetSelection?,
        _ ghosts: [MobileReplayGhost<NeoLemmixSimulation>]) throws -> MobilePixelFrame)?
    public var hotSeatGhosts: HotSeatGhostPlayback?
    private let onCompletion: ((NeoLemmixSimulation) -> Void)?
    private var historyBase: NeoLemmixSimulation
    private var historyBaseBeforeNuke: NeoLemmixSimulation?
    private var historyBaseRequestedInterval: Int?
    private var simulation: NeoLemmixSimulation
    private var simulationBeforeNuke: NeoLemmixSimulation?
    private var requestedSpawnInterval: Int?
    private var inputs: [Input] = []
    private var soundCues: [PositionedSoundCue] = []
    private var didNotifyCompletion = false
    public private(set) var rewindCount = 0
    public private(set) var usedRewind = false
    public private(set) var nukeCount = 0
    public private(set) var undoCount = 0
    public private(set) var bonusSkillID: String?
    public var actualSpawnInterval: Int { simulation.spawnInterval }
    public var existingLevelSkills: Set<String> {
        Set(initial.configuration.skills.compactMap { skill, supply in
            if case let .finite(count) = supply, count > 0 { return skill.rawValue }
            return nil
        })
    }
    public var extraSkillChoices: [MobileExtraSkillChoice] {
        guard bonusSkillID == nil else { return [] }
        return controls.enumerated().compactMap { control, skill in
            simulation.canGrantBonusSkill(skill)
                ? .init(skillID: skill.rawValue, title: SkillVocabulary.title(skill.rawValue), control: control) : nil
        }
    }
    @discardableResult public func grantExtraSkill(_ choice: MobileExtraSkillChoice) -> Bool {
        guard extraSkillChoices.contains(choice), controls.indices.contains(choice.control),
              simulation.grantBonusSkill(controls[choice.control]) else { return false }
        inputs.append(.bonusSkill(tick: simulation.tickCount, skill: controls[choice.control]))
        bonusSkillID = choice.skillID
        return true
    }
    @discardableResult public func retainExtraSkillUse(_ skillID: String) -> Bool {
        guard existingLevelSkills.contains(skillID), bonusSkillID == nil || bonusSkillID == skillID else { return false }
        bonusSkillID = skillID
        return true
    }

    public init(simulation: NeoLemmixSimulation, controls: [NeoLemmixSkill],
                engineFingerprint: String, levelIdentifier: String, levelIndex: Int,
                levelFingerprint: String, renderer: NeoLemmixMobileRenderer? = nil,
                ghostRenderer: ((_ simulation: NeoLemmixSimulation, _ highlight: MobileTargetSelection?,
                    _ ghosts: [MobileReplayGhost<NeoLemmixSimulation>]) throws -> MobilePixelFrame)? = nil,
                gadgetSounds: [Int: String] = [:], soundDirectory: URL? = nil,
                onCompletion: ((NeoLemmixSimulation) -> Void)? = nil) {
        initial = simulation
        historyBase = simulation
        historyBaseBeforeNuke = nil
        historyBaseRequestedInterval = nil
        self.simulation = simulation
        self.controls = controls
        self.engineFingerprint = engineFingerprint
        self.levelIdentifier = levelIdentifier
        self.levelIndex = levelIndex
        self.levelFingerprint = levelFingerprint
        self.renderer = renderer
        self.ghostRenderer = ghostRenderer
        self.gadgetSounds = gadgetSounds
        self.soundDirectory = soundDirectory
        self.onCompletion = onCompletion
        levelSize = MobileSize(width: Double(simulation.terrain.width), height: Double(simulation.terrain.height))
    }

    public var snapshot: MobileGameSnapshot {
        let state = simulation.snapshot()
        let skillStates = controls.map { skill -> MobileSkillState in
            switch state.skills[skill] ?? .finite(0) {
            case let .finite(count): MobileSkillState(name: skill.rawValue.capitalized, count: count)
            case .infinite: MobileSkillState(name: skill.rawValue.capitalized, count: 0, isUnlimited: true)
            }
        }
        return MobileGameSnapshot(
            tick: state.tickCount,
            released: state.releasedCount,
            total: simulation.configuration.totalLemmings,
            saved: state.savedCount,
            required: simulation.configuration.requiredToSave,
            remainingSeconds: state.remainingTimeTicks.map { max(0, $0 / NeoLemmixRules.ticksPerSecond) },
            releaseRate: max(1, min(99, (53 - state.spawnInterval) * 2)),
            isComplete: state.isComplete,
            didWin: state.didWin,
            isEndingRun: state.isNuking || simulationBeforeNuke != nil,
            skills: skillStates
        )
    }

    public var supportsRewind: Bool { true }
    public var assignedSkillCount: Int {
        inputs.filter { if case .assign = $0 { return true }; return false }.count
    }

    public func tick() {
        let events = simulation.tick()
        appendSoundCues(for: events)
        requestedSpawnInterval = simulation.snapshot().spawnInterval
        if simulation.isComplete, !didNotifyCompletion {
            didNotifyCompletion = true
            onCompletion?(simulation)
        }
    }

    public func targetWallDirection(for target: Int) -> Int? {
        guard let lemming = simulation.lemmings.first(where: { $0.id == target }) else { return nil }
        return LemmingApproachTargeting.wallDirection(x: lemming.position.x, footY: lemming.position.y) {
            simulation.terrain.isSolid(x: $0, y: $1)
        }
    }

    public func targetCandidates(for control: Int) -> [MobileTargetCandidate] {
        guard controls.indices.contains(control) else { return [] }
        let skill = controls[control]
        return simulation.lemmings.filter(\.canReceiveSkills).map { lemming in
            var probe = simulation
            let accepted = probe.assign(skill: skill, to: lemming.id).wasAssigned
            return MobileTargetCandidate(
                id: lemming.id,
                point: MobilePoint(x: Double(lemming.position.x), y: Double(lemming.position.y - 5)),
                direction: lemming.direction == .left ? -1 : 1,
                assignment: accepted ? .eligible : .unavailable,
                isBuilding: lemming.action == .building || lemming.action == .platforming,
                hasTool: lemming.traits.contains(.climber) || lemming.traits.contains(.floater),
                pointerBounds: MobileRect(x: -8, y: -10, width: 16, height: 20)
            )
        }
    }

    @discardableResult
    public func assign(control: Int, to target: Int) -> Bool {
        guard controls.indices.contains(control), !simulation.isComplete,
              simulationBeforeNuke == nil else { return false }
        let skill = controls[control]
        guard simulation.assign(skill: skill, to: target).wasAssigned else { return false }
        appendSoundCues(for: simulation.lastTickEvents)
        inputs.append(.assign(tick: simulation.tickCount, skill: skill, target: target))
        spriteFeedback.assigned(to: target, tick: simulation.tickCount)
        return true
    }

    public func drainSoundCues() -> [PositionedSoundCue] {
        defer { soundCues.removeAll(keepingCapacity: true) }
        return soundCues
    }

    private func appendSoundCues(for events: [NeoLemmixEvent]) {
        soundCues += NeoLemmixSoundCue.positionedCues(
            for: events,
            lemmings: simulation.lemmings,
            entrances: simulation.configuration.entrances,
            zones: simulation.configuration.zones,
            gadgetSounds: gadgetSounds
        )
        if soundCues.count > 256 { soundCues.removeFirst(soundCues.count - 256) }
    }

    @discardableResult
    public func adjustReleaseRate(by delta: Int) -> Bool {
        guard delta != 0, !simulation.isComplete, !simulation.isNuking,
              simulationBeforeNuke == nil, !simulation.configuration.spawnIntervalLocked else { return false }
        let current = requestedSpawnInterval ?? simulation.snapshot().spawnInterval
        let next = min(simulation.configuration.spawnInterval,
                       max(NeoLemmixRules.minimumSpawnInterval, current - delta))
        guard next != current else { return false }
        requestedSpawnInterval = next
        simulation.enqueue(.setSpawnInterval(next))
        inputs.append(.spawnInterval(tick: simulation.tickCount, value: next))
        return true
    }

    @discardableResult public func setSpawnInterval(_ value: Int) -> Bool {
        guard !simulation.isComplete, !simulation.isNuking, !simulation.configuration.spawnIntervalLocked,
              (NeoLemmixRules.minimumSpawnInterval...simulation.configuration.spawnInterval).contains(value) else { return false }
        requestedSpawnInterval = value
        simulation.enqueue(.setSpawnInterval(value))
        inputs.append(.spawnInterval(tick: simulation.tickCount, value: value))
        return true
    }

    @discardableResult
    public func beginEndRun() -> Bool {
        guard !simulation.isComplete, !simulation.isNuking, simulationBeforeNuke == nil else { return false }
        simulationBeforeNuke = simulation
        simulation.enqueue(.nuke)
        inputs.append(.nuke(tick: simulation.tickCount))
        nukeCount += 1
        return true
    }

    @discardableResult
    public func undoEndRun() -> Bool {
        guard let simulationBeforeNuke, !simulation.isComplete else { return false }
        soundCues.removeAll(keepingCapacity: true)
        spriteFeedback.reset()
        let restoredRequestedInterval = inputs.reversed().compactMap { input -> Int? in
            if case let .spawnInterval(_, value) = input { return value }
            return nil
        }.first ?? requestedSpawnInterval ?? simulation.snapshot().spawnInterval
        simulation = simulationBeforeNuke
        self.simulationBeforeNuke = nil
        if case .nuke = inputs.last {
            inputs.removeLast()
        } else if historyBaseBeforeNuke != nil {
            historyBase = simulation
            historyBaseBeforeNuke = nil
            inputs = []
            historyBaseRequestedInterval = restoredRequestedInterval
        }
        requestedSpawnInterval = restoredRequestedInterval
        didNotifyCompletion = false
        usedRewind = true
        undoCount += 1
        return true
    }

    public func render(highlight: MobileTargetSelection?) throws -> MobilePixelFrame {
        spriteFeedback.selected = highlight?.id
        guard let renderer else { throw MobileSessionError.frameUnavailable }
        if let ghostRenderer, hotSeatGhosts != nil {
            let ghosts = hotSeatGhosts!.states(at: simulation.tickCount) { state -> NeoLemmixSimulation? in
                if case let .neolemmix(ghost) = state { return ghost }
                return nil
            }
            if !ghosts.isEmpty { return try ghostRenderer(simulation, highlight, ghosts) }
        }
        return try renderer(simulation, highlight)
    }

    public var actionReplayInitial: ActionReplayState? {
        initial.tickCount == 0 && historyBase.tickCount == 0 ? .neolemmix(initial) : nil
    }

    public var assignedSkills: [String: Int] {
        inputs.reduce(into: [:]) { counts, input in
            if case let .assign(_, skill, _) = input { counts[skill.rawValue, default: 0] += 1 }
        }
    }

    public func actionCapture() -> MobileActionCapture? {
        // Legacy saves with only a mid-level state cannot reconstruct the whole attempt.
        guard initial.tickCount == 0, historyBase.tickCount == 0 else { return nil }
        let order = NeoLemmixSkill.allCases.filter { initial.configuration.skills[$0] != nil }
        var interval = initial.spawnInterval
        var requested = interval
        var rateTick = initial.tickCount
        var commands: [LeaderboardActionReplay.Command] = []
        for input in inputs {
            switch input {
            case let .assign(tick, skill, target):
                guard let control = order.firstIndex(of: skill) else { return nil }
                commands.append(.init(tick: tick, action: "assign", lemming: target, skill: control))
            case let .spawnInterval(tick, value):
                // Queued rate changes at one tick all use that tick's actual interval.
                if tick > rateTick { interval = requested }
                commands.append(.init(tick: tick, action: "rate", value: value - interval))
                requested = value; rateTick = tick
            case let .nuke(tick): commands.append(.init(tick: tick, action: "nuke"))
            case let .bonusSkill(tick, skill):
                guard let control = order.firstIndex(of: skill) else { return nil }
                commands.append(.init(tick: tick, action: "bonusSkill", skill: control))
            }
        }
        return .init(initial: .neolemmix(initial), final: .neolemmix(simulation), commands: commands)
    }

    public func checkpointPayload() throws -> Data {
        try prepareCheckpointPayload().encode()
    }

    public func prepareCheckpointPayload() throws -> MobileCheckpointPayload {
        guard !simulation.isComplete else { throw MobileSessionError.invalidCheckpoint }
        return MobileCheckpointPayload(Checkpoint(
            levelFingerprint: levelFingerprint,
            simulation: simulation,
            simulationBeforeNuke: simulationBeforeNuke,
            requestedSpawnInterval: requestedSpawnInterval,
            inputs: inputs,
            historyBase: historyBase == initial ? nil : historyBase,
            historyBaseBeforeNuke: historyBaseBeforeNuke,
            historyBaseRequestedInterval: historyBaseRequestedInterval,
            rewindCount: rewindCount,
            usedRewind: usedRewind,
            nukeCount: nukeCount,
            undoCount: undoCount,
            bonusSkillID: bonusSkillID
        ))
    }

    public func restoreCheckpointPayload(_ data: Data) throws {
        let checkpoint = try JSONDecoder().decode(Checkpoint.self, from: data)
        guard checkpoint.version == 1 else { throw MobileCheckpointError.version }
        guard checkpoint.levelFingerprint == levelFingerprint else { throw MobileSessionError.changedLevel }
        guard checkpoint.simulation.configuration == initial.configuration,
              !checkpoint.simulation.isComplete else { throw MobileSessionError.invalidCheckpoint }
        if let beforeNuke = checkpoint.simulationBeforeNuke,
           beforeNuke.configuration != initial.configuration || beforeNuke.isComplete {
            throw MobileSessionError.invalidCheckpoint
        }
        if let checkpointInputs = checkpoint.inputs {
            let base = checkpoint.historyBase ?? initial
            guard base.configuration == initial.configuration, !base.isComplete else {
                throw MobileSessionError.invalidCheckpoint
            }
            let (restored, restoredBeforeNuke, restoredRequestedInterval) = try replay(
                inputs: checkpointInputs,
                from: base,
                beforeNuke: checkpoint.historyBaseBeforeNuke,
                requestedInterval: checkpoint.historyBaseRequestedInterval,
                through: checkpoint.simulation.tickCount
            )
            guard restored == checkpoint.simulation,
                  restoredBeforeNuke == checkpoint.simulationBeforeNuke else {
                throw MobileSessionError.invalidCheckpoint
            }
            historyBase = base
            historyBaseBeforeNuke = checkpoint.historyBaseBeforeNuke
            historyBaseRequestedInterval = checkpoint.historyBaseRequestedInterval
            simulation = restored
            simulationBeforeNuke = restoredBeforeNuke
            inputs = checkpointInputs
            requestedSpawnInterval = checkpoint.requestedSpawnInterval ?? restoredRequestedInterval
        } else {
            // Older checkpoints retained only the current state, so rewind begins here.
            historyBase = checkpoint.simulation
            historyBaseBeforeNuke = checkpoint.simulationBeforeNuke
            historyBaseRequestedInterval = checkpoint.requestedSpawnInterval
            simulation = checkpoint.simulation
            simulationBeforeNuke = checkpoint.simulationBeforeNuke
            inputs = []
            requestedSpawnInterval = checkpoint.requestedSpawnInterval ?? checkpoint.simulation.snapshot().spawnInterval
        }
        didNotifyCompletion = false
        soundCues.removeAll(keepingCapacity: true)
        spriteFeedback.reset()
        rewindCount = checkpoint.rewindCount ?? 0
        usedRewind = checkpoint.usedRewind ?? false
        nukeCount = checkpoint.nukeCount ?? (checkpoint.simulationBeforeNuke == nil ? 0 : 1)
        undoCount = checkpoint.undoCount ?? 0
        bonusSkillID = checkpoint.bonusSkillID
    }

    @discardableResult
    public func rewind(seconds: Double) -> Bool {
        guard seconds.isFinite, seconds >= 0 else { return false }
        let currentTick = simulation.snapshot().tickCount
        let distance = Int(min(Double(currentTick - historyBase.tickCount), (seconds * ticksPerSecond).rounded()))
        guard distance > 0 else { return false }
        soundCues.removeAll(keepingCapacity: true)
        spriteFeedback.reset()
        return move(to: currentTick - distance)
    }

    @discardableResult
    public func stepBackward() -> Bool {
        soundCues.removeAll(keepingCapacity: true)
        spriteFeedback.reset()
        return move(to: simulation.snapshot().tickCount - 1)
    }

    @discardableResult
    public func stepForward() -> Bool {
        guard !simulation.isComplete else { return false }
        tick()
        return true
    }

    public func resumeFromCurrentTick() {}

    private func move(to tick: Int) -> Bool {
        guard tick >= historyBase.tickCount, tick < simulation.snapshot().tickCount else { return false }
        do {
            let retainedInputs = inputs.filter { inputTick($0) <= tick }
            let (restored, restoredBeforeNuke, restoredRequestedInterval) = try replay(
                inputs: retainedInputs,
                from: historyBase,
                beforeNuke: historyBaseBeforeNuke,
                requestedInterval: historyBaseRequestedInterval,
                through: tick
            )
            simulation = restored
            simulationBeforeNuke = restoredBeforeNuke
            requestedSpawnInterval = restoredRequestedInterval
            inputs = retainedInputs
            didNotifyCompletion = false
            usedRewind = true
            rewindCount += 1
            return true
        } catch {
            return false
        }
    }

    private func replay(
        inputs: [Input],
        from base: NeoLemmixSimulation,
        beforeNuke initialBeforeNuke: NeoLemmixSimulation?,
        requestedInterval initialRequestedInterval: Int?,
        through tick: Int
    ) throws -> (NeoLemmixSimulation, NeoLemmixSimulation?, Int?) {
        var restored = base
        var restoredBeforeNuke = initialBeforeNuke
        var requestedInterval = initialRequestedInterval
        var inputIndex = 0
        while restored.tickCount <= tick {
            while inputIndex < inputs.count, inputTick(inputs[inputIndex]) == restored.tickCount {
                switch inputs[inputIndex] {
                case let .assign(_, skill, target):
                    guard restored.assign(skill: skill, to: target).wasAssigned else {
                        throw MobileSessionError.invalidCheckpoint
                    }
                case let .spawnInterval(_, value):
                    guard !restored.configuration.spawnIntervalLocked else {
                        throw MobileSessionError.invalidCheckpoint
                    }
                    restored.enqueue(.setSpawnInterval(value))
                    requestedInterval = value
                case let .bonusSkill(_, skill):
                    guard restored.grantBonusSkill(skill) else { throw MobileSessionError.invalidCheckpoint }
                case .nuke:
                    guard !restored.isComplete, !restored.isNuking, restoredBeforeNuke == nil else {
                        throw MobileSessionError.invalidCheckpoint
                    }
                    restoredBeforeNuke = restored
                    restored.enqueue(.nuke)
                }
                inputIndex += 1
            }
            if restored.tickCount == tick { break }
            guard !restored.isComplete else { throw MobileSessionError.invalidCheckpoint }
            _ = restored.tick()
            requestedInterval = restored.snapshot().spawnInterval
        }
        guard restored.tickCount == tick, inputIndex == inputs.count, !restored.isComplete else {
            throw MobileSessionError.invalidCheckpoint
        }
        return (restored, restoredBeforeNuke, requestedInterval)
    }

    private func inputTick(_ input: Input) -> Int {
        switch input {
        case let .assign(tick, _, _), let .spawnInterval(tick, _), let .nuke(tick), let .bonusSkill(tick, _): tick
        }
    }

    public func releaseTransientResources() {}
}
