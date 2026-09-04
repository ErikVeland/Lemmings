import Foundation

/// Physical order in PANEL.DAT and L2.RKO's control-name table at 3077.
public enum Lemmings2Control: Int, CaseIterable, Sendable {
    case pause = 8, nuke = 9, fan = 10, fastForward = 11

    public static func slot(x: Int, y: Int) -> Int? {
        guard (0..<320).contains(x), (160..<200).contains(y) else { return nil }
        return x < 256 ? x / 32 : 8 + (x - 256) / 32 + (y >= 180 ? 2 : 0)
    }
}

/// Requires two consecutive clicks on the mushroom-cloud control.
public struct Lemmings2NukeGesture: Sendable {
    public private(set) var armedAt: TimeInterval?
    public init() {}
    public mutating func reset() { armedAt = nil }
    public mutating func click(slot: Int, count: Int, time: TimeInterval, interval: TimeInterval) -> Bool {
        guard slot == Lemmings2Control.nuke.rawValue else { reset(); return false }
        if let armedAt, count >= 2, time >= armedAt, time - armedAt <= interval {
            reset(); return true
        }
        armedAt = time
        return false
    }
}

/// Crosshair, selection box, then sixteen fan directions from POINTER.DAT.
public struct Lemmings2Pointers: Sendable {
    public let frames: [[UInt8]]
    public init(data: Data) throws {
        let decoded = try Lemmings2Compression.decode(data, maximumOutputSize: 4608)
        guard decoded.count == 4608 else { throw SequelDataError.invalid("Invalid L2 pointer bank.") }
        let r = SequelBinary(decoded)
        frames = try (0..<18).map {
            try Lemmings2FrontEnd.planar(Data(r.slice($0 * 256, 256)), width: 16, height: 16)
        }
    }
}
