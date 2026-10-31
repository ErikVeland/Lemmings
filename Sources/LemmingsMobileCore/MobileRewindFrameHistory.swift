import Foundation

/// A monotonic start-and-stop curve for replaying retained rewind frames.
public enum MobileRewindTiming {
    public static func progress(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        let t = min(1, max(0, value))
        return t * t * (3 - 2 * t)
    }

    public static func duration(frameCount: Int) -> Double {
        min(1.2, max(0.35, Double(max(0, frameCount - 1)) / 30))
    }

    public static func frameIndex(elapsed: Double, duration: Double, count: Int) -> Int {
        guard count > 1, duration.isFinite, duration > 0 else { return 0 }
        return Int((progress(elapsed / duration) * Double(count - 1)).rounded())
    }
}

/// Retains a bounded run of presented frames without copying their payloads.
public struct MobileRewindFrameHistory<Frame> {
    private struct Entry {
        let tick: Int
        let frame: Frame
        let bytes: Int
    }
    private var entries: [Entry] = []
    public private(set) var retainedBytes = 0
    private let maximumBytes: Int
    private let maximumFrames: Int

    public init(maximumBytes: Int, maximumFrames: Int) {
        self.maximumBytes = max(0, maximumBytes)
        self.maximumFrames = max(0, maximumFrames)
    }

    public mutating func record(tick: Int, frame: Frame, bytes: Int) {
        guard tick >= 0, bytes > 0, bytes <= maximumBytes, maximumFrames > 0 else { clear(); return }
        while let last = entries.last, last.tick >= tick {
            retainedBytes -= last.bytes
            entries.removeLast()
        }
        while !entries.isEmpty && (entries.count >= maximumFrames || retainedBytes > maximumBytes - bytes) {
            retainedBytes -= entries.removeFirst().bytes
        }
        entries.append(Entry(tick: tick, frame: frame, bytes: bytes))
        retainedBytes += bytes
    }

    /// Returns a covered interval, newest frame first; the caller supplies exact endpoints.
    public func frames(from origin: Int, through target: Int, maximumOriginGap: Int = 0,
                       maximumSampleGap: Int = .max) -> [Frame]? {
        guard target <= origin, let first = entries.first, first.tick <= target,
              let newest = entries.last(where: { $0.tick <= origin }),
              origin - newest.tick <= max(0, maximumOriginGap) else { return nil }
        let samples = entries.reversed().filter { $0.tick <= origin && $0.tick >= target }
        var previous = origin
        for sample in samples {
            guard previous - sample.tick <= max(0, maximumSampleGap) else { return nil }
            previous = sample.tick
        }
        guard previous - target <= max(0, maximumSampleGap) else { return nil }
        return samples.map(\.frame)
    }

    public mutating func discard(after tick: Int) {
        while let last = entries.last, last.tick > tick {
            retainedBytes -= last.bytes
            entries.removeLast()
        }
    }

    public mutating func trim(toBytes limit: Int) {
        while !entries.isEmpty && retainedBytes > max(0, limit) {
            retainedBytes -= entries.removeFirst().bytes
        }
    }

    public mutating func clear() { entries.removeAll(); retainedBytes = 0 }
}
