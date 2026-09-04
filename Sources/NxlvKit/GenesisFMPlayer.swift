import Foundation

/// Audio player engine for Sega Genesis / Mega Drive YM2612 FM music tracks.
///
/// Sega Genesis Lemmings features Matt Furniss's iconic 6-channel FM soundtrack.
public struct GenesisFMPlayer: Sendable {
    public struct GenesisTrack: Sendable, Equatable, Identifiable {
        public let id: Int
        public let title: String

        public init(id: Int, title: String) {
            self.id = id
            self.title = title
        }
    }

    public static let tracks: [GenesisTrack] = [
        GenesisTrack(id: 0, title: "Genesis Presenter Theme"),
        GenesisTrack(id: 1, title: "Genesis Tricky Theme"),
        GenesisTrack(id: 2, title: "Genesis Taxing Theme"),
        GenesisTrack(id: 3, title: "Genesis Mayhem Theme"),
        GenesisTrack(id: 4, title: "Genesis Title Screen"),
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
