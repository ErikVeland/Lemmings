import Foundation
import NxlvKit

struct GameplayTactilePulse: Equatable {
    let start: TimeInterval
    let duration: TimeInterval
    let intensity: Float
    let sharpness: Float

    init(_ start: TimeInterval, _ duration: TimeInterval, _ intensity: Float, _ sharpness: Float) {
        self.start = start; self.duration = duration
        self.intensity = intensity; self.sharpness = sharpness
    }
}

enum GameplayTactileCue: Hashable {
    case bridgeWarning, steel, bomber, nukeArm, nukeFuse, nukeImpact, nukeEcho

    var isNuke: Bool {
        switch self {
        case .nukeArm, .nukeFuse, .nukeImpact, .nukeEcho: true
        default: false
        }
    }

    var pulses: [GameplayTactilePulse] {
        switch self {
        case .bridgeWarning: [.init(0, 0, 0.24, 0.88), .init(0.058, 0, 0.13, 0.96)]
        case .steel: [.init(0, 0, 0.34, 0.76)]
        case .bomber: [.init(0, 0, 0.54, 0.34), .init(0.026, 0.11, 0.32, 0.18)]
        case .nukeArm: [.init(0, 0, 0.30, 0.26), .init(0.14, 0.10, 0.32, 0.13), .init(0.34, 0.18, 0.49, 0.17)]
        case .nukeFuse: [.init(0, 0, 0.40, 0.24), .init(0.10, 0.10, 0.58, 0.20)]
        case .nukeImpact: [.init(0, 0, 0.93, 0.35), .init(0.018, 0.28, 0.76, 0.11), .init(0.11, 0, 0.38, 0.22)]
        case .nukeEcho: [.init(0, 0, 0.48, 0.25), .init(0.020, 0.13, 0.28, 0.1)]
        }
    }
}

/// Keeps multi-builder and accelerated nuke cascades from becoming a constant buzz.
struct GameplayTactileScore {
    private var armed = false
    private var blasted = false
    private var fusePlayed = false
    private var lastOutput = -Double.infinity

    mutating func rebase(nuking: Bool) {
        armed = nuking; blasted = false; fusePlayed = nuking; lastOutput = -.infinity
    }

    mutating func update(nuking: Bool, cues: [ClassicSoundEffect], at time: TimeInterval, secondsToBlast: Double? = nil) -> GameplayTactileCue? {
        let armedNow = nuking && !armed
        let blast = cues.contains(.explode) || cues.contains(.pop)
        armed = nuking
        if !nuking { blasted = false; fusePlayed = false }
        let cue: GameplayTactileCue
        if nuking {
            if blast, !blasted {
                blasted = true
                cue = .nukeImpact
            } else if blast, time - lastOutput >= 0.38 {
                cue = .nukeEcho
            } else if armedNow {
                cue = .nukeArm
            } else if !blasted, !fusePlayed, let secondsToBlast,
                      secondsToBlast > 0, secondsToBlast <= 0.85, time - lastOutput >= 0.5 {
                fusePlayed = true
                cue = .nukeFuse
            } else { return nil }
        } else {
            guard time - lastOutput >= 0.22 else { return nil }
            if blast { cue = .bomber }
            else if cues.contains(.builderWarning) { cue = .bridgeWarning }
            else if cues.contains(.hitSteel) { cue = .steel }
            else { return nil }
        }
        lastOutput = time
        return cue
    }
}

public enum GameplayHapticsPreference {
    private static let key = "gameplayHapticsEnabled"
    public static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

#if canImport(CoreHaptics) && canImport(GameController)
import CoreHaptics
import GameController

/// Local presentation only: never fed into the simulation, recovery, or exported replays.
@MainActor public final class GameplayHaptics {
    private var score = GameplayTactileScore()
    private var lastTick: Int?
    private var endpoint: Endpoint?
    private var engine: CHHapticEngine?
    private var players: [GameplayTactileCue: CHHapticPatternPlayer] = [:]
    private var activeCue: GameplayTactileCue?
    private var pendingCue: GameplayTactileCue?
    private var engineStarted = false
    private var engineStarting = false
    private var engineGeneration = 0
    private static let testMuted = ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] == "muted"
    private enum Endpoint: Equatable { case device, controller(ObjectIdentifier) }

    public init() {}

    private static func cues(for requests: [Lemmings2SoundRequest]) -> [ClassicSoundEffect] {
        requests.compactMap { request in
            if let meaning = request.supplementalEffect { return meaning }
            switch Lemmings2SoundCue(rawValue: request.sample) {
            case .builderWarning: return .builderWarning
            case .hitSteel: return .hitSteel
            case .explode: return .explode
            default: return nil
            }
        }
    }

    public func update(nuking: Bool, tick: Int, cues: [PositionedSoundCue], sequel: [Lemmings2SoundRequest] = [],
                       at time: TimeInterval = ProcessInfo.processInfo.systemUptime, secondsToBlast: Double? = nil) {
        guard !Self.testMuted else { return }
        guard GameplayHapticsPreference.enabled else {
            if engine != nil { pause() }
            score.rebase(nuking: nuking); lastTick = tick
            return
        }
        if let lastTick, tick < lastTick {
            seek(nuking: nuking, tick: tick)
            return
        }
        lastTick = tick
        if !nuking, activeCue?.isNuke == true || pendingCue?.isNuke == true { stopCurrentCue() }
        guard let cue = score.update(nuking: nuking, cues: cues.map(\.effect) + Self.cues(for: sequel), at: time, secondsToBlast: secondsToBlast) else { return }
        play(cue)
    }

    public func seek(nuking: Bool, tick: Int) {
        pause()
        score.rebase(nuking: nuking)
        lastTick = tick
    }

    public func pause() {
        stopCurrentCue()
        if let engine { engine.stop(completionHandler: nil) }
        clearEngine()
    }

    public func reset() { pause(); lastTick = nil; score.rebase(nuking: false) }

    private func stopCurrentCue() {
        if let activeCue { try? players[activeCue]?.stop(atTime: CHHapticTimeImmediate) }
        activeCue = nil; pendingCue = nil
    }

    private func clearEngine() {
        engineGeneration += 1
        engine = nil; endpoint = nil; players.removeAll(keepingCapacity: true); activeCue = nil
        pendingCue = nil; engineStarted = false; engineStarting = false
    }

    private func play(_ cue: GameplayTactileCue) {
        let controllers = GCController.controllers()
        let supported = controllers.filter { $0.haptics?.supportedLocalities.isEmpty == false }
        let controller = supported.first { $0.extendedGamepad is GCDualSenseGamepad } ?? supported.first
        let next: Endpoint = controller.map { .controller(ObjectIdentifier($0)) } ?? .device
        if endpoint != next { pause() }
        if engine == nil {
            let created: CHHapticEngine?
            if let haptics = controller?.haptics {
                let localities = haptics.supportedLocalities
                let locality = localities.contains(.handles) ? GCHapticsLocality.handles :
                    localities.contains(.default) ? .default : localities.first
                created = locality.flatMap { haptics.createEngine(withLocality: $0) }
            } else {
                #if os(iOS)
                created = CHHapticEngine.capabilitiesForHardware().supportsHaptics ? try? CHHapticEngine() : nil
                #else
                created = nil
                #endif
            }
            guard let created else { return }
            created.playsHapticsOnly = true
            created.isAutoShutdownEnabled = true
            engine = created; endpoint = next
            let generation = engineGeneration
            created.stoppedHandler = { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.engineGeneration == generation else { return }
                    self.engineStarted = false
                }
            }
            created.resetHandler = { [weak self] in
                Task { @MainActor in
                    guard let self, self.engineGeneration == generation else { return }
                    self.clearEngine()
                }
            }
        }
        guard let engine else { return }
        if engineStarted {
            play(cue, on: engine)
            return
        }
        pendingCue = cue
        guard !engineStarting else { return }
        engineStarting = true
        let generation = engineGeneration
        engine.start { [weak self] error in
            let succeeded = error == nil
            Task { @MainActor in
                guard let self, self.engineGeneration == generation else { return }
                self.engineStarting = false
                guard succeeded, let engine = self.engine else { self.clearEngine(); return }
                self.engineStarted = true
                if let pending = self.pendingCue { self.play(pending, on: engine) }
            }
        }
    }

    private func play(_ cue: GameplayTactileCue, on engine: CHHapticEngine) {
        do {
            if players[cue] == nil {
                let events = cue.pulses.map { pulse in
                    var parameters: [CHHapticEventParameter] = [
                        .init(parameterID: .hapticIntensity, value: pulse.intensity),
                        .init(parameterID: .hapticSharpness, value: pulse.sharpness)
                    ]
                    if pulse.duration > 0 {
                        parameters.append(.init(parameterID: .attackTime, value: 0.02))
                        parameters.append(.init(parameterID: .releaseTime, value: 0.12))
                    }
                    return CHHapticEvent(eventType: pulse.duration > 0 ? .hapticContinuous : .hapticTransient,
                                         parameters: parameters, relativeTime: pulse.start, duration: pulse.duration)
                }
                players[cue] = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            }
            stopCurrentCue()
            try players[cue]?.start(atTime: CHHapticTimeImmediate)
            activeCue = cue
        } catch {
            clearEngine()
        }
    }
}
#endif
