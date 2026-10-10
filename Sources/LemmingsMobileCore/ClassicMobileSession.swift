import Foundation
import NxlvKit

public struct ClassicMobileLevelSummary: Codable, Equatable, Sendable {
    public let index: Int
    public let rank: String
    public let number: Int
    public let title: String

    public init(index: Int, rank: String, number: Int, title: String) {
        self.index = index
        self.rank = rank
        self.number = number
        self.title = title
    }
}

public struct ClassicMobileContent {
    public let summary: ClassicMobileLevelSummary
    public let session: ClassicMobileSession

    public init(summary: ClassicMobileLevelSummary, session: ClassicMobileSession) {
        self.summary = summary
        self.session = session
    }
}

/// Loads user-selected DOS data once and creates sessions from the authored order.
public final class ClassicMobileLibrary {
    public let directory: URL
    public let dataSet: ClassicDataSet
    public let levels: [ClassicMobileLevelSummary]

    private let assets: ClassicMainDATAssets
    private var grounds: [Int: ClassicGroundSet] = [:]
    private var specials: [Int: ClassicSpecialGraphic] = [:]

    public init(directory: URL) throws {
        self.directory = directory
        dataSet = try ClassicDataSet.detect(directory: directory)
        assets = try ClassicMainDATAssets.load(from: directory)
        levels = dataSet.campaign.levels.enumerated().map { index, item in
            ClassicMobileLevelSummary(
                index: index,
                rank: item.rank,
                number: item.number,
                title: item.level.title
            )
        }
    }

    public func loadLevel(at index: Int) throws -> ClassicMobileContent {
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
        let rendered = try ClassicLevelRenderer.render(
            level,
            groundSet: ground,
            specialGraphic: special
        )
        let mechanics = ClassicDOSMechanics(title: dataSet.title, rank: entry.rank)
        let simulation = try ClassicDOSSimulation(
            level: level,
            renderedLevel: rendered,
            mainDATAssets: assets,
            mechanics: mechanics
        )
        let palette = try ClassicLemmingPalette.inLevelVGA(terrainPalette: ground.terrainPalette)
        let summary = levels[index]
        return ClassicMobileContent(
            summary: summary,
            session: ClassicMobileSession(
                simulation: simulation,
                renderedLevel: rendered,
                assets: assets,
                palette: palette,
                levelIdentifier: "\(dataSet.identifierKey)/\(entry.rank)/\(entry.number)",
                levelIndex: index
            )
        )
    }
}

public final class ClassicMobileSession: MobileGameSession {
    private struct Checkpoint: Codable {
        var version = 1
        let initialStateHash: String
        let simulation: ClassicDOSSimulation
        let beforeEndRun: ClassicDOSSimulation?
    }

    public let engineIdentifier = "classic-dos"
    public let engineFingerprint = "classic-dos-mobile-v1"
    public let levelIdentifier: String
    public let levelIndex: Int
    public let levelFingerprint: String
    public let levelSize: MobileSize
    public let ticksPerSecond = Double(ClassicDOSRules.ticksPerSecond)

    private let initialStateHash: String
    private let renderedLevel: ClassicRenderedLevel?
    private let assets: ClassicMainDATAssets?
    private let palette: [ClassicRGBColor]
    private var simulation: ClassicDOSSimulation
    private var beforeEndRun: ClassicDOSSimulation?

    public init(
        simulation: ClassicDOSSimulation,
        renderedLevel: ClassicRenderedLevel? = nil,
        assets: ClassicMainDATAssets? = nil,
        palette: [ClassicRGBColor] = [],
        levelIdentifier: String,
        levelIndex: Int
    ) {
        self.simulation = simulation
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
            isComplete: simulation.isComplete,
            didWin: simulation.didWin,
            isEndingRun: simulation.isNuking,
            skills: ClassicSkill.allCases.map {
                MobileSkillState(name: $0.rawValue.capitalized, count: simulation.remainingSkillCount($0))
            }
        )
    }

    public var panelFrame: MobilePixelFrame? {
        guard let panel = assets?.panel else { return nil }
        return try? MobilePixelFrame(
            width: panel.width,
            height: panel.height,
            rgba: panel.rgba(using: ClassicLemmingPalette.panelVGA)
        )
    }

    public func tick() {
        _ = simulation.tick()
        if !simulation.isNuking { beforeEndRun = nil }
    }

    public func targetCandidates(for control: Int) -> [MobileTargetCandidate] {
        guard ClassicSkill.allCases.indices.contains(control) else { return [] }
        let skill = ClassicSkill.allCases[control]
        return simulation.lemmings.filter(\.isActive).map { lemming in
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
                isBuilding: lemming.action == .building
            )
        }
    }

    @discardableResult
    public func assign(control: Int, to target: Int) -> Bool {
        guard ClassicSkill.allCases.indices.contains(control) else { return false }
        return simulation.assign(ClassicSkill.allCases[control], to: target) == .assigned
    }

    @discardableResult
    public func adjustReleaseRate(by delta: Int) -> Bool {
        guard delta != 0, !simulation.isComplete else { return false }
        let before = simulation.releaseRate
        simulation.setReleaseRate(before + delta)
        return simulation.releaseRate != before
    }

    @discardableResult
    public func beginEndRun() -> Bool {
        guard !simulation.isComplete, !simulation.isNuking, beforeEndRun == nil else { return false }
        beforeEndRun = simulation
        simulation.beginNuke()
        return true
    }

    @discardableResult
    public func undoEndRun() -> Bool {
        guard let beforeEndRun else { return false }
        simulation = beforeEndRun
        self.beforeEndRun = nil
        return true
    }

    public func render(highlight: MobileTargetSelection?) throws -> MobilePixelFrame {
        guard let renderedLevel else { throw MobileSessionError.frameUnavailable }
        var pixels = [UInt8](ClassicSceneFrame.rgba(renderedLevel, simulation: simulation))
        if let assets, palette.count >= 8 {
            for lemming in simulation.lemmings where lemming.isActive {
                Self.draw(lemming, assets: assets, palette: palette, into: &pixels,
                          width: renderedLevel.width, height: renderedLevel.height)
            }
        }
        if let highlight {
            Self.drawReticle(highlight, into: &pixels, width: renderedLevel.width, height: renderedLevel.height)
        }
        return try MobilePixelFrame(width: renderedLevel.width, height: renderedLevel.height, rgba: Data(pixels))
    }

    public func checkpointPayload() throws -> Data {
        try JSONEncoder().encode(Checkpoint(
            initialStateHash: initialStateHash,
            simulation: simulation,
            beforeEndRun: beforeEndRun
        ))
    }

    public func restoreCheckpointPayload(_ data: Data) throws {
        let checkpoint = try JSONDecoder().decode(Checkpoint.self, from: data)
        guard checkpoint.version == 1 else { throw MobileCheckpointError.version }
        guard checkpoint.initialStateHash == initialStateHash else { throw MobileSessionError.changedLevel }
        let restored = checkpoint.simulation
        guard restored.terrain.width == simulation.terrain.width,
              restored.terrain.height == simulation.terrain.height,
              !restored.isComplete else {
            throw MobileSessionError.invalidCheckpoint
        }
        simulation = restored
        beforeEndRun = checkpoint.beforeEndRun
    }

    public func releaseTransientResources() {}

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
        composite(
            [UInt8](source),
            sourceWidth: frame.width,
            sourceHeight: frame.height,
            atX: lemming.foot.x + animation.offsetX,
            y: lemming.foot.y + animation.offsetY,
            into: &destination,
            width: width,
            height: height
        )
        if let countdown = lemming.bomberCountdown {
            let seconds = max(1, (countdown + ClassicDOSRules.ticksPerSecond - 1) / ClassicDOSRules.ticksPerSecond)
            if let glyph = assets.countdownGlyphs.first(where: { $0.digit == min(9, seconds) })?.bitmap {
                drawMonochrome(
                    glyph,
                    atX: lemming.foot.x - glyph.width / 2,
                    y: lemming.foot.y + animation.offsetY - glyph.height - 1,
                    into: &destination,
                    width: width,
                    height: height
                )
            }
        }
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

    private static func drawMonochrome(
        _ bitmap: ClassicMonochromeBitmap,
        atX originX: Int,
        y originY: Int,
        into destination: inout [UInt8],
        width: Int,
        height: Int
    ) {
        for y in 0..<bitmap.height {
            for x in 0..<bitmap.width where bitmap.isSet(x: x, y: y) {
                let px = originX + x
                let py = originY + y
                guard (0..<width).contains(px), (0..<height).contains(py) else { continue }
                let offset = (py * width + px) * 4
                destination[offset] = 255
                destination[offset + 1] = 255
                destination[offset + 2] = 255
                destination[offset + 3] = 255
            }
        }
    }

    private static func drawReticle(
        _ selection: MobileTargetSelection,
        into pixels: inout [UInt8],
        width: Int,
        height: Int
    ) {
        let colour: (UInt8, UInt8, UInt8)
        switch selection.state {
        case .eligible: colour = (116, 255, 26)
        case .alreadyAssigned: colour = (255, 151, 32)
        case .unavailable: colour = (140, 140, 140)
        }
        let centreX = Int(selection.point.x.rounded())
        let centreY = Int(selection.point.y.rounded())
        let radius = 8
        let marks = (-radius...radius).flatMap { offset -> [(Int, Int)] in
            guard abs(offset) >= radius - 2 else { return [] }
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
