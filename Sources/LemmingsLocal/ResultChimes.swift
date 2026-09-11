import AppKit

/// Three short rising notes, prepared once and played only on the result page.
@MainActor final class ResultChimes {
    private var notes: [NSSound] = []
    func play(star: Int, volume: Double) {
        guard volume > 0, (1...3).contains(star) else { return }
        if notes.isEmpty {
            notes = [659.25, 830.61, 987.77].compactMap { frequency in
                let rate = 22050, count = 5292
                var data = Data()
                func bytes(_ value: String) { data.append(contentsOf: value.utf8) }
                func word<T: FixedWidthInteger>(_ value: T) {
                    var little = value.littleEndian
                    withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
                }
                bytes("RIFF"); word(UInt32(36 + count * 2)); bytes("WAVEfmt ")
                word(UInt32(16)); word(UInt16(1)); word(UInt16(1)); word(UInt32(rate))
                word(UInt32(rate * 2)); word(UInt16(2)); word(UInt16(16)); bytes("data"); word(UInt32(count * 2))
                for index in 0..<count {
                    let time = Double(index) / Double(rate)
                    let envelope = min(1, time / 0.008) * exp(-time * 20) * min(1, Double(count - index) / 220)
                    word(Int16(sin(time * frequency * 2 * .pi) * envelope * 9000))
                }
                return NSSound(data: data)
            }
        }
        guard notes.indices.contains(star - 1) else { return }
        let note = notes[star - 1]; note.volume = Float(min(1, max(0, volume)))
        note.stop(); note.play()
    }
    func stop() { notes.forEach { $0.stop() } }
}
