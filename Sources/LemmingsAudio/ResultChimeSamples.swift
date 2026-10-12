import Foundation

/// The Mac and iPad use the same three rising result notes.
public enum ResultChimeSamples {
    public static let sampleRate = 22_050.0
    public static func samples(star: Int, ornament: Bool = false) -> [Int16] {
        guard (1...3).contains(star) else { return [] }
        let frequency = [659.25, 830.61, 987.77][star - 1]
        let count = 5292
        var phase = 0.0
        return (0..<count).map { index in
            let time = Double(index) / sampleRate
            let progress = min(1, max(0, (time - 0.055) / 0.10))
            let scoop = ornament ? 1 + 0.20 * sin(progress * .pi) : 1
            let envelope = min(1, time / 0.008) * exp(-time * 20) * min(1, Double(count - index) / 220)
            let sample = Int16(sin(phase) * envelope * 9000)
            phase += frequency * scoop * 2 * .pi / sampleRate
            return sample
        }
    }
}
