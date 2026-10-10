import Foundation

public struct GameplaySupplementClip: Sendable {
    public let samples: [Float]
    public let sampleRate: Double
    public let gain: Float
}

/// Short presentation effects fill verified gaps without guessing original bank indices.
public enum GameplaySupplementSounds {
    private static let clips: [ClassicSoundEffect: GameplaySupplementClip] = {
        var result: [ClassicSoundEffect: GameplaySupplementClip] = [:]
        func add(_ effect: ClassicSoundEffect, seconds: Double, gain: Float = 0.45,
                 sample: (Double, Double, Double) -> Double) {
            let count = Int(seconds * 44_100)
            var seed: UInt32 = 0x6c656d73
            let samples = (0..<count).map { index -> Float in
                let time = Double(index) / 44_100
                let progress = Double(index) / Double(count - 1)
                seed = seed &* 1_664_525 &+ 1_013_904_223
                let noise = Double(seed >> 8) / Double(0x00ff_ffff) * 2 - 1
                let envelope = min(1, time / 0.004) * pow(1 - progress, 2)
                return Float(max(-0.8, min(0.8, sample(time, progress, noise) * envelope)))
            }
            result[effect] = GameplaySupplementClip(samples: samples, sampleRate: 44_100, gain: gain)
        }
        func tone(_ time: Double, _ frequency: Double) -> Double { sin(2 * .pi * frequency * time) }
        add(.builderWarning, seconds: 0.08) { t, _, _ in tone(t, 1320) * 0.45 }
        add(.brickPlace, seconds: 0.045, gain: 0.22) { t, _, _ in
            tone(t, 880) * 0.32 + tone(t, 1760) * 0.1
        }
        add(.hitSteel, seconds: 0.09) { t, _, _ in
            tone(t, 740) * 0.4 + tone(t, 1777) * 0.18
        }
        add(.toolPickup, seconds: 0.13) { t, _, _ in
            tone(t, t < 0.055 ? 880 : 1320) * 0.5
        }
        add(.clockPickup, seconds: 0.22) { t, p, _ in
            tone(t, 600 + 300 * p) * 0.4 * (0.65 + 0.35 * cos(2 * .pi * 18 * t))
        }
        add(.projectileLaunch, seconds: 0.12) { t, _, noise in
            sin(2 * .pi * (420 * t + 2200 * t * t)) * 0.4 + noise * 0.04
        }
        add(.trampolineBounce, seconds: 0.2) { t, _, _ in
            sin(2 * .pi * (230 * t + 520 * 0.055 * (1 - exp(-t / 0.055)))) * 0.65
        }
        add(.trapTrigger, seconds: 0.13) { t, _, noise in
            tone(t, 190) * 0.4 + tone(t, 1100) * exp(-t * 75) * 0.25 + noise * 0.12
        }
        add(.waterEntry, seconds: 0.16) { t, _, noise in
            noise * exp(-t * 15) * 0.35 + sin(2 * .pi * (700 * t - 1200 * t * t)) * 0.15
        }
        add(.drown, seconds: 0.24) { t, _, noise in
            noise * exp(-t * 15) * 0.4 + sin(2 * .pi * (520 * t - 850 * t * t)) * 0.3
        }
        add(.explode, seconds: 0.28, gain: 0.55) { t, _, noise in
            sin(2 * .pi * (100 * t + 100 * 0.025 * (1 - exp(-t / 0.025)))) * 0.55
                + noise * exp(-t * 22) * 0.22
        }
        add(.timerWarning, seconds: 0.09, gain: 0.4) { t, _, _ in
            tone(t, t < 0.035 ? 660 : 990) * 0.45
        }
        add(.actionRejected, seconds: 0.065, gain: 0.3) { t, _, _ in
            sin(2 * .pi * (360 * t - 1400 * t * t)) * 0.5
        }
        add(.ready, seconds: 0.11, gain: 0.35) { t, _, _ in
            tone(t, t < 0.045 ? 660 : 990) * 0.45
        }
        // The bundled Yippee recording takes precedence over this preview fallback.
        add(.yippee, seconds: 0.22, gain: 0.5) { t, _, _ in
            sin(2 * .pi * (600 * t + 1400 * t * t)) * 0.5
        }
        return result
    }()

    public static func clip(for effect: ClassicSoundEffect) -> GameplaySupplementClip? { clips[effect] }
}
