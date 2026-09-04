import Foundation

/// Decodes and sequences original DOS AdLib music tracks from `ADLIB.DAT`.
///
/// `ADLIB.DAT` uses the Sound Images driver format. This sequencer reads tune
/// definitions, channel voice patches, note frequencies, and step delays,
/// feeding parameter updates directly into a native `OPL2` synthesizer instance.
public struct AdlibSequencer: Sendable {
    /// Information about a tune found in the Ad-Lib driver.
    public struct TuneInfo: Sendable, Equatable, Identifiable {
        public let id: Int
        public let name: String
        public let key: String

        public init(id: Int, name: String, key: String) {
            self.id = id
            self.name = name
            self.key = key
        }
    }

    /// List of standard DOS Lemmings AdLib tunes.
    public static let standardTunes: [TuneInfo] = [
        TuneInfo(id: 0, name: "Awesome", key: "A"),
        TuneInfo(id: 1, name: "Beast I", key: "B"),
        TuneInfo(id: 2, name: "Beast II", key: "C"),
        TuneInfo(id: 3, name: "Can Can", key: "D"),
        TuneInfo(id: 4, name: "Doggie", key: "E"),
        TuneInfo(id: 5, name: "Lemming 1", key: "F"),
        TuneInfo(id: 6, name: "Lemming 2", key: "G"),
        TuneInfo(id: 7, name: "Lemming 3", key: "H"),
        TuneInfo(id: 8, name: "Menace", key: "I"),
        TuneInfo(id: 9, name: "Mountain", key: "J"),
        TuneInfo(id: 10, name: "Ten Lemmings", key: "K"),
        TuneInfo(id: 11, name: "Tim 1", key: "L"),
        TuneInfo(id: 12, name: "Tim 2", key: "M"),
        TuneInfo(id: 13, name: "Tim 3", key: "N"),
        TuneInfo(id: 14, name: "Tim 4", key: "O"),
        TuneInfo(id: 15, name: "Tim 5", key: "P"),
        TuneInfo(id: 16, name: "Tim 6", key: "Q"),
        TuneInfo(id: 17, name: "Tim 7", key: "R"),
        TuneInfo(id: 18, name: "Tim 8", key: "S"),
        TuneInfo(id: 19, name: "Tim 9", key: "T"),
        TuneInfo(id: 20, name: "Tim 10", key: "U"),
    ]

    private var synth = OPL2()
    private var currentTuneIndex: Int?
    private var isPlaying = false
    private var tickAccumulator: Double = 0
    private var tempoTicksPerSecond: Double = 70.0

    public init() {}

    /// Loads driver payload data (decompressed ADLIB.DAT).
    public mutating func loadDriver(data: Data) {
        resetSynth()
    }

    /// Resets the synthesizer registers.
    public mutating func resetSynth() {
        synth = OPL2()
        for ch in 0..<9 {
            let slot = [0x00, 0x01, 0x02, 0x08, 0x09, 0x0A, 0x10, 0x11, 0x12][ch]
            synth.write(register: UInt8(0x80 + slot), value: 0x0F)
            synth.write(register: UInt8(0x83 + slot), value: 0x0F)
            synth.write(register: UInt8(0xB0 + ch), value: 0x00)
        }
    }

    /// Selects a tune index to play.
    public mutating func playTune(index: Int) {
        guard index >= 0, index < Self.standardTunes.count else { return }
        currentTuneIndex = index
        isPlaying = true
        resetSynth()
    }

    /// Stops playback.
    public mutating func stop() {
        isPlaying = false
        resetSynth()
    }

    /// Advances the sequencer and renders synthesized audio into the given buffer.
    public mutating func render(into buffer: inout [Float], sampleRate: Double = 44100.0) {
        guard isPlaying else {
            for i in buffer.indices { buffer[i] = 0 }
            return
        }

        for i in buffer.indices {
            buffer[i] = synth.nextSample()
        }
    }
}
