import Foundation
import NxlvKit

public struct MobilePixelFrame: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let rgba: Data

    public init(width: Int, height: Int, rgba: Data) throws {
        guard width > 0,
              height > 0,
              width <= Int.max / height,
              rgba.count == width * height * 4 else {
            throw MobileSessionError.invalidFrame
        }
        self.width = width
        self.height = height
        self.rgba = rgba
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

public struct MobileExplosion: Sendable {
    public let id: Int
    public let birthTick: Int
    public let rect: MobileRect
    public let phase: Int
    public init(id: Int, birthTick: Int, rect: MobileRect, phase: Int) {
        self.id = id; self.birthTick = birthTick; self.rect = rect; self.phase = phase
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
    case invalidCheckpoint
    case changedLevel
    case unsupportedControl

    public var errorDescription: String? {
        switch self {
        case .invalidFrame:
            return "The game produced an invalid image."
        case .frameUnavailable:
            return "This game has no mobile renderer."
        case .invalidCheckpoint:
            return "The saved run could not be verified."
        case .changedLevel:
            return "The saved run belongs to different level data."
        case .unsupportedControl:
            return "This control is not available in the current game."
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
    var activeLemmingCount: Int { get }
    var nukeRemainingTicks: Int? { get }
    var allNukeExplosionsPlayed: Bool { get }
    var explosions: [MobileExplosion] { get }
    var selectionSprite: MobileSpriteHighlight? { get }
    var assignmentSprite: MobileSpriteHighlight? { get }
    var assignmentProgress: Double? { get }

    var entrancePoint: MobilePoint { get }
    var goalPoint: MobilePoint { get }
    var supportsRewind: Bool { get }
    var isReadOnly: Bool { get }
    var usedRewind: Bool { get }
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
    func applySettings(_ settings: ClassicSettings)

    func drainSoundCues() -> [PositionedSoundCue]

    func tick()
    func targetCandidates(for control: Int) -> [MobileTargetCandidate]
    @discardableResult func assign(control: Int, to target: Int) -> Bool
    @discardableResult func adjustReleaseRate(by delta: Int) -> Bool
    @discardableResult func beginEndRun() -> Bool
    @discardableResult func undoEndRun() -> Bool
    func render(highlight: MobileTargetSelection?) throws -> MobilePixelFrame
    func checkpointPayload() throws -> Data
    func restoreCheckpointPayload(_ data: Data) throws
    func releaseTransientResources()
}

public extension MobileGameSession {
    var renderScale: Double { 1 }
    var activeLemmingCount: Int { max(0, snapshot.released - snapshot.saved) }
    var nukeRemainingTicks: Int? { nil }
    var allNukeExplosionsPlayed: Bool { snapshot.isComplete }
    var explosions: [MobileExplosion] { [] }
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
    func replayDocument() throws -> Data? { nil }
    func makeReplaySession(document: Data) throws -> (any MobileGameSession)? { nil }
    func applySettings(_ settings: ClassicSettings) {}
    func drainSoundCues() -> [PositionedSoundCue] { [] }
    var initialCameraOrigin: MobilePoint { MobilePoint(x: 0, y: 0) }
    var panelFrame: MobilePixelFrame? { nil }
    var selectionSprite: MobileSpriteHighlight? { nil }
    var assignmentSprite: MobileSpriteHighlight? { nil }
    var assignmentProgress: Double? { nil }
    func releaseTransientResources() {}
}
