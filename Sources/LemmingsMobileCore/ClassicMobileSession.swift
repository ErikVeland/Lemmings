import Foundation
import LemmingsAppCore
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
        let packName = dataSet.name
        levels = dataSet.campaign.levels.enumerated().map { index, item in
            MobileLevelSummary(
                index: index,
                rank: item.rank,
                number: item.number,
                title: item.level.title, origin: .official, packName: packName
            )
        }
    }

    public func canSkipLevel(at index: Int) -> Bool {
        levels.indices.contains(index) && levels.indices.contains(index + 1)
    }
    public func prepareLevelSkip(at index: Int) throws -> () throws -> Void {
        guard canSkipLevel(at: index) else { throw MobileSessionError.changedLevel }
        return {}
    }

    public func checkpointLevelIdentifier(at index: Int) throws -> String? {
        guard dataSet.campaign.levels.indices.contains(index) else { throw MobileSessionError.changedLevel }
        let entry = dataSet.campaign.levels[index]
        return "\(dataSet.identifierKey)/\(entry.rank)/\(entry.number)"
    }

    public func loadLevel(at index: Int) throws -> MobileLevelContent {
        try Task.checkCancellation()
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
    public var familiarNamesStore: FamiliarNamesStore? = .shared
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
        var bonusSkillID: String? = nil
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
    private let terrainLease = RuntimePixelCacheLease()
    private var terrainFrame: Data?
    private var cachedPanelFrame: MobilePixelFrame?
    public var renderScale: Double { nativeScene == nil ? 1 : 2 }
    public var spriteActorIDs: [Int] { simulation.lemmings.filter { $0.isActive }.map(\.id) }
    public var activeLemmingCount: Int { simulation.activeCount }
    public var minimapActorPoints: [MobilePoint] { simulation.lemmings.filter(\.isActive).map { .init(x: Double($0.foot.x), y: Double($0.foot.y)) } }
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
    private var playbackAssignedSkills: [String: Int] = [:]
    private var playbackReplay: ClassicDOSReplay?
    public private(set) var replayMoveNavigation = ReplayMoveNavigation(ticks: [])
    private var playbackEvents: [Int: [ClassicDOSReplayEvent]] = [:]
    private var playbackEndTick: Int?
    public private(set) var nukeCount = 0
    public private(set) var rewindCount = 0
    public private(set) var undoCount = 0
    public private(set) var usedRewind = false
    public private(set) var bonusSkillID: String?
    public var existingLevelSkills: Set<String> {
        Set(levelInitial.configuration.initialSkills.filter { $0.value > 0 }.map { $0.key.rawValue })
    }
    public var extraSkillChoices: [MobileExtraSkillChoice] {
        guard !isReadOnly, bonusSkillID == nil else { return [] }
        return ClassicSkill.allCases.enumerated().compactMap { index, skill in
            guard history.canGrantBonusSkill(skill) else { return nil }
            return .init(skillID: skill.rawValue, title: SkillVocabulary.title(skill.rawValue), control: index)
        }
    }
    @discardableResult public func grantExtraSkill(_ choice: MobileExtraSkillChoice) -> Bool {
        guard extraSkillChoices.contains(choice), ClassicSkill.allCases.indices.contains(choice.control),
              history.grantBonusSkill(ClassicSkill.allCases[choice.control]) else { return false }
        bonusSkillID = choice.skillID
        cachedRender = nil; cachedPanelFrame = nil
        return true
    }
    @discardableResult public func retainExtraSkillUse(_ skillID: String) -> Bool {
        guard !isReadOnly, existingLevelSkills.contains(skillID), bonusSkillID == nil || bonusSkillID == skillID else { return false }
        bonusSkillID = skillID
        return true
    }
    private var settings: ClassicSettings?
    public private(set) var selectionSprite: MobileSpriteHighlight?
    public func spriteHighlight(for actor: Int) -> MobileSpriteHighlight? {
        simulation.lemmings.first(where: { $0.id == actor && Self.canHighlight($0) }).flatMap(spriteHighlight)
    }
    public var rescueSprites: [MobileSpriteHighlight] {
        guard settings?.hdEffectsEnabled == true, settings?.reduceFlashes != true,
              RescueCelebration.isSecured(saved: simulation.savedCount, required: simulation.configuration.requiredToSave,
                  isComplete: isSimulationComplete, didWin: simulation.didWin) else { return [] }
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
    public var assignedSkillCount: Int {
        if isReadOnly { return playbackAssignedSkills.values.reduce(0, +) }
        return history.appliedCommands.filter { if case .assign = $0.action { return true }; return false }.count
    }
    public var replaySkillUses: [MobileReplaySkillUse] {
        guard isReadOnly else { return [] }
        return Array(playbackSkillHistory.suffix(3))
    }
    public var assignedSkills: [String: Int] {
        if isReadOnly { return playbackAssignedSkills }
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
    public var replayEndTick: Int? { playbackEndTick }

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
        try Task.checkCancellation()
        let rendered = try ClassicLevelRenderer.render(
            level, groundSet: ground, specialGraphic: special, objectSemantics: objectSemantics)
        try Task.checkCancellation()
        let simulation = try ClassicDOSSimulation(
            level: level, renderedLevel: rendered, mainDATAssets: assets, mechanics: mechanics, clock: clock)
        try Task.checkCancellation()
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
        levelFingerprint = simulation.levelSourceFingerprint
        levelSize = MobileSize(
            width: Double(renderedLevel?.width ?? simulation.terrain.width),
            height: Double(renderedLevel?.height ?? simulation.terrain.height)
        )
    }

    public var isSimulationComplete: Bool {
        simulation.isComplete || (isReadOnly && playbackEndTick.map { simulation.tickCount >= $0 } == true)
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
        cachedRender = nil
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

    public func targetWallDirection(for target: Int) -> Int? {
        guard let lemming = simulation.lemmings.first(where: { $0.id == target }) else { return nil }
        return LemmingApproachTargeting.wallDirection(x: lemming.foot.x, footY: lemming.foot.y) {
            simulation.terrain.isSolid(x: $0, y: $1)
        }
    }

    public func targetCandidates(for control: Int) -> [MobileTargetCandidate] {
        guard ClassicSkill.allCases.indices.contains(control) else { return [] }
        let skill = ClassicSkill.allCases[control]
        let results = simulation.assignmentResults(for: skill)
        return simulation.lemmings.enumerated().compactMap { index, lemming in
            guard Self.canHighlight(lemming) else { return nil }
            let result = results[index]
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
        cachedRender = nil
        guard !isReadOnly, ClassicSkill.allCases.indices.contains(control) else { return false }
        let accepted = history.assign(ClassicSkill.allCases[control], to: target) == .assigned
        if accepted {
            assignmentID = target; assignmentTick = simulation.tickCount
            soundCues += ClassicSoundCue.positionedCues(for: simulation.lastTickEvents,
                lemmings: simulation.lemmings, entrances: simulation.configuration.entrances)
        }
        return accepted
    }

    @discardableResult
    public func adjustReleaseRate(by delta: Int) -> Bool {
        cachedRender = nil
        guard !isReadOnly, delta != 0, !simulation.isComplete else { return false }
        let before = simulation.releaseRate
        history.setReleaseRate(before + delta)
        return simulation.releaseRate != before
    }

    @discardableResult
    public func beginEndRun() -> Bool {
        cachedRender = nil
        guard !isReadOnly, !simulation.isComplete, !simulation.isNuking, beforeEndRun == nil else { return false }
        beforeEndRun = history
        history.beginNuke()
        nukeCount += 1
        return true
    }

    @discardableResult
    public func undoEndRun() -> Bool {
        cachedRender = nil
        guard let beforeEndRun else { return false }
        history = beforeEndRun
        terrainFrame = nil
        if replayInitial.tickCount > 0, history.commands.isEmpty { replayInitial = history.simulation }
        self.beforeEndRun = nil
        usedRewind = true
        undoCount += 1
        return true
    }

    private var ghostReplay: ClassicDOSReplay?
    private var solutionGhost: ClassicSolutionGhost?
    private var ghostFrames: [String: SolutionGhostPixels] = [:]
    private struct SpriteKey: Hashable {
        let pose: ClassicLemmingPose
        let left: Bool
        let phase: Int
        let climber: Bool
        let floater: Bool
    }
    private var spriteFrames: [SpriteKey: MobileSpriteHighlight] = [:]
    private var cachedRender: (selection: MobileTargetSelection?, region: SceneRasterContext.Viewport?, actors: Bool, frame: MobilePixelFrame)?
    public var ghostSolutionEnabled = false { didSet { cachedRender = nil } }
    public var hasGhostSolution: Bool { solutionGhost != nil }
    public var ghostSolutionTick: Int? { solutionGhost?.simulation.tickCount }

    /// Install only after the player has revealed the verified full solution.
    @discardableResult public func installGhostSolution(_ replay: ClassicDOSReplay) -> Bool {
        guard !isReadOnly, let ghost = ClassicSolutionGhost(initial: levelInitial, replay: replay) else { return false }
        solutionGhost = ghost
        ghostReplay = replay
        ghostSolutionEnabled = false
        ghostFrames.removeAll()
        return true
    }

    public func inheritGhostSolution(from previous: ClassicMobileSession) {
        guard let replay = previous.ghostReplay, installGhostSolution(replay) else { return }
        ghostSolutionEnabled = previous.ghostSolutionEnabled
    }

    private var ghostPlayback: HotSeatGhostPlayback?
    public var hotSeatGhosts: HotSeatGhostPlayback? {
        get { ghostPlayback }
        set { ghostPlayback = newValue; cachedRender = nil }
    }
    public var actionReplayInitial: ActionReplayState? { .classic(levelInitial) }

    public var lemmingInspection: LemmingInspection? {
        guard !isReadOnly else { return nil }
        let commands = history.appliedCommands.compactMap {
            try? LeaderboardActionReplay.Command.classic(.init(tick: $0.tick, action: $0.action, afterTick: true))
        }
        return try? LemmingInspection(initial: .classic(levelInitial), current: .classic(simulation), commands: commands, familiarNames: familiarNamesStore)
    }

    public func actionCapture() throws -> MobileActionCapture? {
        // Older checkpoints without history start part-way through. Their commands cannot replay from tick 0.
        guard !isReadOnly, replayInitial.tickCount == 0 else { return nil }
        let commands = try history.appliedCommands.map {
            try LeaderboardActionReplay.Command.classic(.init(tick: $0.tick, action: $0.action, afterTick: true))
        }
        return .init(initial: .classic(levelInitial), final: .classic(simulation), commands: commands)
    }

    private func drawHotSeatGhosts(into pixels: inout Data, width: Int, height: Int, scale: Int) {
        guard ghostPlayback != nil else { return }
        let ghosts = ghostPlayback!.states(at: simulation.tickCount) { state -> ClassicDOSSimulation? in
            if case let .classic(ghost) = state { return ghost }
            return nil
        }
        for ghost in ghosts {
            for lemming in ghost.state.lemmings where lemming.isActive {
                guard let sprite = spriteHighlight(lemming) else { continue }
                let key = "\(sprite.cacheKey)|\(ghost.colour.rawValue)"
                let frame = ghostFrames[key] ?? SolutionGhostPixels(rgba: sprite.frame.rgba,
                    width: sprite.frame.width, height: sprite.frame.height, pixelScale: scale, colour: ghost.colour)
                if ghostFrames.count >= 512 { ghostFrames.removeAll(keepingCapacity: true) }
                ghostFrames[key] = frame
                Self.composite(frame.rgba, sourceWidth: frame.width, sourceHeight: frame.height,
                    atX: Int(sprite.rect.x * Double(scale)) - frame.padding,
                    y: Int(sprite.rect.y * Double(scale)) - frame.padding,
                    into: &pixels, width: width, height: height)
            }
        }
    }

    private func drawSolutionGhost(into pixels: inout Data, width: Int, height: Int, scale: Int) {
        guard ghostSolutionEnabled, solutionGhost != nil else { return }
        solutionGhost?.synchronise(to: simulation.tickCount)
        guard let ghost = solutionGhost else { return }
        for lemming in ghost.simulation.lemmings where lemming.isActive {
            guard let sprite = spriteHighlight(lemming) else { continue }
            let frame = ghostFrames[sprite.cacheKey] ?? SolutionGhostPixels(rgba: sprite.frame.rgba,
                width: sprite.frame.width, height: sprite.frame.height, pixelScale: scale)
            if ghostFrames.count >= 512 { ghostFrames.removeAll(keepingCapacity: true) }
            ghostFrames[sprite.cacheKey] = frame
            Self.composite(frame.rgba, sourceWidth: frame.width, sourceHeight: frame.height,
                atX: Int(sprite.rect.x * Double(scale)) - frame.padding,
                y: Int(sprite.rect.y * Double(scale)) - frame.padding,
                into: &pixels, width: width, height: height)
        }
    }

    public func render(highlight: MobileTargetSelection?) throws -> MobilePixelFrame {
        if let cachedRender, cachedRender.selection == highlight, cachedRender.region == SceneRasterContext.viewport, cachedRender.actors == SceneRasterContext.drawActors.wrappedValue { return cachedRender.frame }
        guard let renderedLevel else { throw MobileSessionError.frameUnavailable }
        let scale = nativeScene == nil ? 1 : 2
        let width = renderedLevel.width * scale, height = renderedLevel.height * scale
        if !terrainLease.reserve(bytes: width * height * 4) { terrainFrame = nil }
        if terrainFrame == nil {
            terrainFrame = nativeScene?.terrainFrame(terrain: simulation.terrain)
                ?? ClassicSceneFrame.terrainRGBA(renderedLevel, terrain: simulation.terrain)
        }
        // The frame stays in one buffer from composition to presentation.
        // Apple TV has no app EDR. Reduced colour depth keeps the period look.
        #if os(tvOS)
        let wantsGlints = false
        #else
        let wantsGlints = settings?.hdEffectsEnabled != false && settings?.colorDepth != .amigaOCS
        #endif
        let native = nativeScene.map { scene in
            wantsGlints ? scene.rgbaWithArrowGlints(simulation: simulation, terrain: terrainFrame)
                : (rgba: scene.rgba(simulation: simulation, terrain: terrainFrame), glints: nil)
        }
        var pixels = native?.rgba
            ?? ClassicSceneFrame.rgba(renderedLevel, simulation: simulation, terrain: terrainFrame)
        if SceneRasterContext.drawActors.wrappedValue {
            drawSolutionGhost(into: &pixels, width: width, height: height, scale: scale)
            drawHotSeatGhosts(into: &pixels, width: width, height: height, scale: scale)
            if assets != nil, palette.count >= 8 {
                var crowdShadow = MobileCrowdShadow()
                for lemming in simulation.lemmings where lemming.isActive {
                    if lemming.action == .exploding,
                       !ExplosionPixelSpray.popIsVisible(age: lemming.animationFrame,
                           enhanced: settings?.hdEffectsEnabled != false, singleFrameArtwork: true) { continue }
                    if let sprite = spriteHighlight(lemming) {
                        if lemming.action != .exploding {
                            pixels.withUnsafeMutableBytes { destination in
                                sprite.frame.rgba.withUnsafeBytes { (source: UnsafeRawBufferPointer) in
                                    crowdShadow.cast(spriteWidth: sprite.frame.width, spriteHeight: sprite.frame.height,
                                        x: Int(sprite.rect.x * Double(scale)), y: Int(sprite.rect.y * Double(scale)),
                                        width: width, height: height, pixels: destination,
                                        opaque: { sx, sy in source[(sy * sprite.frame.width + sx) * 4 + 3] >= 128 })
                                }
                            }
                        }
                        Self.composite(sprite.frame.rgba, sourceWidth: sprite.frame.width, sourceHeight: sprite.frame.height,
                            atX: Int(sprite.rect.x * Double(scale)), y: Int(sprite.rect.y * Double(scale)), into: &pixels, width: width, height: height)
                    }
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
            pixels.withUnsafeMutableBytes { (pixels: UnsafeMutableRawBufferPointer) in
                for offset in stride(from: 0, to: pixels.count, by: 4) {
                    for channel in 0..<3 { pixels[offset + channel] = MobileColourDepth.ocs[Int(pixels[offset + channel])] }
                }
            }
        }
        let frame = try MobilePixelFrame(width: width, height: height, rgba: pixels, arrowGlints: native?.glints)
        cachedRender = (highlight, SceneRasterContext.viewport, SceneRasterContext.drawActors.wrappedValue, frame)
        if !terrainLease.reserve(bytes: width * height * 4) { terrainFrame = nil }
        return frame
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
            replayInitial: replayInitial,
            bonusSkillID: bonusSkillID
        ))
    }

    public func restoreCheckpointPayload(_ data: Data) throws {
        cachedRender = nil
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
        bonusSkillID = checkpoint.bonusSkillID
    }

    public var earliestRewindTick: Int { isReadOnly ? replayInitial.tickCount : history.earliestTick }

    public func prepareSeek(to tick: Int, backwardSteps: Int) -> MobileSeekOperation? {
        if isReadOnly {
            guard tick >= replayInitial.tickCount, tick <= (playbackEndTick ?? Int.max) else { return nil }
            let copy = ClassicMobileSession(simulation: replayInitial, renderedLevel: renderedLevel,
                assets: assets, palette: palette, levelIdentifier: levelIdentifier, levelIndex: levelIndex,
                startX: Int(initialCameraOrigin.x), authoredLevel: authoredLevel, ground: ground,
                artworkFamily: artworkFamily, artworkMatch: artworkMatch, artworkRoot: artworkRoot)
            copy.playbackReplay = playbackReplay; copy.playbackEvents = playbackEvents
            copy.playbackEndTick = playbackEndTick
            copy.resetReplay()
            let originalTick = simulation.tickCount
            return MobileSeekOperation { [weak self] deadline in
                while copy.simulation.tickCount < tick, !copy.simulation.isComplete {
                    copy.tick()
                    if ProcessInfo.processInfo.systemUptime >= deadline { return false }
                }
                guard let self, self.simulation.tickCount == originalTick, copy.simulation.tickCount == tick else {
                    throw MobileSessionError.invalidCheckpoint
                }
                self.history = copy.history
                self.playbackSkillHistory = copy.playbackSkillHistory
                self.playbackAssignedSkills = copy.playbackAssignedSkills
                self.cachedRender = nil; self.terrainFrame = nil; self.beforeEndRun = nil
                self.soundCues.removeAll(keepingCapacity: true)
                return true
            }
        }
        guard tick < simulation.tickCount, tick >= history.earliestTick,
              var cursor = history.preparedSeek(toTick: tick) else { return nil }
        let originalTick = simulation.tickCount
        return MobileSeekOperation { [weak self] deadline in
            while cursor.currentTick < tick {
                guard cursor.seek(toTick: cursor.currentTick + 1) else { throw MobileSessionError.invalidCheckpoint }
                if ProcessInfo.processInfo.systemUptime >= deadline { return false }
            }
            guard let self, self.simulation.tickCount == originalTick else { throw CancellationError() }
            self.history = cursor
            self.cachedRender = nil
            self.terrainFrame = nil
            self.beforeEndRun = nil
            self.soundCues.removeAll(keepingCapacity: true)
            if !self.isReadOnly { self.usedRewind = true; self.rewindCount += max(1, backwardSteps) }
            return true
        }
    }

    @discardableResult public func rewind(seconds: Double) -> Bool {
        cachedRender = nil
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
        cachedRender = nil
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
            initialLevelFingerprint: replayInitial.levelSourceFingerprint,
            events: history.appliedCommands.map { .init(tick: $0.tick, action: $0.action, afterTick: true) },
            expected: outcome))
    }

    public func makeReplaySession(document: Data) throws -> (any MobileGameSession)? {
        let replay = try JSONDecoder().decode(ClassicDOSReplay.self, from: document)
        if let expectedFingerprint = replay.initialLevelFingerprint,
           expectedFingerprint != levelInitial.levelSourceFingerprint {
            throw MobileSessionError.changedLevel
        }
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
        result.replayMoveNavigation = .classic(initial: start, replay: replay)
        result.resetReplay()
        return result
    }

    private func resetReplay() {
        terrainFrame = nil
        playbackSkillHistory.removeAll(keepingCapacity: true)
        playbackAssignedSkills.removeAll(keepingCapacity: true)
        var initial = replayInitial
        for event in playbackReplay?.events ?? [] where event.afterTick != true {
            if case let .assign(id, skill) = event.action {
                _ = initial.schedule(.init(tick: event.tick, lemmingID: id, skill: skill))
            }
        }
        history = ClassicDOSRewind(simulation: initial)
        for event in playbackEvents[initial.tickCount] ?? [] { applyReplayAction(event.action) }
    }

    public func seekReplay(to target: Int) -> Bool {
        cachedRender = nil
        guard isReadOnly, target >= replayInitial.tickCount, target <= (playbackEndTick ?? Int.max) else { return false }
        if target < simulation.tickCount { resetReplay() }
        while simulation.tickCount < target, !simulation.isComplete { tick() }
        soundCues.removeAll(keepingCapacity: true)
        return simulation.tickCount == target
    }

    private func recordReplaySkill(_ skill: ClassicSkill) {
        playbackAssignedSkills[skill.rawValue, default: 0] += 1
        playbackSkillHistory.append(.init(tick: simulation.tickCount, name: skill.rawValue.capitalized))
        if playbackSkillHistory.count > 3 { playbackSkillHistory.removeFirst() }
    }

    private func applyReplayAction(_ action: ClassicDOSReplayAction) {
        switch action {
        case let .assign(id, skill):
            if history.assign(skill, to: id) == .assigned {
                recordReplaySkill(skill)
                soundCues += ClassicSoundCue.positionedCues(for: simulation.lastTickEvents,
                    lemmings: simulation.lemmings, entrances: simulation.configuration.entrances)
            }
        case let .releaseRate(value): history.setReleaseRate(value)
        case let .bonusSkill(skill): _ = history.grantBonusSkill(skill)
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

    public var availableGraphics: [ClassicGraphicsSource] {
        guard authoredLevel != nil, renderedLevel != nil, let artworkFamily, let artworkRoot else { return [.dosVGA] }
        let optionalSources: [ClassicGraphicsSource] = [.amiga, .macintosh, .macintoshMonochrome]
        let installed = optionalSources.filter { source in
            if source == .amiga, let artworkMatch, let authoredLevel {
                guard (artworkMatch.share(of: authoredLevel) ?? 1) >= 0.5,
                      authoredLevel.specialStyle == 0 || artworkMatch.special else { return false }
            }
            let folder = source == .amiga ? "AmigaArtwork"
                : source == .macintoshMonochrome ? "MacArtwork/monochrome" : "MacArtwork"
            let directory = artworkRoot.appendingPathComponent(folder).appendingPathComponent(artworkFamily)
            return (try? ClassicMobileArtworkCache.shared.load(directory)) != nil
        }
        return [.dosVGA] + installed
    }

    public func applySettings(_ settings: ClassicSettings) {
        cachedRender = nil
        let changed = self.settings?.graphics != settings.graphics
        if changed || self.settings?.showClassicSkillBackpacks != settings.showClassicSkillBackpacks {
            spriteFrames.removeAll(keepingCapacity: true)
        }
        self.settings = settings
        ghostFrames.removeAll(keepingCapacity: true)
        guard changed else { return }
        terrainFrame = nil
        nativeScene = nil; nativeArtwork = nil
        guard [.macintosh, .macintoshMonochrome, .amiga].contains(settings.graphics), let authoredLevel, let renderedLevel,
              let artworkFamily, let artworkRoot else { return }
        if settings.graphics == .amiga, let artworkMatch {
            guard (artworkMatch.share(of: authoredLevel) ?? 1) >= 0.5,
                authoredLevel.specialStyle == 0 || artworkMatch.special else { return }
        }
        let source = settings.graphics == .amiga ? "AmigaArtwork"
            : settings.graphics == .macintoshMonochrome ? "MacArtwork/monochrome" : "MacArtwork"
        let directory = artworkRoot.appendingPathComponent(source).appendingPathComponent(artworkFamily)
        let art = try? (artworkRoot == Bundle.main.resourceURL
            ? ClassicMobileArtworkCache.shared.load(directory) : ClassicMacArtwork(directory: directory))
        guard let art,
              let scene = try? ClassicMacScene(level: authoredLevel, rendered: renderedLevel, artwork: art,
                  groundSet: ground, match: artworkMatch, reconstructUnmatched: settings.graphics != .amiga) else { return }
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

    public func releaseTransientResources() { terrainLease.release(); terrainFrame = nil; cachedPanelFrame = nil; ghostFrames.removeAll(); spriteFrames.removeAll(); cachedRender = nil }

    private func spriteHighlight(_ lemming: ClassicDOSLemming) -> MobileSpriteHighlight? {
        guard let assets else { return nil }
        let pose = Self.pose(for: lemming.action)
        let left = lemming.direction == .left
        let direction: ClassicSpriteDirection = left ? .left : .right
        guard let animation = assets.animation(for: pose, direction: direction)
            ?? assets.animation(for: pose, direction: .none), !animation.frames.isEmpty else { return nil }
        let phase = nativeScene != nil && nativeArtwork?.lemming(pose: pose, left: left, tick: lemming.animationFrame) != nil
            ? ClassicMacArtwork.lemmingFrameIndex(pose: pose, left: left, tick: lemming.animationFrame)
            : abs(lemming.animationFrame) % animation.frames.count
        let key = SpriteKey(pose: pose, left: left, phase: phase,
            climber: lemming.hasClimber, floater: lemming.hasFloater)
        let sprite: MobileSpriteHighlight
        if let cached = spriteFrames[key] { sprite = cached }
        else {
            guard let generated = makeSpriteHighlight(lemming) else { return nil }
            sprite = .init(frame: generated.frame,
                rect: .init(x: generated.rect.x - Double(lemming.foot.x), y: generated.rect.y - Double(lemming.foot.y),
                    width: generated.rect.width, height: generated.rect.height),
                cacheKey: generated.cacheKey, time: nil)
            if spriteFrames.count >= 512 { spriteFrames.removeAll(keepingCapacity: true) }
            spriteFrames[key] = sprite
        }
        let reduced = settings?.reduceMotion == true || settings?.reduceFlashes == true
        // The cached rect follows the foot; the Mac door offset depends on the exit.
        let doorShift = pose == .exiting && nativeArtwork?.lemming(pose: pose, left: left, tick: lemming.animationFrame) != nil
            ? Double(nativeScene?.exitingShift(footX: lemming.foot.x, footY: lemming.foot.y,
                spriteOffsetX: animation.offsetX) ?? 0) / 2 : 0
        return .init(frame: sprite.frame,
            rect: .init(x: sprite.rect.x + Double(lemming.foot.x) + doorShift, y: sprite.rect.y + Double(lemming.foot.y),
                width: sprite.rect.width, height: sprite.rect.height),
            cacheKey: sprite.cacheKey, time: reduced ? nil : Double(simulation.tickCount) / ticksPerSecond,
            direction: left ? -1 : 1)
    }

    private func makeSpriteHighlight(_ lemming: ClassicDOSLemming) -> MobileSpriteHighlight? {
        guard let assets, palette.count >= 8 else { return nil }
        let pose = Self.pose(for: lemming.action)
        let direction: ClassicSpriteDirection = lemming.direction == .left ? .left : .right
        guard let animation = assets.animation(for: pose, direction: direction)
            ?? assets.animation(for: pose, direction: .none), !animation.frames.isEmpty else { return nil }
        let index = abs(lemming.animationFrame) % animation.frames.count
        let frame = animation.frames[index]
        if nativeScene != nil, var native = nativeArtwork?.lemming(pose: pose, left: lemming.direction == .left, tick: lemming.animationFrame) {
            if nativeArtwork?.monochrome == true, settings?.showClassicSkillBackpacks == true {
                native = ClassicMonochromeBackpack.render(native,
                    kind: .assigned(climber: lemming.hasClimber, floater: lemming.hasFloater),
                    pose: pose, left: lemming.direction == .left)
            }
            let pack = settings?.showClassicSkillBackpacks == true && nativeArtwork?.monochrome != true
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

    /// Reads sprite bytes in place. Each actor's frame is composited every tick.
    private static func composite(
        _ source: Data,
        sourceWidth: Int,
        sourceHeight: Int,
        atX originX: Int,
        y originY: Int,
        into destination: inout Data,
        width: Int,
        height: Int
    ) {
        guard source.count == sourceWidth * sourceHeight * 4, destination.count >= SceneRasterContext.region(width: width, height: height).byteCount else { return }
        let region = SceneRasterContext.region(width: width, height: height)
        let top = max(0, region.y - originY), bottom = min(sourceHeight, region.y + region.height - originY)
        let left = max(0, region.x - originX), right = min(sourceWidth, region.x + region.width - originX)
        guard top < bottom, left < right else { return }
        let rows = top..<bottom, columns = left..<right
        source.withUnsafeBytes { (source: UnsafeRawBufferPointer) in
            destination.withUnsafeMutableBytes { (destination: UnsafeMutableRawBufferPointer) in
                for y in rows {
                    let sourceRow = y * sourceWidth
                    for x in columns {
                        let src = (sourceRow + x) * 4
                        let alpha = Int(source[src + 3])
                        guard alpha > 0 else { continue }
                        guard let dst = region.offset(x: originX + x, y: originY + y) else { continue }
                        if alpha == 255 {
                            destination[dst] = source[src]
                            destination[dst + 1] = source[src + 1]
                            destination[dst + 2] = source[src + 2]
                        } else {
                            let inverse = 255 - alpha
                            for channel in 0..<3 {
                                destination[dst + channel] = UInt8(
                                    (Int(source[src + channel]) * alpha + Int(destination[dst + channel]) * inverse) / 255
                                )
                            }
                        }
                        destination[dst + 3] = 255
                    }
                }
            }
        }
    }

    private static func drawReticle(
        _ selection: MobileTargetSelection,
        into pixels: inout Data,
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
            guard let offset = SceneRasterContext.region(width: width, height: height).offset(x: x, y: y) else { continue }
            pixels[offset] = colour.0
            pixels[offset + 1] = colour.1
            pixels[offset + 2] = colour.2
            pixels[offset + 3] = 255
        }
    }
}
