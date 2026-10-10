import Foundation

/// Measured timing for one audio version. Stable estimates remain distinct from manual verification.
public struct MusicTimingCatalogue: Decodable, Sendable {
    public struct Entry: Decodable, Sendable {
        public struct Tracker: Decodable, Sendable {
            public let loopStartSeconds: Double?
        }
        public let variantID: String
        public let path: String
        public let sourceSHA256: String
        public let playbackSHA256: String?
        public let durationSeconds: Double
        public let baseBPM: Double?
        public let bpmStatus: String
        public let barStatus: String
        public let beatsPerBar: Int?
        public let beats: [Double]
        public let downbeats: [Double]
        public let tracker: Tracker?

        public var supportsBeatMixing: Bool { bpmStatus == "estimated-stable" && beats.count >= 32 }
        public var supportsBarMixing: Bool {
            supportsBeatMixing && barStatus == "estimated-stable" && downbeats.count >= 9 && beatsPerBar != nil
        }
        public var expectedSHA256: String { playbackSHA256 ?? sourceSHA256 }

        /// A file or module can loop while its audio-node sample counter continues.
        public func position(at sourceSeconds: Double) -> Double {
            guard sourceSeconds >= durationSeconds else { return max(0, sourceSeconds) }
            let start = tracker?.loopStartSeconds ?? 0
            return start + (sourceSeconds - durationSeconds).truncatingRemainder(dividingBy: durationSeconds - start)
        }

        /// Use measured boundaries. Do not extrapolate through an unanalysed outro.
        public func nextBeat(at sourceSeconds: Double, rate: Double) -> (bpm: Double, delay: Double)? {
            guard supportsBeatMixing, rate > 0, let baseBPM else { return nil }
            let position = position(at: sourceSeconds)
            guard let next = beats.first(where: { $0 >= position }) else { return nil }
            return (baseBPM * rate, (next - position) / rate)
        }

        public struct BarTransition: Sendable {
            public let delay: Double
            public let preRoll: Double
            public let duration: Double
            public let bars: Int
        }

        /// Align the incoming first downbeat with a measured outgoing downbeat.
        /// Long introductions and uncertain grids retain the ordinary gain fade.
        public func barTransition(to incoming: Entry, at sourceSeconds: Double,
                                  outgoingRate: Double, incomingRate: Double,
                                  minimumDuration: Double) -> BarTransition? {
            guard supportsBarMixing, incoming.supportsBarMixing,
                  beatsPerBar == incoming.beatsPerBar, outgoingRate > 0, incomingRate > 0,
                  let outgoingBPM = baseBPM, let incomingBPM = incoming.baseBPM,
                  abs(outgoingBPM * outgoingRate / (incomingBPM * incomingRate) - 1) < 0.01,
                  let first = incoming.downbeats.first else { return nil }
            let position = position(at: sourceSeconds)
            let lead = first / incomingRate
            guard lead <= 2 else { return nil }
            guard let index = downbeats.firstIndex(where: { ($0 - position) / outgoingRate >= lead }),
                  index + 1 < downbeats.count else { return nil }
            let delay = (downbeats[index] - position) / outgoingRate - lead
            guard delay <= 4 else { return nil }
            let bar = (downbeats[index + 1] - downbeats[index]) / outgoingRate
            let count = max(1, Int(ceil(minimumDuration / bar)))
            guard index + count < downbeats.count, count < incoming.downbeats.count,
                  let beatsPerBar else { return nil }
            let expectedBar = Double(beatsPerBar) * 60 / (outgoingBPM * outgoingRate)
            for offset in 1...count {
                let outgoingBar = (downbeats[index + offset] - downbeats[index + offset - 1]) / outgoingRate
                let incomingBar = (incoming.downbeats[offset] - incoming.downbeats[offset - 1]) / incomingRate
                let outgoingBoundary = (downbeats[index + offset] - downbeats[index]) / outgoingRate
                let incomingBoundary = (incoming.downbeats[offset] - first) / incomingRate
                // A mostly regular track can still contain one missed or displaced downbeat.
                guard abs(outgoingBar / expectedBar - 1) <= 0.04,
                      abs(incomingBar / expectedBar - 1) <= 0.04,
                      abs(outgoingBoundary - incomingBoundary) <= 0.08 else { return nil }
            }
            let duration = (downbeats[index + count] - downbeats[index]) / outgoingRate
            return .init(delay: delay, preRoll: lead, duration: duration, bars: count)
        }
    }

    public let schemaVersion: Int
    public let variants: [Entry]

    public init(data: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: data)
        guard schemaVersion == 1, Set(variants.map(\.path)).count == variants.count,
              Set(variants.map(\.variantID)).count == variants.count else { throw InvalidTiming.invalid }
        for entry in variants {
            func ordered(_ values: [Double]) -> Bool {
                values.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= entry.durationSeconds + 0.02 }
                    && zip(values, values.dropFirst()).allSatisfy { $0 < $1 }
            }
            let start = entry.tracker?.loopStartSeconds ?? 0
            guard entry.durationSeconds.isFinite, entry.durationSeconds > 0,
                  start.isFinite, start >= 0, start < entry.durationSeconds,
                  entry.baseBPM.map({ $0.isFinite && $0 > 0 && $0 <= 1000 }) ?? true,
                  entry.beatsPerBar.map({ (2...12).contains($0) }) ?? true,
                  entry.expectedSHA256.count == 64,
                  entry.expectedSHA256.allSatisfy({ $0.isHexDigit }),
                  !entry.path.hasPrefix("/"), !entry.path.split(separator: "/").contains(".."),
                  ordered(entry.beats), ordered(entry.downbeats) else { throw InvalidTiming.invalid }
        }
    }
    private enum InvalidTiming: Error { case invalid }

    public static func load(at root: URL) -> Self? {
        guard let data = try? Data(contentsOf: root.appendingPathComponent("timing.json")) else { return nil }
        return try? Self(data: data)
    }

    public func entry(path: String) -> Entry? { variants.first { $0.path == path } }
}
