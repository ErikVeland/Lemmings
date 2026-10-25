import Foundation
import LemmingsAppCore
import NxlvKit

public struct MobilePixelFrame: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let rgba: Data
    /// HDR light on lit Mac arrow edges, in frame pixels. SDR screens ignore it.
    public let arrowGlints: ClassicMacScene.ArrowGlints?

    public init(width: Int, height: Int, rgba: Data, arrowGlints: ClassicMacScene.ArrowGlints? = nil) throws {
        guard width > 0,
              height > 0,
              width <= Int.max / height,
              rgba.count == width * height * 4 else {
            throw MobileSessionError.invalidFrame
        }
        self.width = width
        self.height = height
        self.rgba = rgba
        self.arrowGlints = arrowGlints
    }

    /// Keeps the original pixels and clips the loupe to the level boundary.
    public func cropped(around point: MobilePoint, width requestedWidth: Int, height requestedHeight: Int) throws -> MobilePixelFrame {
        guard requestedWidth > 0, requestedHeight > 0,
              point.x.isFinite, point.y.isFinite else { throw MobileSessionError.invalidFrame }
        let cropWidth = min(width, requestedWidth)
        let cropHeight = min(height, requestedHeight)
        let x = Int(min(Double(width - cropWidth), max(0, point.x - Double(cropWidth) / 2)))
        let y = Int(min(Double(height - cropHeight), max(0, point.y - Double(cropHeight) / 2)))
        var pixels = Data()
        pixels.reserveCapacity(cropWidth * cropHeight * 4)
        for row in y..<(y + cropHeight) {
            let start = (row * width + x) * 4
            pixels.append(rgba[start..<(start + cropWidth * 4)])
        }
        return try MobilePixelFrame(width: cropWidth, height: cropHeight, rgba: pixels)
    }
}

/// Captures one game state cheaply so a worker can encode it without accessing live play.
public struct MobileCheckpointPayload: Sendable {
    private let encodeValue: @Sendable () throws -> Data

    public init<Value: Encodable & Sendable>(_ value: Value) {
        encodeValue = { try JSONEncoder().encode(value) }
    }

    public init(encoded: Data) { encodeValue = { encoded } }
    public func encode() throws -> Data { try encodeValue() }
}

public struct MobileBombCountdown: Equatable, Sendable {
    public let id: Int
    public let seconds: Int
    /// Centre of the sprite's top edge, in level coordinates.
    public let anchor: MobilePoint
    public init(id: Int, seconds: Int, anchor: MobilePoint) {
        self.id = id; self.seconds = seconds; self.anchor = anchor
    }
}

public struct MobileExplosion: Sendable {
    public let id: Int
    public let birthTick: Int
    public let rect: MobileRect
    public let phase: Int
    public let sprayOrigin: MobilePoint
    public init(id: Int, birthTick: Int, rect: MobileRect, phase: Int, sprayOrigin: MobilePoint? = nil) {
        self.id = id; self.birthTick = birthTick; self.rect = rect; self.phase = phase
        self.sprayOrigin = sprayOrigin ?? .init(x: rect.x + rect.width / 2, y: rect.y + rect.height / 2)
    }
    public init(_ burst: PixelExplosion, at tick: Int) {
        self.init(id: burst.id, birthTick: burst.birthTick,
            rect: .init(x: Double(burst.x - 3), y: Double(burst.y - 3), width: 6, height: 6),
            phase: tick - burst.birthTick)
    }
}

public struct MobileSpriteHighlight: Sendable {
    public let frame: MobilePixelFrame
    public let rect: MobileRect
    public let cacheKey: String
    public let time: Double?
    public init(frame: MobilePixelFrame, rect: MobileRect, cacheKey: String, time: Double?) {
        self.frame = frame; self.rect = rect; self.cacheKey = cacheKey; self.time = time
    }
}

public struct MobileReplaySkillUse: Equatable, Sendable {
    public let tick: Int
    public let name: String
    public init(tick: Int, name: String) { self.tick = tick; self.name = name }
}

public struct MobileSkillState: Codable, Equatable, Sendable {
    public let name: String
    public let count: Int
    public let isUnlimited: Bool

    public init(name: String, count: Int, isUnlimited: Bool = false) {
        self.name = name
        self.count = count
        self.isUnlimited = isUnlimited
    }
}

/// One existing level supply, or one lemming's held tool, that can receive a charge.
public struct MobileExtraSkillChoice: Equatable, Sendable {
    public let skillID: String
    public let title: String
    public let control: Int
    public let target: Int?

    public init(skillID: String, title: String, control: Int, target: Int? = nil) {
        self.skillID = skillID; self.title = title; self.control = control; self.target = target
    }
}

public struct MobileGameSnapshot: Codable, Equatable, Sendable {
    public let tick: Int
    public let released: Int
    public let total: Int
    public let saved: Int
    public let required: Int
    public let remainingSeconds: Int?
    public let releaseRate: Int?
    public let isComplete: Bool
    public let didWin: Bool
    public let isEndingRun: Bool
    public let skills: [MobileSkillState]

    public init(
        tick: Int,
        released: Int,
        total: Int,
        saved: Int,
        required: Int,
        remainingSeconds: Int?,
        releaseRate: Int?,
        isComplete: Bool,
        didWin: Bool,
        isEndingRun: Bool,
        skills: [MobileSkillState]
    ) {
        self.tick = tick
        self.released = released
        self.total = total
        self.saved = saved
        self.required = required
        self.remainingSeconds = remainingSeconds
        self.releaseRate = releaseRate
        self.isComplete = isComplete
        self.didWin = didWin
        self.isEndingRun = isEndingRun
        self.skills = skills
    }
}

public enum MobileSessionError: Error, LocalizedError, Equatable {
    case invalidFrame
    case frameUnavailable
    case journeyEngineUnavailable
    case invalidCheckpoint
    case changedLevel
    case unsupportedControl

    public var errorDescription: String? {
        switch self {
        case .invalidFrame:
            return L10n.text("The game produced an invalid image.")
        case .frameUnavailable:
            return L10n.text("This game has no mobile renderer.")
        case .journeyEngineUnavailable:
            return L10n.text("This journey level is unavailable on this device. The saved session has been kept.")
        case .invalidCheckpoint:
            return L10n.text("The saved run could not be verified.")
        case .changedLevel:
            return L10n.text("The saved run belongs to different level data.")
        case .unsupportedControl:
            return L10n.text("This control is not available in the current game.")
        }
    }
}

/// The mobile shell depends on this contract, not on one game's concrete runtime.
public protocol MobileGameSession: AnyObject {
    var engineIdentifier: String { get }
    var engineFingerprint: String { get }
    var levelIdentifier: String { get }
    var levelIndex: Int { get }
    var levelFingerprint: String { get }
    var levelSize: MobileSize { get }
    var initialCameraOrigin: MobilePoint { get }
    var ticksPerSecond: Double { get }
    var snapshot: MobileGameSnapshot { get }
    var panelFrame: MobilePixelFrame? { get }
    var renderScale: Double { get }
    var availableGraphics: [ClassicGraphicsSource] { get }
    var spriteActorIDs: [Int] { get }
    var activeLemmingCount: Int { get }
    var lostLemmingCount: Int { get }
    var nukeRemainingTicks: Int? { get }
    var allNukeExplosionsPlayed: Bool { get }
    var explosions: [MobileExplosion] { get }
    var bombCountdowns: [MobileBombCountdown] { get }
    var selectionSprite: MobileSpriteHighlight? { get }
    func spriteHighlight(for actor: Int) -> MobileSpriteHighlight?
    var rescueSprites: [MobileSpriteHighlight] { get }
    var assignmentSprite: MobileSpriteHighlight? { get }
    var assignmentProgress: Double? { get }
    var replaySkillUses: [MobileReplaySkillUse] { get }
    var replayMoveNavigation: ReplayMoveNavigation { get }
    var replayEndTick: Int? { get }
    @discardableResult func seekReplay(to tick: Int) -> Bool

    var entrancePoint: MobilePoint { get }
    var goalPoint: MobilePoint { get }
    var supportsRewind: Bool { get }
    var isReadOnly: Bool { get }
    var usedRewind: Bool { get }
    /// Retained for the entire attempt, including rewinds before the extra charge.
    var bonusSkillID: String? { get }
    var extraSkillChoices: [MobileExtraSkillChoice] { get }
    var existingLevelSkills: Set<String> { get }
    @discardableResult func grantExtraSkill(_ choice: MobileExtraSkillChoice) -> Bool
    /// Retains the spent attempt marker without adding stock to an earlier checkpoint.
    @discardableResult func retainExtraSkillUse(_ skillID: String) -> Bool
    var assignedSkillCount: Int { get }
    var assignedSkills: [String: Int] { get }
    var nukeCount: Int { get }
    var rewindCount: Int { get }
    var undoCount: Int { get }
    @discardableResult func rewind(seconds: Double) -> Bool
    @discardableResult func stepBackward() -> Bool
    @discardableResult func stepForward() -> Bool
    func resumeFromCurrentTick()
    func replayDocument() throws -> Data?
    func makeReplaySession(document: Data) throws -> (any MobileGameSession)?
    func makeReplayClone() -> (any MobileGameSession)?
    func skillCursorFrame(control: Int) -> MobilePixelFrame?
    func skillCursorRemaining(control: Int, target: Int?) -> Int?
    func applySettings(_ settings: ClassicSettings)

    func drainSoundCues() -> [PositionedSoundCue]
    func drainLemmings2SoundRequests() -> [Lemmings2SoundRequest]

    func tick()
    func targetCandidates(for control: Int) -> [MobileTargetCandidate]
    /// A nearby wall's side, using the actor's native foot position and terrain.
    func targetWallDirection(for target: Int) -> Int?
    @discardableResult func assign(control: Int, to target: Int) -> Bool
    @discardableResult func adjustReleaseRate(by delta: Int) -> Bool
    @discardableResult func beginEndRun() -> Bool
    @discardableResult func undoEndRun() -> Bool
    func render(highlight: MobileTargetSelection?) throws -> MobilePixelFrame
    func checkpointPayload() throws -> Data
    func prepareCheckpointPayload() throws -> MobileCheckpointPayload
    func restoreCheckpointPayload(_ data: Data) throws
    func releaseTransientResources()

    /// Earlier Hot Seat turns, drawn behind live lemmings. Nil in solo play.
    var hotSeatGhosts: HotSeatGhostPlayback? { get set }
    /// The level start in the shared action format, or nil when this engine has none.
    var actionReplayInitial: ActionReplayState? { get }
    /// The attempt so far in the shared action format, or nil when it cannot be expressed.
    func actionCapture() throws -> MobileActionCapture?
    /// Read-only details for released individuals. Unsupported engines return nil.
    var lemmingInspection: LemmingInspection? { get }
}

public extension MobileGameSession {
    var bonusSkillID: String? { nil }
    var extraSkillChoices: [MobileExtraSkillChoice] { [] }
    var existingLevelSkills: Set<String> { [] }
    func grantExtraSkill(_ choice: MobileExtraSkillChoice) -> Bool { false }
    func retainExtraSkillUse(_ skillID: String) -> Bool { false }
    var lemmingInspection: LemmingInspection? { nil }
    func targetWallDirection(for target: Int) -> Int? { nil }
    var lostLemmingCount: Int { max(0, snapshot.released - snapshot.saved - activeLemmingCount) }
    func prepareCheckpointPayload() throws -> MobileCheckpointPayload {
        .init(encoded: try checkpointPayload())
    }
    var renderScale: Double { 1 }
    var availableGraphics: [ClassicGraphicsSource] { [] }
    var spriteActorIDs: [Int] { [] }
    var activeLemmingCount: Int { max(0, snapshot.released - snapshot.saved) }
    var nukeRemainingTicks: Int? { nil }
    var allNukeExplosionsPlayed: Bool { snapshot.isComplete }
    var explosions: [MobileExplosion] { [] }
    var bombCountdowns: [MobileBombCountdown] { [] }
    var entrancePoint: MobilePoint { initialCameraOrigin }
    var goalPoint: MobilePoint { MobilePoint(x: levelSize.width, y: levelSize.height / 2) }
    var supportsRewind: Bool { false }
    var isReadOnly: Bool { false }
    var usedRewind: Bool { false }
    var assignedSkillCount: Int { 0 }
    var assignedSkills: [String: Int] { [:] }
    var nukeCount: Int { 0 }
    var rewindCount: Int { 0 }
    var undoCount: Int { 0 }
    func rewind(seconds: Double) -> Bool { false }
    func stepBackward() -> Bool { false }
    func stepForward() -> Bool { tick(); return true }
    func resumeFromCurrentTick() {}
    func replayDocument() throws -> Data? {
        guard let capture = try actionCapture(), capture.initial.tick == 0 else { return nil }
        return try JSONEncoder().encode(MobileActionReplayDocument(session: self, capture: capture))
    }
    func makeReplaySession(document: Data) throws -> (any MobileGameSession)? {
        try MobileActionReplaySession(document: document, source: self)
    }
    func makeReplayClone() -> (any MobileGameSession)? { nil }
    var replayEndTick: Int? { nil }
    func skillCursorFrame(control: Int) -> MobilePixelFrame? { nil }
    func skillCursorRemaining(control: Int, target: Int?) -> Int? {
        guard snapshot.skills.indices.contains(control), !snapshot.skills[control].isUnlimited else { return nil }
        return snapshot.skills[control].count
    }
    func applySettings(_ settings: ClassicSettings) {}
    func drainSoundCues() -> [PositionedSoundCue] { [] }
    func drainLemmings2SoundRequests() -> [Lemmings2SoundRequest] { [] }
    var initialCameraOrigin: MobilePoint { MobilePoint(x: 0, y: 0) }
    /// Keep menu scenery at the opening view, independent of the live camera.
    var menuPreviewOrigin: MobilePoint {
        if engineIdentifier.hasPrefix("classic") { return initialCameraOrigin }
        return .init(x: entrancePoint.x - 160, y: entrancePoint.y - 80)
    }
    var panelFrame: MobilePixelFrame? { nil }
    var selectionSprite: MobileSpriteHighlight? { nil }
    var rescueSprites: [MobileSpriteHighlight] { [] }
    var assignmentSprite: MobileSpriteHighlight? { nil }
    var replaySkillUses: [MobileReplaySkillUse] { [] }
    var replayMoveNavigation: ReplayMoveNavigation { .init(ticks: []) }
    func seekReplay(to tick: Int) -> Bool { false }
    var assignmentProgress: Double? { nil }
    func spriteHighlight(for actor: Int) -> MobileSpriteHighlight? { nil }
    func releaseTransientResources() {}
    var hotSeatGhosts: HotSeatGhostPlayback? { get { nil } set {} }
    var actionReplayInitial: ActionReplayState? { nil }
    func actionCapture() throws -> MobileActionCapture? { nil }
}
