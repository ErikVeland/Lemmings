import Foundation

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
    var initialCameraOrigin: MobilePoint { MobilePoint(x: 0, y: 0) }
    var panelFrame: MobilePixelFrame? { nil }
    func releaseTransientResources() {}
}
