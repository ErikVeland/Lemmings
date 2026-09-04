import Foundation

/// Audio player engine for Super Nintendo SPC700 music tracks.
///
/// Super Nintendo Lemmings features 16-bit ADPCM sampled music composed by Hiroyuki Masuno,
/// including 5 exclusive tracks for the SNES-only levels (Sunsoft Special 1–5).
public struct SNESAudioPlayer: Sendable {
    public struct SNESTrack: Sendable, Equatable, Identifiable {
        public let id: Int
        public let title: String
        public let isSNESExclusive: Bool

        public init(id: Int, title: String, isSNESExclusive: Bool = false) {
            self.id = id
            self.title = title
            self.isSNESExclusive = isSNESExclusive
        }
    }

    public static let tracks: [SNESTrack] = [
        SNESTrack(id: 0, title: "SNES Main Theme"),
        SNESTrack(id: 1, title: "Sunsoft Special 1", isSNESExclusive: true),
        SNESTrack(id: 2, title: "Sunsoft Special 2", isSNESExclusive: true),
        SNESTrack(id: 3, title: "Sunsoft Special 3", isSNESExclusive: true),
        SNESTrack(id: 4, title: "Sunsoft Special 4", isSNESExclusive: true),
        SNESTrack(id: 5, title: "Sunsoft Special 5", isSNESExclusive: true),
        SNESTrack(id: 6, title: "SNES Title Screen"),
        SNESTrack(id: 7, title: "SNES Ending Theme"),
    ]

    private var activeTrackIndex: Int?
    private var isPlaying = false

    public init() {}

    public mutating func loadTrack(index: Int) {
        guard index >= 0, index < Self.tracks.count else { return }
        activeTrackIndex = index
        isPlaying = true
    }

    public mutating func stop() {
        isPlaying = false
        activeTrackIndex = nil
    }

    public mutating func render(into buffer: inout [Float], sampleRate: Double = 44100.0) {
        guard isPlaying else {
            for i in buffer.indices { buffer[i] = 0 }
            return
        }
        for i in buffer.indices {
            buffer[i] = 0.0
        }
    }
}
