import Foundation

/// Track list for the Super Nintendo soundtrack. Not a player yet.
///
/// `render(into:)` writes silence. There is no SPC700 core and no BRR sample
/// decoder behind this type, so `.snesSPC` is not offered as a music source.
/// The track titles below record what the release contains, including the five
/// tracks written for the Super Nintendo levels.
///
/// To finish this: emulate the SPC700 and the S-DSP, then read the sample
/// directory and the note data out of the ROM.
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
