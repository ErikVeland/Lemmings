import Foundation

/// Named voice samples supplied with the original Gravis soundtrack.
/// These are one-shot voices, not a general Gravis instrument synthesizer.
public struct Lemmings3SoundBank: Sendable {
    public struct Clip: Sendable {
        public let samples: [Float]
        public let sampleRate: Double

        public init(patch: Data) throws {
            let bytes = [UInt8](patch)
            let headers = 335
            guard bytes.count >= headers,
                  ["GF1PATCH110\0ID#000002\0", "GF1PATCH100\0ID#000002\0"].contains(String(decoding: bytes.prefix(22), as: UTF8.self)),
                  bytes[82] == 1, bytes[151] == 1, bytes[198] == 1 else {
                throw SequelDataError.invalid("L3 voice requires one Gravis instrument, layer and sample.")
            }
            func word(_ offset: Int) -> Int { Int(bytes[offset]) | Int(bytes[offset + 1]) << 8 }
            let count = word(247) | word(249) << 16
            let rate = word(259), mode = bytes[294]
            guard count > 0, count <= 1_048_576, bytes.count == headers + count,
                  (1_000...65_535).contains(rate), mode & 0x1d == 0 else {
                throw SequelDataError.invalid("L3 voice requires complete, unlooped 8-bit sample data and a valid rate.")
            }
            sampleRate = Double(rate)
            samples = bytes.dropFirst(headers).map {
                mode & 2 != 0 ? Float(Int($0) - 128) / 128 : Float(Int8(bitPattern: $0)) / 128
            }
        }
    }

    public static let filenames: [ClassicSoundEffect: String] = [
        .doorOpen: "I_DOOR.PAT", .letsGo: "I_LETSGO.PAT", .assignSkill: "I_OK.PAT",
        .exitLevel: "I_YIPEE.PAT", .splat: "I_LEMDIE.PAT", .fallOut: "I_LEMDIE.PAT", .ohNo: "I_OHNO.PAT"
    ]
    public let clips: [ClassicSoundEffect: Clip]
    public init(root: URL) throws {
        clips = try Self.filenames.mapValues { name in
            try Clip(patch: Data(contentsOf: root.appendingPathComponent("AUDIO/GRAVIS/" + name)))
        }
    }
}

public enum Lemmings3SoundCue {
    public struct Snapshot: Sendable {
        let released: Int, saved: Int, lost: Int
        let bottomDeaths: Set<Int>
        let lemmings: [Int: Lemmings3Runtime.Lemming]
        let entrance: GameplaySoundPoint?
        public init(_ game: Lemmings3Runtime) {
            lemmings = Dictionary(uniqueKeysWithValues: game.lemmings.map { ($0.id, $0) })
            entrance = GameplaySoundPoint(x: Double(game.configuration.entrance.x), y: Double(game.configuration.entrance.y))
            released = game.released; saved = game.saved; lost = game.lost
            bottomDeaths = Set(game.lemmings.filter { $0.state == .dead && $0.y >= game.configuration.height }.map(\.id))
        }
    }
    public static func positionedCues(before: Snapshot, after: Snapshot) -> [PositionedSoundCue] {
        var result: [PositionedSoundCue] = []
        if before.released == 0 && after.released > 0 {
            result += [.init(.doorOpen, at: after.entrance), .init(.letsGo, at: after.entrance)]
        }
        for lem in after.lemmings.values.sorted(by: { $0.id < $1.id }) {
            let previous = before.lemmings[lem.id]
            let point = GameplaySoundPoint(x: Double(lem.x), y: Double(lem.y))
            if lem.state == .saved && previous?.state != .saved { result.append(.init(.exitLevel, at: point)) }
            if lem.state == .dead && previous?.state != .dead {
                result.append(.init(after.bottomDeaths.contains(lem.id) ? .fallOut : .splat, at: point))
            }
            if let previous, previous.state == .building, lem.quantity < previous.quantity {
                result.append(.init(.builderWarning, at: point))
            }
        }
        return result
    }

    /// Collapse simultaneous arrivals and losses to one voice per event kind.
    public static func cues(before: Snapshot, after: Snapshot) -> [ClassicSoundEffect] {
        var result: [ClassicSoundEffect] = []
        if before.released == 0 && after.released > 0 { result += [.doorOpen, .letsGo] }
        if after.saved > before.saved { result.append(.exitLevel) }
        let bottomLosses = after.bottomDeaths.subtracting(before.bottomDeaths).count
        if bottomLosses > 0 { result.append(.fallOut) }
        if after.lost - before.lost > bottomLosses { result.append(.splat) }
        return result
    }
}
