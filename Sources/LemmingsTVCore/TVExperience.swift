import Foundation
import LemmingsMobileCore
import NxlvKit

/// Couch controls keep planning separate from Ready, recovery and results.
public struct TVPreferences: Codable, Equatable, Sendable {
    public var planningOnSkillChange = false
    public var aimSensitivity = 1.0
    public var deadZone = 0.15
    public var textScale = 1.0
    public var swapSticks = false
    public var musicEnabled = true
    public var effectsEnabled = true
    public var mappings: [String: String] = [:]
    public var triggerFeedback: Bool? = nil
    public init() {}

    public static let inputDefaultsKey = "tv.inputPreferences.v1"
    public static func inputPreferences(from defaults: UserDefaults, profileID: String? = nil) -> TVPreferences {
        let key = inputKey(profileID)
        if let data = defaults.data(forKey: key), let value = try? JSONDecoder().decode(Self.self, from: data) { return value.validated }
        let legacy = defaults.data(forKey: inputDefaultsKey).flatMap { try? JSONDecoder().decode(Self.self, from: $0) }?.validated ?? .init()
        if profileID != nil { legacy.saveInputPreferences(to: defaults, profileID: profileID) }
        return legacy
    }
    public static func inputKey(_ profileID: String?) -> String {
        profileID.map { inputDefaultsKey + ".player." + Data($0.utf8).base64EncodedString() } ?? inputDefaultsKey
    }
    public func saveInputPreferences(to defaults: UserDefaults, profileID: String? = nil) {
        if let data = try? JSONEncoder().encode(validated) { defaults.set(data, forKey: Self.inputKey(profileID)) }
    }

    public var validated: TVPreferences {
        var copy = self
        copy.aimSensitivity = aimSensitivity.isFinite ? min(2, max(0.5, aimSensitivity)) : 1
        copy.deadZone = deadZone.isFinite ? min(0.35, max(0.05, deadZone)) : 0.15
        copy.textScale = textScale >= 1.25 ? 1.25 : 1
        copy.mappings = ControllerBindings.validatedMapping(mappings)
        return copy
    }

    /// Fine movement near the centre, quick travel near the edge; bounded and symmetric.
    public func stickVelocity(_ value: Double, maximum: Double = 620) -> Double {
        guard value.isFinite else { return 0 }
        let settings = validated
        let magnitude = abs(min(1, max(-1, value)))
        guard magnitude > settings.deadZone else { return 0 }
        let normalized = (magnitude - settings.deadZone) / (1 - settings.deadZone)
        return (value < 0 ? -1 : 1) * normalized * normalized * maximum * settings.aimSensitivity
    }
}

public enum TVCameraMode: Int, CaseIterable, Sendable { case overview, play, precision }

/// Capture on the gameplay actor, then encode without reading the live session again.
public struct TVCheckpointDraft: Sendable {
    public let metadata: MobileCheckpointEnvelope
    private let payload: MobileCheckpointPayload
    fileprivate init(metadata: MobileCheckpointEnvelope, payload: MobileCheckpointPayload) {
        self.metadata = metadata; self.payload = payload
    }
    public func encode() throws -> MobileCheckpointEnvelope {
        .init(runID: metadata.runID, engine: metadata.engine, engineFingerprint: metadata.engineFingerprint,
              levelIdentifier: metadata.levelIdentifier, levelIndex: metadata.levelIndex, levelFingerprint: metadata.levelFingerprint,
              tick: metadata.tick, selectedControl: metadata.selectedControl, camera: metadata.camera,
              payload: try payload.encode(), savedAt: metadata.savedAt, scope: metadata.scope, owner: metadata.owner)
    }
}

/// Native engines expose only the controls their rules support.
public struct TVGameCapabilities: Equatable, Sendable {
    public let rewind: Bool
    public let releaseRate: Bool
    public let nuke: Bool
    public let carriedTools: Bool
    public init(session: any MobileGameSession) {
        rewind = session.supportsRewind
        releaseRate = session.snapshot.releaseRate != nil
        nuke = session.engineIdentifier != "lemmings3"
        carriedTools = session.engineIdentifier == "lemmings3"
    }
}

@MainActor public final class TVGameExperience {
    public let content: MobileLevelContent
    public var session: any MobileGameSession { content.session }
    public let runID: UUID
    public let owner: String
    public let scope: String?
    public private(set) var play = MobilePlayState()
    public private(set) var viewport: MobileViewport
    public private(set) var pointer: MobilePoint
    public private(set) var selectedControl = 0
    public private(set) var target: MobileTargetSelection?
    public private(set) var cameraMode = TVCameraMode.play
    public private(set) var speed = 1.0
    public private(set) var lastAssignment: (control: Int, actor: Int)?
    public private(set) var assignmentPulse = 0.0
    public var preferences: TVPreferences
    private var lockedActor: Int?
    private var clock: MobileTickClock
    private var inputSpeed = GameplaySpeed()
    private var foreground = true
    private var interrupted = false
    private var countdown = GameplayStartCountdown()
    private var needsCountdown = true
    private var presentationTime: Double?
    public var startNumber: Int? { countdown.number }
    public var awaitsFirstStart: Bool { needsCountdown && play.phase == .ready }

    public var capabilities: TVGameCapabilities { TVGameCapabilities(session: session) }
    public var canInteract: Bool { foreground && !interrupted && play.canEdit && !countdown.isActive }

    public init(content: MobileLevelContent, owner: String, scope: String? = nil,
                preferences: TVPreferences = .init(), checkpoint: MobileCheckpointEnvelope? = nil) throws {
        self.content = content; self.owner = owner; self.scope = scope
        self.preferences = preferences.validated
        runID = checkpoint?.runID ?? UUID()
        viewport = MobileViewport(levelSize: content.session.levelSize,
            viewSize: .init(width: 1728, height: 760), pixelAspect: 1, maximumZoom: 24)
        viewport.fitGameplay(in: viewport.viewSize, centring: content.session.entrancePoint)
        pointer = viewport.viewPoint(fromLevel: content.session.entrancePoint)
        clock = MobileTickClock(ticksPerSecond: content.session.ticksPerSecond, maximumCatchUpTicks: 32)
        selectedControl = session.snapshot.skills.firstIndex { $0.count > 0 || $0.isUnlimited } ?? 0
        if let checkpoint {
            needsCountdown = false
            guard checkpoint.engine == session.engineIdentifier,
                checkpoint.engineFingerprint == session.engineFingerprint,
                checkpoint.levelIdentifier == session.levelIdentifier,
                checkpoint.levelFingerprint == session.levelFingerprint,
                checkpoint.scope == scope, (checkpoint.owner ?? MobileProfiles.defaultID) == owner else {
                throw MobileSessionError.changedLevel
            }
            _ = try checkpoint.validated()
            try session.restoreCheckpointPayload(checkpoint.payload)
            selectedControl = min(checkpoint.selectedControl, max(0, session.snapshot.skills.count - 1))
            viewport.origin = checkpoint.camera.origin; viewport.zoom = checkpoint.camera.zoom; viewport.clamp()
            pointer = .init(x: viewport.viewSize.width / 2, y: viewport.viewSize.height / 2)
        }
    }

    public func resize(_ size: MobileSize) {
        let anchor = viewport.levelPoint(fromView: pointer)
        viewport.resize(size)
        pointer = bounded(viewport.viewPoint(fromLevel: anchor))
        refreshTarget()
    }

    @discardableResult public func resume() -> Bool {
        guard play.resume(isForeground: foreground, isInterrupted: interrupted) else { return false }
        if needsCountdown { countdown.arm(); needsCountdown = false }
        presentationTime = nil
        session.resumeFromCurrentTick(); clock.suspend(); refreshTarget()
        return true
    }

    public func pause() {
        countdown.cancel(); presentationTime = nil
        _ = play.pauseForPlanning(); clearSpeed(); clock.suspend()
    }

    public func suspend(interruption: Bool = false, inactive: Bool = false) {
        if inactive { foreground = false }
        interrupted = interruption || interrupted
        presentationTime = nil
        play.suspend(); clearSpeed(); clock.suspend(); lockedActor = nil; target = nil
    }

    public func becameActive() { foreground = true; clock.suspend() }
    public func interruptionEnded() { interrupted = false; clock.suspend() }

    public func advance(at time: Double) -> Bool {
        guard foreground, !interrupted, play.phase == .running else { clock.suspend(); return false }
        if countdown.isActive {
            let elapsed = presentationTime.map { max(0, time - $0) } ?? 0
            presentationTime = time
            _ = countdown.advance(seconds: elapsed, visible: true)
            clock.suspend(); refreshTarget(); return false
        }
        inputSpeed.update(at: time)
        speed = inputSpeed.target; clock.speed = inputSpeed.multiplier
        let ticks = clock.advance(at: time)
        for _ in 0..<ticks where !session.snapshot.isComplete { session.tick() }
        if session.snapshot.isComplete { play.complete(); clearSpeed() }
        assignmentPulse = max(0, assignmentPulse - Double(ticks) / session.ticksPerSecond)
        refreshTarget()
        return ticks > 0
    }

    public func selectSkill(_ control: Int) {
        guard canInteract, session.snapshot.skills.indices.contains(control) else { return }
        if preferences.planningOnSkillChange { pause() }
        selectedControl = control; lockedActor = nil; refreshTarget()
    }

    public func cycleSkill(_ delta: Int) {
        let skills = session.snapshot.skills
        guard canInteract, !skills.isEmpty, delta != 0 else { return }
        for step in 1...skills.count {
            let next = (selectedControl + (delta < 0 ? -step : step) + skills.count * 2) % skills.count
            if skills[next].count > 0 || skills[next].isUnlimited { selectSkill(next); return }
        }
    }

    public func aim(dx: Double, dy: Double) {
        guard canInteract, dx.isFinite, dy.isFinite else { return }
        if abs(dx) + abs(dy) > 0.01 { lockedActor = nil }
        pointer = bounded(.init(x: pointer.x + dx, y: pointer.y + dy)); refreshTarget()
    }

    public func pan(dx: Double, dy: Double) {
        guard canInteract, dx.isFinite, dy.isFinite else { return }
        viewport.pan(viewDelta: .init(x: -dx, y: -dy)); refreshTarget()
    }

    public func centre(entrance: Bool) {
        guard canInteract else { return }
        let point = entrance ? session.entrancePoint : session.goalPoint
        viewport.origin = .init(x: point.x - viewport.visibleLevelSize.width / 2,
                                y: point.y - viewport.visibleLevelSize.height / 2)
        viewport.clamp(); pointer = bounded(viewport.viewPoint(fromLevel: point)); refreshTarget()
    }

    public func setCamera(_ mode: TVCameraMode) {
        guard canInteract else { return }
        let anchor = viewport.levelPoint(fromView: pointer)
        cameraMode = mode
        let zoom: Double
        switch mode {
        case .overview: zoom = viewport.minimumZoom
        case .play: zoom = max(viewport.minimumZoom, floor(viewport.fittedGameplayZoom))
        case .precision: zoom = max(viewport.minimumZoom, floor(viewport.fittedGameplayZoom * 2))
        }
        viewport.magnify(by: zoom / viewport.zoom, around: pointer)
        pointer = bounded(viewport.viewPoint(fromLevel: anchor)); refreshTarget()
    }

    /// Cycling locks an actor ID, so crossings cannot silently select a neighbour.
    public func cycleTarget(_ delta: Int) {
        guard canInteract, delta != 0 else { return }
        let candidates = session.targetCandidates(for: selectedControl).filter { $0.assignment == .eligible }.sorted { $0.id < $1.id }
        guard !candidates.isEmpty else { lockedActor = nil; target = nil; return }
        let current = candidates.firstIndex { $0.id == target?.id }
        let index = current.map { ($0 + (delta < 0 ? -1 : 1) + candidates.count) % candidates.count } ?? (delta < 0 ? candidates.count - 1 : 0)
        focus(candidates[index])
    }

    public func focusLast() {
        guard canInteract, let lastAssignment,
              let actor = session.targetCandidates(for: selectedControl).first(where: { $0.id == lastAssignment.actor }) else { return }
        focus(actor)
    }

    @discardableResult public func assign(repeatLast: Bool = false) -> Bool {
        guard canInteract else { return false }
        if repeatLast, let lastAssignment { selectSkill(lastAssignment.control) }
        refreshTarget()
        guard let target, target.state == .eligible,
              session.assign(control: selectedControl, to: target.id) else { return false }
        lastAssignment = (selectedControl, target.id); assignmentPulse = 0.1
        refreshTarget(); return true
    }

    public func step(backward: Bool = false) {
        guard foreground, !interrupted, play.canEdit else { return }
        pause()
        if backward { guard capabilities.rewind else { return }; _ = session.stepBackward() }
        else { _ = session.stepForward() }
        lockedActor = nil
        if session.snapshot.isComplete { play.complete() }
        refreshTarget()
    }

    public func rewind() {
        guard canInteract, capabilities.rewind else { return }
        pause(); _ = session.rewind(seconds: 1); lockedActor = nil; refreshTarget()
    }

    public func rate(_ delta: Int) {
        guard canInteract, capabilities.releaseRate else { return }
        _ = session.adjustReleaseRate(by: delta)
    }

    public func boost(_ held: Bool, at time: Double) {
        guard canInteract else { clearSpeed(); return }
        if held { inputSpeed.press(.controller, at: time) }
        else { inputSpeed.release(.controller, at: time) }
        speed = inputSpeed.target
    }

    public func changeSpeed(_ delta: Int) {
        guard canInteract else { return }
        inputSpeed.step(delta, at: ProcessInfo.processInfo.systemUptime); speed = inputSpeed.target
    }
    public func clearSpeed() { inputSpeed.reset(at: 0); speed = 1 }

    public func endRun() {
        guard canInteract else { return }
        if session.snapshot.isEndingRun { _ = session.undoEndRun() }
        else { _ = session.beginEndRun() }
        refreshTarget()
    }

    public func prepareCheckpoint() throws -> TVCheckpointDraft {
        let metadata = MobileCheckpointEnvelope(runID: runID, engine: session.engineIdentifier,
            engineFingerprint: session.engineFingerprint, levelIdentifier: session.levelIdentifier,
            levelIndex: session.levelIndex, levelFingerprint: session.levelFingerprint, tick: session.snapshot.tick,
            selectedControl: selectedControl, camera: .init(origin: viewport.origin, zoom: viewport.zoom),
            payload: Data(), scope: scope, owner: owner)
        return TVCheckpointDraft(metadata: metadata, payload: try session.prepareCheckpointPayload())
    }
    public func checkpoint() throws -> MobileCheckpointEnvelope { try prepareCheckpoint().encode() }

    private func focus(_ actor: MobileTargetCandidate) {
        lockedActor = actor.id
        let visible = viewport.visibleLevelRect
        if !visible.contains(actor.point) {
            viewport.origin = .init(x: actor.point.x - viewport.visibleLevelSize.width / 2,
                                    y: actor.point.y - viewport.visibleLevelSize.height / 2)
            viewport.clamp()
        }
        pointer = bounded(viewport.viewPoint(fromLevel: actor.point)); refreshTarget()
    }

    public func refreshTarget() {
        guard canInteract else { target = nil; return }
        let candidates = session.targetCandidates(for: selectedControl)
        if let lockedActor {
            guard let actor = candidates.first(where: { $0.id == lockedActor }),
                viewport.visibleLevelRect.contains(actor.point) else { target = nil; return }
            target = .init(id: actor.id, point: actor.point, state: actor.assignment)
            pointer = bounded(viewport.viewPoint(fromLevel: actor.point)); return
        }
        target = MobileTargetSelector.select(candidates: candidates, touch: pointer, viewport: viewport,
            radius: 36, input: .touch)
    }

    private func bounded(_ point: MobilePoint) -> MobilePoint {
        .init(x: min(viewport.viewSize.width, max(0, point.x)), y: min(viewport.viewSize.height, max(0, point.y)))
    }
}
