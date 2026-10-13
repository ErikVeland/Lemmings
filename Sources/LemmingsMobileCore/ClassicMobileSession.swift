import Foundation
import NxlvKit

/// Loads user-selected DOS data once and creates sessions from the authored order.
public final class ClassicMobileLibrary: MobileGameLibrary {
    public let directory: URL
    public let dataSet: ClassicDataSet
    public let levels: [MobileLevelSummary]
    public var displayName: String { dataSet.name }

    private let assets: ClassicMainDATAssets
    private var grounds: [Int: ClassicGroundSet] = [:]
    private var specials: [Int: ClassicSpecialGraphic] = [:]

    public init(directory: URL) throws {
        self.directory = directory
        dataSet = try ClassicDataSet.detect(directory: directory)
        assets = try ClassicMainDATAssets.load(from: directory)
        levels = dataSet.campaign.levels.enumerated().map { index, item in
            MobileLevelSummary(
                index: index,
                rank: item.rank,
                number: item.number,
                title: item.level.title
            )
        }
    }

    public func checkpointLevelIdentifier(at index: Int) throws -> String? {
        guard dataSet.campaign.levels.indices.contains(index) else { throw MobileSessionError.changedLevel }
        let entry = dataSet.campaign.levels[index]
        return "\(dataSet.identifierKey)/\(entry.rank)/\(entry.number)"
    }

    public func loadLevel(at index: Int) throws -> MobileLevelContent {
        guard dataSet.campaign.levels.indices.contains(index) else {
            throw MobileSessionError.changedLevel
        }
        let entry = dataSet.campaign.levels[index]
        let level = entry.level
        let ground: ClassicGroundSet
        if let cached = grounds[level.groundStyle] {
            ground = cached
        } else {
            let loaded = try ClassicGroundSet.load(style: level.groundStyle, from: directory)
            grounds[level.groundStyle] = loaded
            ground = loaded
        }
        let special: ClassicSpecialGraphic?
        if level.specialStyle == 0 {
            special = nil
        } else if let cached = specials[level.specialStyle] {
            special = cached
        } else {
            let loaded = try ClassicSpecialGraphic.load(index: level.specialStyle - 1, from: directory)
            specials[level.specialStyle] = loaded
            special = loaded
        }
        return try ClassicMobileSession.makeContent(
            summary: levels[index], level: level, ground: ground, special: special, assets: assets,
            mechanics: ClassicDOSMechanics(title: dataSet.title, rank: entry.rank),
            objectSemantics: .dos,
            levelIdentifier: try checkpointLevelIdentifier(at: index)!,
            levelIndex: index, artworkFamily: ClassicMobileSession.family(for: dataSet.title))
    }
}

public final class ClassicMobileSession: MobileGameSession {
    private struct Checkpoint: Codable, Sendable {
        var version = 2
        let initialStateHash: String
        let simulation: ClassicDOSSimulation
        let beforeEndRun: ClassicDOSSimulation?
        var nukeCount: Int? = nil
        var rewindCount: Int? = nil
        var undoCount: Int? = nil
        var usedRewind: Bool? = nil
        var history: ClassicDOSRewind? = nil
        var beforeEndRunHistory: ClassicDOSRewind? = nil
        var replayInitial: ClassicDOSSimulation? = nil
    }

    public let engineIdentifier = "classic-dos"
    public let engineFingerprint = "classic-dos-mobile-v1"
    public let levelIdentifier: String
    public let levelIndex: Int
    public let levelFingerprint: String
    public let levelSize: MobileSize
    public let initialCameraOrigin: MobilePoint
    public let ticksPerSecond = Double(ClassicDOSRules.ticksPerSecond)

    private let initialStateHash: String
    private let renderedLevel: ClassicRenderedLevel?
    private let authoredLevel: ClassicLevel?
    private let ground: ClassicGroundSet?
    private let artworkFamily: String?
    private let artworkMatch: ClassicMacPieceMatch?
    private let artworkRoot: URL?
    private var nativeArtwork: ClassicMacArtwork?
    private var nativeScene: ClassicMacScene?
    private var terrainFrame: Data?
    private var cachedPanelFrame: MobilePixelFrame?
    public var renderScale: Double { nativeScene == nil ? 1 : 2 }
    public var activeLemmingCount: Int { simulation.activeCount }
    public var bombCountdowns: [MobileBombCountdown] {
        simulation.lemmings.filter(\.isActive).compactMap { lemming in
            guard let ticks = lemming.bomberCountdown, let assets else { return nil }
            let pose = Self.pose(for: lemming.action)
            let direction: ClassicSpriteDirection = lemming.direction == .left ? .left : .right
            guard let animation = assets.animation(for: pose, direction: direction)
                ?? assets.animation(for: pose, direction: .none), !animation.frames.isEmpty else { return nil }
            let anchor: MobilePoint
            if nativeScene != nil, let sprite = nativeArtwork?.lemming(pose: pose,
                left: lemming.direction == .left, tick: lemming.animationFrame) {
                anchor = .init(x: Double(lemming.foot.x + animation.offsetX) + Double(sprite.x) / 2 + Double(sprite.width) / 4,
                    y: Double(lemming.foot.y + animation.offsetY) + Double(sprite.y) / 2)
            } else {
                let sprite = animation.frames[abs(lemming.animationFrame) % animation.frames.count]
                anchor = .init(x: Double(lemming.foot.x + animation.offsetX) + Double(sprite.width) / 2,
                    y: Double(lemming.foot.y + animation.offsetY))
            }
            return .init(id: lemming.id,
                seconds: max(1, (ticks + ClassicDOSRules.ticksPerSecond - 1) / ClassicDOSRules.ticksPerSecond), anchor: anchor)
        }
    }
    public var explosions: [MobileExplosion] {
        simulation.lemmings.filter { $0.action == .exploding && $0.animationFrame < ExplosionPixelSpray.lifetime }
            .map { lemming in
                let burst = PixelExplosion(id: lemming.id, birthTick: simulation.tickCount - lemming.animationFrame,
                    x: lemming.foot.x, y: lemming.foot.y - 6)
                guard lemming.animationFrame < 2, let sprite = spriteHighlight(lemming) else {
                    return MobileExplosion(burst, at: simulation.tickCount)
                }
                return .init(id: burst.id, birthTick: burst.birthTick, rect: sprite.rect,
                    phase: lemming.animationFrame, sprayOrigin: .init(x: Double(burst.x), y: Double(burst.y)))
            }
    }
    public var allNukeExplosionsPlayed: Bool { simulation.lemmings.allSatisfy { !$0.isActive || $0.action == .exploding || $0.action == .exiting } }
    public var nukeRemainingTicks: Int? { simulation.lemmings.filter(\.isActive).compactMap(\.bomberCountdown).min() }
    private let assets: ClassicMainDATAssets?
    private let palette: [ClassicRGBColor]
    private var history: ClassicDOSRewind
    private var simulation: ClassicDOSSimulation { history.simulation }
    private var beforeEndRun: ClassicDOSRewind?
    private let levelInitial: ClassicDOSSimulation
    private var replayInitial: ClassicDOSSimulation
    private var soundCues: [PositionedSoundCue] = []
    private var playbackSkillHistory: [MobileReplaySkillUse] = []
    private var playbackReplay: ClassicDOSReplay?
    private var playbackEvents: [Int: [ClassicDOSReplayEvent]] = [:]
    private var playbackEndTick: Int?
    public private(set) var nukeCount = 0
    public private(set) var rewindCount = 0
    public private(set) var undoCount = 0
    public private(set) var usedRewind = false
    private var settings: ClassicSettings?
    public private(set) var selectionSprite: MobileSpriteHighlight?
    public func spriteHighlight(for actor: Int) -> MobileSpriteHighlight? {
        simulation.lemmings.first(where: { $0.id == actor && Self.canHighlight($0) }).flatMap(spriteHighlight)
    }
    public var rescueSprites: [MobileSpriteHighlight] {
        guard settings?.hdEffectsEnabled == true, settings?.reduceFlashes != true,
              RescueCelebration.isSecured(saved: snapshot.saved, required: snapshot.required,
                  isComplete: snapshot.isComplete, didWin: snapshot.didWin) else { return [] }
        return simulation.lemmings.filter(Self.canHighlight).compactMap(spriteHighlight)
    }
    public private(set) var assignmentSprite: MobileSpriteHighlight?
    public var assignmentProgress: Double? {
        guard let tick = assignmentTick else { return nil }
        let value = Double(simulation.tickCount - tick) / ticksPerSecond / 0.22
        return (0..<1).contains(value) ? value : nil
    }
    private var assignmentID: Int?
    private var assignmentTick: Int?
    public var assignedSkillCount: Int { history.appliedCommands.filter { if case .assign = $0.action { return true }; return false }.count }
    public var replaySkillUses: [MobileReplaySkillUse] {
        guard isReadOnly else { return [] }
        return Array(playbackSkillHistory.suffix(3))
    }
    public var assignedSkills: [String: Int] {
        var counts: [String: Int] = [:]
        for command in history.appliedCommands {
            if case let .assign(_, skill) = command.action { counts[skill.rawValue, default: 0] += 1 }
        }
        return counts
    }
    public var entrancePoint: MobilePoint {
        let point = replayInitial.configuration.entrances.first
        return point.map { MobilePoint(x: Double($0.x), y: Double($0.y)) } ?? initialCameraOrigin
    }
    public var goalPoint: MobilePoint {
        guard let trigger = replayInitial.configuration.triggers.first(where: { $0.effect == .exit }) else {
            return MobilePoint(x: levelSize.width, y: levelSize.height / 2)
        }
        return MobilePoint(x: Double((trigger.bounds.x1 + trigger.bounds.x2) / 2), y: Double((trigger.bounds.y1 + trigger.bounds.y2) / 2))
    }
    public var finalSimulation: ClassicDOSSimulation { simulation }
    public var initialSimulation: ClassicDOSSimulation { levelInitial }
    public var supportsRewind: Bool { true }
    public var isReadOnly: Bool { playbackReplay != nil }

    /// Renders a level, starts its simulation and wraps both in a session.
    ///
    /// Every Classic-engine library goes through here, so official releases and
    /// fan packs share one construction path.
    public static func makeContent(
        summary: MobileLevelSummary,
        level: ClassicLevel,
        ground: ClassicGroundSet,
        special: ClassicSpecialGraphic?,
        assets: ClassicMainDATAssets,
        mechanics: ClassicDOSMechanics,
        objectSemantics: ClassicObjectSemantics,
        clock: ClassicDOSClock = .dos,
        levelIdentifier: String,
        levelIndex: Int,
        artworkFamily: String? = nil, artworkMatch: ClassicMacPieceMatch? = nil
    ) throws -> MobileLevelContent {
        let rendered = try ClassicLevelRenderer.render(
            level, groundSet: ground, specialGraphic: special, objectSemantics: objectSemantics)
        let simulation = try ClassicDOSSimulation(
            level: level, renderedLevel: rendered, mainDATAssets: assets, mechanics: mechanics, clock: clock)
        let palette = try ClassicLemmingPalette.inLevelVGA(terrainPalette: ground.terrainPalette)
        return MobileLevelContent(
            summary: summary,
            session: ClassicMobileSession(
                simulation: simulation,
                renderedLevel: rendered,
                assets: assets,
                palette: palette,
                levelIdentifier: levelIdentifier,
                levelIndex: levelIndex,
                startX: level.startX, authoredLevel: level, ground: ground,
                artworkFamily: artworkFamily, artworkMatch: artworkMatch))
    }

    public init(
        simulation: ClassicDOSSimulation,
        renderedLevel: ClassicRenderedLevel? = nil,
        assets: ClassicMainDATAssets? = nil,
        palette: [ClassicRGBColor] = [],
        levelIdentifier: String,
        levelIndex: Int,
        startX: Int = 0,
        authoredLevel: ClassicLevel? = nil, ground: ClassicGroundSet? = nil,
        artworkFamily: String? = nil, artworkMatch: ClassicMacPieceMatch? = nil, artworkRoot: URL? = Bundle.main.resourceURL
    ) {
        self.authoredLevel = authoredLevel
        self.ground = ground
        self.artworkFamily = artworkFamily
        self.artworkMatch = artworkMatch
        self.artworkRoot = artworkRoot
        initialCameraOrigin = MobilePoint(x: Double(startX), y: 0)
        history = ClassicDOSRewind(simulation: simulation)
        levelInitial = simulation
        replayInitial = simulation
        self.renderedLevel = renderedLevel
        self.assets = assets
        self.palette = palette
        self.levelIdentifier = levelIdentifier
        self.levelIndex = levelIndex
        initialStateHash = ClassicDOSReplayRecorder.stateHash(of: simulation)
        levelFingerprint = initialStateHash
        levelSize = MobileSize(
            width: Double(renderedLevel?.width ?? simulation.terrain.width),
            height: Double(renderedLevel?.height ?? simulation.terrain.height)
        )
    }

    public var snapshot: MobileGameSnapshot {
        MobileGameSnapshot(
            tick: simulation.tickCount,
            released: simulation.releasedCount,
            total: simulation.configuration.totalLemmings,
            saved: simulation.savedCount,
            required: simulation.configuration.requiredToSave,
            remainingSeconds: simulation.remainingTimeSeconds,
            releaseRate: simulation.releaseRate,
            isComplete: simulation.isComplete || (isReadOnly && playbackEndTick.map { simulation.tickCount >= $0 } == true),
            didWin: simulation.didWin,
            isEndingRun: simulation.isNuking,
            skills: ClassicSkill.allCases.map {
                MobileSkillState(name: $0.rawValue.capitalized, count: simulation.remainingSkillCount($0))
            }
        )
    }

    public var panelFrame: MobilePixelFrame? {
        if let cachedPanelFrame { return cachedPanelFrame }
        guard let panel = assets?.panel else { return nil }
        cachedPanelFrame = try? MobilePixelFrame(
            width: panel.width,
            height: panel.height,
            rgba: panel.rgba(using: ClassicLemmingPalette.panelVGA)
        )
        return cachedPanelFrame
    }

    public func tick() {
        if isReadOnly {
            let next = simulation.tickCount + 1
            for event in playbackEvents[next] ?? [] where event.afterTick != true {
                if case .assign = event.action { continue }
                applyReplayAction(event.action)
            }
            let events = history.tick()
            invalidateTerrain(for: events)
            for event in events {
                if case let .skillAssigned(_, skill) = event {
                    recordReplaySkill(skill)
                }
            }
            soundCues += ClassicSoundCue.positionedCues(for: events, lemmings: simulation.lemmings, entrances: simulation.configuration.entrances)
            for event in playbackEvents[simulation.tickCount] ?? [] where event.afterTick == true {
                applyReplayAction(event.action)
            }
        } else {
            let events = history.tick()
            invalidateTerrain(for: events)
            soundCues += ClassicSoundCue.positionedCues(for: events, lemmings: simulation.lemmings, entrances: simulation.configuration.entrances)
        }
        if !simulation.isNuking { beforeEndRun = nil }
    }

    private func invalidateTerrain(for events: [ClassicDOSEvent]) {
        if events.contains(where: {
            switch $0 {
            case .terrainAdded, .terrainRemoved: return true
            default: return false
            }
        }) { terrainFrame = nil }
    }

    public func targetCandidates(for control: Int) -> [MobileTargetCandidate] {
        guard ClassicSkill.allCases.indices.contains(control) else { return [] }
        let skill = ClassicSkill.allCases[control]
        return simulation.lemmings.filter(Self.canHighlight).map { lemming in
            var probe = simulation
            let result = probe.assign(skill, to: lemming.id)
            let state: MobileAssignmentState
            if result == .assigned {
                state = .eligible
            } else if result == .alreadyHasSkill
                || (skill == .climber && lemming.hasClimber)
                || (skill == .floater && lemming.hasFloater)
                || Self.isPerforming(skill, lemming: lemming) {
                state = .alreadyAssigned
            } else {
                state = .unavailable
            }
            return MobileTargetCandidate(
                id: lemming.id,
                point: MobilePoint(x: Double(lemming.foot.x), y: Double(lemming.foot.y - 5)),
                direction: lemming.direction.rawValue,
                assignment: state,
                isBuilding: lemming.action == .building,
                isBlocking: lemming.action == .blocking
            )
        }
    }

    @discardableResult
    public func assign(control: Int, to target: Int) -> Bool {
        guard !isReadOnly, ClassicSkill.allCases.indices.contains(control) else { return false }
        let accepted = history.assign(ClassicSkill.allCases[control], to: target) == .assigned
        if accepted { assignmentID = target; assignmentTick = simulation.tickCount }
        return accepted
    }

    @discardableResult
    public func adjustReleaseRate(by delta: Int) -> Bool {
        guard !isReadOnly, delta != 0, !simulation.isComplete else { return false }
        let before = simulation.releaseRate
        history.setReleaseRate(before + delta)
        return simulation.releaseRate != before
    }

    @discardableResult
    public func beginEndRun() -> Bool {
        guard !isReadOnly, !simulation.isComplete, !simulation.isNuking, beforeEndRun == nil else { return false }
        beforeEndRun = history
        history.beginNuke()
        nukeCount += 1
        return true
    }

    @discardableResult
    public func undoEndRun() -> Bool {
        guard let beforeEndRun else { return false }
        history = beforeEndRun
        terrainFrame = nil
        if replayInitial.tickCount > 0, history.commands.isEmpty { replayInitial = history.simulation }
        self.beforeEndRun = nil
        usedRewind = true
        undoCount += 1
        return true
    }

    public func render(highlight: MobileTargetSelection?) throws -> MobilePixelFrame {
        guard let renderedLevel else { throw MobileSessionError.frameUnavailable }
        let scale = nativeScene == nil ? 1 : 2
        let width = renderedLevel.width * scale, height = renderedLevel.height * scale
        if terrainFrame == nil {
            terrainFrame = nativeScene?.terrainFrame(terrain: simulation.terrain)
                ?? ClassicSceneFrame.terrainRGBA(renderedLevel, terrain: simulation.terrain)
        }
        var pixels = [UInt8](nativeScene?.rgba(simulation: simulation, terrain: terrainFrame)
            ?? ClassicSceneFrame.rgba(renderedLevel, simulation: simulation, terrain: terrainFrame))
        if let assets, palette.count >= 8 {
            for lemming in simulation.lemmings where lemming.isActive {
                if lemming.action == .exploding,
                   !ExplosionPixelSpray.popIsVisible(age: lemming.animationFrame,
                       enhanced: settings?.hdEffectsEnabled != false, singleFrameArtwork: true) { continue }
                if nativeScene != nil, let sprite = spriteHighlight(lemming) {
                    Self.composite([UInt8](sprite.frame.rgba), sourceWidth: sprite.frame.width, sourceHeight: sprite.frame.height,
                        atX: Int(sprite.rect.x * 2), y: Int(sprite.rect.y * 2), into: &pixels, width: width, height: height)
                } else {
                    Self.draw(lemming, assets: assets, palette: palette, backpacks: settings?.showClassicSkillBackpacks == true, into: &pixels,
                          width: width, height: height)
                }
            }
        }
        selectionSprite = nil
        if let highlight, settings?.lemmingSelectionStyle == .modern,
           let lemming = simulation.lemmings.first(where: { $0.id == highlight.id && Self.canHighlight($0) }) {
            selectionSprite = spriteHighlight(lemming)
        }
        assignmentSprite = assignmentProgress == nil ? nil : assignmentID.flatMap { id in
            simulation.lemmings.first(where: { $0.id == id && Self.canHighlight($0) }).flatMap(spriteHighlight)
        }
        if let highlight, simulation.lemmings.contains(where: { $0.id == highlight.id && Self.canHighlight($0) }) {
            Self.drawReticle(highlight, into: &pixels, width: width, height: height, scale: scale)
        }
        if settings?.colorDepth == .amigaOCS {
            for offset in stride(from: 0, to: pixels.count, by: 4) {
                for channel in 0..<3 { pixels[offset + channel] = UInt8((Int(pixels[offset + channel]) * 15 + 127) / 255 * 17) }
            }
        }
        return try MobilePixelFrame(width: width, height: height, rgba: Data(pixels))
    }

    public func checkpointPayload() throws -> Data {
        try prepareCheckpointPayload().encode()
    }

    public func prepareCheckpointPayload() -> MobileCheckpointPayload {
        MobileCheckpointPayload(Checkpoint(
            initialStateHash: initialStateHash,
            simulation: simulation,
            beforeEndRun: beforeEndRun?.simulation,
            nukeCount: nukeCount,
            rewindCount: rewindCount,
            undoCount: undoCount,
            usedRewind: usedRewind,
            history: history,
            beforeEndRunHistory: beforeEndRun,
            replayInitial: replayInitial
        ))
    }

    public func restoreCheckpointPayload(_ data: Data) throws {
        terrainFrame = nil
        let checkpoint = try JSONDecoder().decode(Checkpoint.self, from: data)
        guard [1, 2].contains(checkpoint.version) else { throw MobileCheckpointError.version }
        guard checkpoint.initialStateHash == initialStateHash else { throw MobileSessionError.changedLevel }
        let restored = checkpoint.simulation
        guard restored.terrain.width == simulation.terrain.width,
              restored.terrain.height == simulation.terrain.height,
              !restored.isComplete else {
            throw MobileSessionError.invalidCheckpoint
        }
        if let restoredHistory = checkpoint.history {
            guard ClassicDOSReplayRecorder.stateHash(of: restoredHistory.simulation)
                == ClassicDOSReplayRecorder.stateHash(of: restored),
                restoredHistory.appliedCommands.allSatisfy({ $0.tick <= restored.tickCount }) else {
                throw MobileSessionError.invalidCheckpoint
            }
            history = restoredHistory
        } else { history = ClassicDOSRewind(simulation: restored) }
        beforeEndRun = checkpoint.beforeEndRunHistory
            ?? checkpoint.beforeEndRun.map { ClassicDOSRewind(simulation: $0) }
        replayInitial = checkpoint.replayInitial ?? restored
        usedRewind = checkpoint.usedRewind ?? false
        nukeCount = checkpoint.nukeCount ?? (restored.isNuking ? 1 : 0)
        rewindCount = checkpoint.rewindCount ?? 0
        undoCount = checkpoint.undoCount ?? 0
    }

    @discardableResult public func rewind(seconds: Double) -> Bool {
        terrainFrame = nil
        beforeEndRun = nil
        soundCues.removeAll(keepingCapacity: true)
        if isReadOnly {
            guard seconds.isFinite, seconds >= 0 else { return false }
            let available = max(0, simulation.tickCount - replayInitial.tickCount)
            let ticks = Int(min(Double(available), (seconds * ticksPerSecond).rounded()))
            return seekReplay(to: simulation.tickCount - ticks)
        }
        let previous = simulation.tickCount
        let result = history.rewind(seconds: seconds)
        if result, simulation.tickCount < previous { usedRewind = true; rewindCount += 1 }
        return result
    }

    @discardableResult public func stepBackward() -> Bool {
        terrainFrame = nil
        beforeEndRun = nil
        soundCues.removeAll(keepingCapacity: true)
        if isReadOnly { return seekReplay(to: simulation.tickCount - 1) }
        let result = history.stepBackward()
        if result { usedRewind = true; rewindCount += 1 }
        return result
    }

    @discardableResult public func stepForward() -> Bool {
        guard !simulation.isComplete, playbackEndTick.map({ simulation.tickCount < $0 }) ?? true else { return false }
        tick()
        return true
    }

    public func resumeFromCurrentTick() {
        if !isReadOnly { history.resumeFromCurrentTick() }
    }

    public func replayDocument() throws -> Data? {
        let hash = ClassicDOSReplayRecorder.stateHash(of: replayInitial)
        let outcome = ClassicDOSReplayOutcome(ticks: simulation.tickCount,
            released: simulation.releasedCount, saved: simulation.savedCount,
            required: simulation.configuration.requiredToSave, didWin: simulation.didWin,
            stateHash: ClassicDOSReplayRecorder.stateHash(of: simulation))
        return try JSONEncoder().encode(ClassicDOSReplay(rank: "", number: levelIndex + 1,
            title: levelIdentifier, initialStateHash: hash,
            events: history.appliedCommands.map { .init(tick: $0.tick, action: $0.action, afterTick: true) },
            expected: outcome))
    }

    public func makeReplaySession(document: Data) throws -> (any MobileGameSession)? {
        let replay = try JSONDecoder().decode(ClassicDOSReplay.self, from: document)
        let start: ClassicDOSSimulation
        if replay.initialStateHash == ClassicDOSReplayRecorder.stateHash(of: levelInitial) { start = levelInitial }
        else if replay.initialStateHash == ClassicDOSReplayRecorder.stateHash(of: replayInitial) { start = replayInitial }
        else { throw MobileSessionError.changedLevel }
        guard replay.events.allSatisfy({ $0.tick >= start.tickCount && $0.tick <= (replay.expected?.ticks ?? Int.max) }) else {
            throw MobileSessionError.invalidCheckpoint
        }
        let result = ClassicMobileSession(simulation: start, renderedLevel: renderedLevel,
            assets: assets, palette: palette, levelIdentifier: levelIdentifier, levelIndex: levelIndex,
            startX: Int(initialCameraOrigin.x), authoredLevel: authoredLevel, ground: ground, artworkFamily: artworkFamily, artworkMatch: artworkMatch, artworkRoot: artworkRoot)
        if let settings { result.applySettings(settings) }
        result.playbackReplay = replay
        result.playbackEvents = Dictionary(grouping: replay.events, by: \.tick)
        result.playbackEndTick = replay.expected?.ticks
        result.resetReplay()
        return result
    }

    private func resetReplay() {
        terrainFrame = nil
        playbackSkillHistory.removeAll(keepingCapacity: true)
        var initial = replayInitial
        for event in playbackReplay?.events ?? [] where event.afterTick != true {
            if case let .assign(id, skill) = event.action {
                _ = initial.schedule(.init(tick: event.tick, lemmingID: id, skill: skill))
            }
        }
        history = ClassicDOSRewind(simulation: initial)
        for event in playbackEvents[initial.tickCount] ?? [] { applyReplayAction(event.action) }
    }

    private func seekReplay(to target: Int) -> Bool {
        guard target >= replayInitial.tickCount, target <= (playbackEndTick ?? Int.max) else { return false }
        if target < simulation.tickCount { resetReplay() }
        while simulation.tickCount < target, !simulation.isComplete { tick() }
        soundCues.removeAll(keepingCapacity: true)
        return simulation.tickCount == target
    }

    private func recordReplaySkill(_ skill: ClassicSkill) {
        playbackSkillHistory.append(.init(tick: simulation.tickCount, name: skill.rawValue.capitalized))
        if playbackSkillHistory.count > 3 { playbackSkillHistory.removeFirst() }
    }

    private func applyReplayAction(_ action: ClassicDOSReplayAction) {
        switch action {
        case let .assign(id, skill):
            if history.assign(skill, to: id) == .assigned {
                recordReplaySkill(skill)
            }
        case let .releaseRate(value): history.setReleaseRate(value)
        case .nuke: history.beginNuke()
        }
    }

    public func skillCursorFrame(control: Int) -> MobilePixelFrame? {
        let poses: [ClassicLemmingPose] = [.climbing, .floating, .ohNo, .blocking, .building, .bashing, .mining, .digging]
        guard poses.indices.contains(control), let assets, palette.count >= 8 else { return nil }
        let pose = poses[control]
        if let frame = nativeArtwork?.lemming(pose: pose, left: false, tick: 0) {
            return try? MobilePixelFrame(width: frame.width, height: frame.height, rgba: frame.rgba)
        }
        guard let animation = assets.animation(for: pose, direction: .right) ?? assets.animation(for: pose, direction: .none),
            let frame = animation.frames.first, let rgba = try? frame.rgba(using: palette) else { return nil }
        return try? MobilePixelFrame(width: frame.width, height: frame.height, rgba: rgba)
    }

    public func applySettings(_ settings: ClassicSettings) {
        let changed = self.settings?.graphics != settings.graphics
        self.settings = settings
        guard changed else { return }
        terrainFrame = nil
        nativeScene = nil; nativeArtwork = nil
        guard [.macintosh, .amiga].contains(settings.graphics), let authoredLevel, let renderedLevel,
              let artworkFamily, let artworkRoot else { return }
        if settings.graphics == .amiga, let artworkMatch {
            guard (artworkMatch.share(of: authoredLevel) ?? 1) >= 0.5,
                authoredLevel.specialStyle == 0 || artworkMatch.special else { return }
        }
        let source = settings.graphics == .amiga ? "AmigaArtwork" : "MacArtwork"
        let directory = artworkRoot.appendingPathComponent(source).appendingPathComponent(artworkFamily)
        let art = try? (artworkRoot == Bundle.main.resourceURL
            ? ClassicMobileArtworkCache.shared.load(directory) : ClassicMacArtwork(directory: directory))
        guard let art,
              let scene = try? ClassicMacScene(level: authoredLevel, rendered: renderedLevel, artwork: art,
                  groundSet: ground, match: artworkMatch, reconstructUnmatched: settings.graphics == .macintosh) else { return }
        nativeArtwork = art; nativeScene = scene
    }

    static func family(for title: ClassicTitle?) -> String? {
        switch title {
        case .lemmings: return "lemmings"
        case .ohNoMoreLemmings: return "ohno"
        case .xmasLemmings1991, .xmasLemmings1992: return "xmas"
        case .holidayLemmings1993, .holidayLemmings1994: return "holiday"
        default: return nil
        }
    }

    public func drainSoundCues() -> [PositionedSoundCue] {
        defer { soundCues.removeAll(keepingCapacity: true) }
        return soundCues
    }

    public func releaseTransientResources() { terrainFrame = nil; cachedPanelFrame = nil }

    private func spriteHighlight(_ lemming: ClassicDOSLemming) -> MobileSpriteHighlight? {
        guard let assets, palette.count >= 8 else { return nil }
        let pose = Self.pose(for: lemming.action)
        let direction: ClassicSpriteDirection = lemming.direction == .left ? .left : .right
        guard let animation = assets.animation(for: pose, direction: direction)
            ?? assets.animation(for: pose, direction: .none), !animation.frames.isEmpty else { return nil }
        let index = abs(lemming.animationFrame) % animation.frames.count
        let frame = animation.frames[index]
        if nativeScene != nil, let native = nativeArtwork?.lemming(pose: pose, left: lemming.direction == .left, tick: lemming.animationFrame) {
            let pack = settings?.showClassicSkillBackpacks == true
                ? Self.backpackPixels(native.rgba, width: native.width, height: native.height, lemming: lemming, pose: pose, scale: 2)
                : (pixels: [UInt8](native.rgba), width: native.width, padding: 0)
            guard let bitmap = try? MobilePixelFrame(width: pack.width, height: native.height, rgba: Data(pack.pixels)) else { return nil }
            let key = "native/\(levelFingerprint)/\(String(describing: settings?.graphics))/\(pose)/\(direction)/\(lemming.animationFrame)/\(lemming.hasClimber)/\(lemming.hasFloater)/\(settings?.showClassicSkillBackpacks == true)"
            let reduced = settings?.reduceMotion == true || settings?.reduceFlashes == true
            return .init(frame: bitmap,
                rect: .init(x: Double(lemming.foot.x + animation.offsetX) + Double(native.x - pack.padding) / 2,
                    y: Double(lemming.foot.y + animation.offsetY) + Double(native.y) / 2,
                    width: Double(pack.width) / 2, height: Double(native.height) / 2),
                cacheKey: key, time: reduced ? nil : Double(simulation.tickCount) / ticksPerSecond)
        }
        guard let rgba = try? frame.rgba(using: palette) else { return nil }
        let pack = settings?.showClassicSkillBackpacks == true
            ? Self.backpackPixels(rgba, width: frame.width, height: frame.height, lemming: lemming, pose: pose)
            : (pixels: [UInt8](rgba), width: frame.width, padding: 0)
        guard let bitmap = try? MobilePixelFrame(width: pack.width, height: frame.height, rgba: Data(pack.pixels)) else { return nil }
        let reduced = settings?.reduceMotion == true || settings?.reduceFlashes == true
        return .init(frame: bitmap,
            rect: .init(x: Double(lemming.foot.x + animation.offsetX - pack.padding), y: Double(lemming.foot.y + animation.offsetY),
                        width: Double(pack.width), height: Double(frame.height)),
            cacheKey: "\(levelFingerprint)/\(pose)/\(direction)/\(index)/\(lemming.hasClimber)/\(lemming.hasFloater)/\(settings?.showClassicSkillBackpacks == true)",
            time: reduced ? nil : Double(simulation.tickCount) / ticksPerSecond)
    }

    private static func canHighlight(_ lemming: ClassicDOSLemming) -> Bool {
        guard lemming.isActive else { return false }
        switch lemming.action {
        case .exploding, .splatting, .drowning, .vaporizing, .exiting: return false
        default: return true
        }
    }

    private static func isPerforming(_ skill: ClassicSkill, lemming: ClassicDOSLemming) -> Bool {
        switch skill {
        case .bomber: return lemming.bomberCountdown != nil
        case .blocker: return lemming.action == .blocking
        case .builder: return lemming.action == .building
        case .basher: return lemming.action == .bashing
        case .miner: return lemming.action == .mining
        case .digger: return lemming.action == .digging
        case .climber, .floater: return false
        }
    }

    private static func pose(for action: ClassicDOSAction) -> ClassicLemmingPose {
        switch action {
        case .walking: return .walking
        case .falling: return .falling
        case .jumping: return .jumping
        case .climbing: return .climbing
        case .hoisting: return .postClimb
        case .floating: return .floating
        case .splatting: return .splatting
        case .exiting: return .exiting
        case .drowning: return .drowning
        case .vaporizing: return .frying
        case .blocking: return .blocking
        case .building: return .building
        case .shrugging: return .shrugging
        case .bashing: return .bashing
        case .mining: return .mining
        case .digging: return .digging
        case .ohNo: return .ohNo
        case .exploding: return .explosion
        }
    }

    private static func draw(
        _ lemming: ClassicDOSLemming,
        assets: ClassicMainDATAssets,
        palette: [ClassicRGBColor],
        backpacks: Bool,
        into destination: inout [UInt8],
        width: Int,
        height: Int
    ) {
        let pose = pose(for: lemming.action)
        let direction: ClassicSpriteDirection = lemming.direction == .left ? .left : .right
        guard let animation = assets.animation(for: pose, direction: direction)
                ?? assets.animation(for: pose, direction: .none),
              !animation.frames.isEmpty else { return }
        let frame = animation.frames[abs(lemming.animationFrame) % animation.frames.count]
        guard let source = try? frame.rgba(using: palette) else { return }
        let pack = backpacks ? backpackPixels(source, width: frame.width, height: frame.height,
            lemming: lemming, pose: pose) : (pixels: [UInt8](source), width: frame.width, padding: 0)
        composite(
            pack.pixels,
            sourceWidth: pack.width,
            sourceHeight: frame.height,
            atX: lemming.foot.x + animation.offsetX - pack.padding,
            y: lemming.foot.y + animation.offsetY,
            into: &destination,
            width: width,
            height: height
        )
    }

    private static func backpackPixels(_ source: Data, width: Int, height: Int,
        lemming: ClassicDOSLemming, pose: ClassicLemmingPose, scale: Int = 1) -> (pixels: [UInt8], width: Int, padding: Int) {
        guard lemming.hasClimber || lemming.hasFloater else { return ([UInt8](source), width, 0) }
        switch pose {
        case .drowning, .splatting, .frying, .explosion, .exiting: return ([UInt8](source), width, 0)
        default: break
        }
        let padding = 2 * scale, outputWidth = width + 4 * scale
        var pixels = [UInt8](repeating: 0, count: outputWidth * height * 4)
        var hairTop = height
        var body: [(x: Int, y: Int)] = []
        for y in 0..<height { for x in 0..<width {
            let from = (y * width + x) * 4, to = (y * outputWidth + x + padding) * 4
            for channel in 0..<4 { pixels[to + channel] = source[from + channel] }
            guard source[from + 3] > 0 else { continue }
            let r = Int(source[from]), g = Int(source[from + 1]), b = Int(source[from + 2])
            if g > 100 && g > r * 2 && g > b * 2 { hairTop = min(hairTop, y) }
            if (b > 128 && b > r * 2 && b > g * 2) || (r > 128 && r > g * 2 && r > b * 2) { body.append((x, y)) }
        } }
        let upright = body.filter { $0.y >= hairTop + 3 * scale }
        let torso = upright.isEmpty ? body : upright
        guard let top = torso.map(\.y).min() else { return (pixels, outputWidth, padding) }
        let shoulders = torso.filter { $0.y < top + 2 * scale }
        var left = lemming.direction == .left
        if pose == .floating || pose == .umbrellaOpening { left.toggle() }
        guard let back = left ? shoulders.map(\.x).max() : shoulders.map(\.x).min() else { return (pixels, outputWidth, padding) }
        let origin = padding + (left ? back + scale : back - 2 * scale)
        let colours: [[UInt8]] = lemming.hasClimber && lemming.hasFloater
            ? [[206, 138, 240], [155, 78, 198], [96, 42, 135]]
            : lemming.hasFloater ? [[255, 192, 75], [240, 133, 36], [178, 72, 20]]
            : [[205, 149, 83], [151, 92, 47], [100, 58, 32]]
        for y in 0..<(3 * scale) where top + y < height { for x in 0..<(2 * scale) {
            let px = origin + x
            guard (0..<outputWidth).contains(px) else { continue }
            let index = ((top + y) * outputWidth + px) * 4
            let r = Int(pixels[index]), g = Int(pixels[index + 1]), b = Int(pixels[index + 2])
            if pixels[index + 3] > 0 && ((g > 100 && g > r * 2 && g > b * 2)
                || (r > 180 && g > 150 && b > 130) || (r > 220 && g > 120 && b < 70)) { continue }
            let colour = colours[y / scale == 0 ? 0 : ((left ? x / scale == 1 : x / scale == 0) ? 2 : 1)]
            for channel in 0..<3 { pixels[index + channel] = colour[channel] }
            pixels[index + 3] = 255
        } }
        return (pixels, outputWidth, padding)
    }

    private static func composite(
        _ source: [UInt8],
        sourceWidth: Int,
        sourceHeight: Int,
        atX originX: Int,
        y originY: Int,
        into destination: inout [UInt8],
        width: Int,
        height: Int
    ) {
        guard source.count == sourceWidth * sourceHeight * 4 else { return }
        for y in 0..<sourceHeight {
            let destinationY = originY + y
            guard (0..<height).contains(destinationY) else { continue }
            for x in 0..<sourceWidth {
                let destinationX = originX + x
                guard (0..<width).contains(destinationX) else { continue }
                let src = (y * sourceWidth + x) * 4
                let alpha = Int(source[src + 3])
                guard alpha > 0 else { continue }
                let dst = (destinationY * width + destinationX) * 4
                if alpha == 255 {
                    destination[dst] = source[src]
                    destination[dst + 1] = source[src + 1]
                    destination[dst + 2] = source[src + 2]
                    destination[dst + 3] = 255
                } else {
                    let inverse = 255 - alpha
                    for channel in 0..<3 {
                        destination[dst + channel] = UInt8(
                            (Int(source[src + channel]) * alpha + Int(destination[dst + channel]) * inverse) / 255
                        )
                    }
                    destination[dst + 3] = 255
                }
            }
        }
    }

    private static func drawReticle(
        _ selection: MobileTargetSelection,
        into pixels: inout [UInt8],
        width: Int,
        height: Int, scale: Int = 1
    ) {
        let colour: (UInt8, UInt8, UInt8)
        switch selection.state {
        case .eligible: colour = (116, 255, 26)
        case .alreadyAssigned: colour = (255, 151, 32)
        case .unavailable: colour = (140, 140, 140)
        }
        let centreX = Int((selection.point.x * Double(scale)).rounded())
        let centreY = Int((selection.point.y * Double(scale)).rounded())
        let radius = 8 * scale
        let marks = (-radius...radius).flatMap { offset -> [(Int, Int)] in
            guard abs(offset) >= radius - 2 * scale else { return [] }
            return [
                (centreX + offset, centreY - radius),
                (centreX + offset, centreY + radius),
                (centreX - radius, centreY + offset),
                (centreX + radius, centreY + offset),
            ]
        }
        for (x, y) in marks where (0..<width).contains(x) && (0..<height).contains(y) {
            let offset = (y * width + x) * 4
            pixels[offset] = colour.0
            pixels[offset + 1] = colour.1
            pixels[offset + 2] = colour.2
            pixels[offset + 3] = 255
        }
    }
}
