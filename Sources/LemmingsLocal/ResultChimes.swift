import AppKit

/// Three short rising notes, prepared once and played only on the result page.
@MainActor final class ResultChimes {
    private var notes: [Int: NSSound] = [:]
    private var volumeTask: Task<Void, Never>?
    private var activeNote: NSSound?
    private(set) var currentVolume: Double = 0
    var onPlay: ((Int, Bool, Double) -> Void)?

    /// The ornament changes pitch inside the final note without adding another sound.
    static func samples(star: Int, ornament: Bool = false) -> [Int16] {
        guard (1...3).contains(star) else { return [] }
        let frequency = [659.25, 830.61, 987.77][star - 1]
        let rate = 22050, count = 5292
        var phase = 0.0
        return (0..<count).map { index in
            let time = Double(index) / Double(rate)
            let progress = min(1, max(0, (time - 0.055) / 0.10))
            let scoop = ornament ? 1 + 0.20 * sin(progress * .pi) : 1
            let envelope = min(1, time / 0.008) * exp(-time * 20) * min(1, Double(count - index) / 220)
            let sample = Int16(sin(phase) * envelope * 9000)
            phase += frequency * scoop * 2 * .pi / Double(rate)
            return sample
        }
    }

    func play(star: Int, ornament: Bool = false, volume: @escaping () -> Double) {
        guard (1...3).contains(star) else { return }
        let gain = Self.gain(volume())
        guard gain > 0 else { stop(); return }
        let key = star + (ornament ? 3 : 0)
        if notes[key] == nil {
            let samples = Self.samples(star: star, ornament: ornament)
            var data = Data()
            func bytes(_ value: String) { data.append(contentsOf: value.utf8) }
            func word<T: FixedWidthInteger>(_ value: T) {
                var little = value.littleEndian
                withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
            }
            bytes("RIFF"); word(UInt32(36 + samples.count * 2)); bytes("WAVEfmt ")
            word(UInt32(16)); word(UInt16(1)); word(UInt16(1)); word(UInt32(22050))
            word(UInt32(44100)); word(UInt16(2)); word(UInt16(16)); bytes("data"); word(UInt32(samples.count * 2))
            samples.forEach { word($0) }
            notes[key] = NSSound(data: data)
        }
        guard let note = notes[key] else { return }
        stop()
        currentVolume = gain
        note.volume = Float(gain)
        activeNote = note
        onPlay?(star, ornament, gain)
        note.play()
        volumeTask = Task { @MainActor [weak self] in
            // Keep mute, suspension and volume changes effective during the note's tail.
            for _ in 0..<12 {
                do { try await Task.sleep(nanoseconds: 20_000_000) } catch { return }
                guard let self else { return }
                let gain = Self.gain(volume())
                self.currentVolume = gain
                note.volume = Float(gain)
                if gain == 0 { self.stop(); return }
            }
            self?.activeNote = nil
            self?.currentVolume = 0
            self?.volumeTask = nil
        }
    }

    private static func gain(_ value: Double) -> Double { value.isFinite ? min(1, max(0, value)) : 0 }
    func stop() {
        volumeTask?.cancel(); volumeTask = nil
        activeNote?.stop(); activeNote = nil; currentVolume = 0
    }
}
