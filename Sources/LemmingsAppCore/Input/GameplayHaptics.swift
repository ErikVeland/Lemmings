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
    case bridgeWarning, steel, fallLanding, bomber, nukeArm, nukeFuse, nukeImpact, nukeEcho

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
        case .fallLanding: [.init(0, 0, 0.38, 0.32), .init(0.019, 0.065, 0.14, 0.12)]
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
    private var lastLanding = -Double.infinity

    mutating func rebase(nuking: Bool) {
        armed = nuking; blasted = false; fusePlayed = nuking; lastOutput = -.infinity; lastLanding = -.infinity
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
            else if cues.contains(.splat), time - lastLanding >= 0.44 {
                cue = .fallLanding
                lastLanding = time
            }
            else { return nil }
        }
        lastOutput = time
        return cue
    }
}

/// The camera, not the world origin, is the listener. The device is mono;
/// split controller handles carry direction while both outputs stay active.
struct GameplayTactileMix: Equatable {
    let pan: Float
    let gain: Float

    static let centered = Self(pan: 0, gain: 1)
    var left: Float { gain * (0.10 + 0.90 * sqrt((1 - pan) / 2)) }
    var right: Float { gain * (0.10 + 0.90 * sqrt((1 + pan) / 2)) }
    func deviceGain(withController: Bool) -> Float { gain * (withController ? 0.57 : 1) }

    static func at(_ point: GameplaySoundPoint, in camera: GameplaySoundViewport) -> Self {
        guard camera.width > 0, camera.height > 0,
              [point.x, point.y, camera.x, camera.y, camera.width, camera.height].allSatisfy(\.isFinite)
        else { return .centered }
        let x = (point.x - camera.x) / camera.width * 2 - 1
        let y = (point.y - camera.y) / camera.height * 2 - 1
        let outside = hypot(max(0, abs(x) - 1), max(0, abs(y) - 1))
        return Self(pan: Float(min(1, max(-1, x))), gain: Float(1 / (1 + 3 * outside)))
    }

    static func select(for cue: GameplayTactileCue, from events: [PositionedSoundCue],
                       viewport: GameplaySoundViewport?) -> Self? {
        if cue == .nukeArm || cue == .nukeFuse { return .centered }
        func matches(_ event: PositionedSoundCue) -> Bool {
            switch cue {
            case .fallLanding: event.isFatalLanding
            case .bridgeWarning: event.effect == .builderWarning
            case .steel: event.effect == .hitSteel
            case .bomber, .nukeImpact, .nukeEcho: event.effect == .explode || event.effect == .pop
            default: false
            }
        }
        let positioned = events.filter(matches).compactMap { event -> Self? in
            guard let point = event.point, let viewport else { return nil }
            return at(point, in: viewport)
        }
        let winner = positioned.max { lhs, rhs in
            lhs.gain == rhs.gain ? abs(lhs.pan) > abs(rhs.pan) : lhs.gain < rhs.gain
        }
        if cue == .fallLanding { return winner.flatMap { $0.gain >= 0.26 ? $0 : nil } }
        guard let winner else { return .centered }
        // Keep the global nuke readable even if every explosion is offscreen.
        let floor: Float = cue == .nukeImpact ? 0.52 : (cue == .nukeEcho ? 0.25 : 0)
        return Self(pan: winner.pan, gain: max(floor, winner.gain))
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
    private var lastCue: GameplayTactileCue?
    private var controllerID: ObjectIdentifier?
    private var controllerActuators: [(channel: Channel, actuator: Actuator)] = []
    private enum Channel { case left, right, mono }
    private static let testMuted = ProcessInfo.processInfo.environment["LEMMINGS_TEST_AUDIO"] == "muted"
    private let device = Actuator {
        #if os(iOS)
        return CHHapticEngine.capabilitiesForHardware().supportsHaptics ? try? CHHapticEngine() : nil
        #else
        return nil
        #endif
    }

    public init() {}

    private static func cues(for requests: [Lemmings2SoundRequest]) -> [PositionedSoundCue] {
        requests.compactMap { request in
            if let meaning = request.supplementalEffect { return .init(meaning, at: request.point) }
            let effect: ClassicSoundEffect
            switch Lemmings2SoundCue(rawValue: request.sample) {
            case .builderWarning: effect = .builderWarning
            case .hitSteel: effect = .hitSteel
            case .explode: effect = .explode
            case .splat: effect = .splat
            default: return nil
            }
            return .init(effect, at: request.point)
        }
    }

    public func update(nuking: Bool, tick: Int, cues: [PositionedSoundCue], sequel: [Lemmings2SoundRequest] = [],
                       viewport: GameplaySoundViewport? = nil,
                       at time: TimeInterval = ProcessInfo.processInfo.systemUptime, secondsToBlast: Double? = nil) {
        guard !Self.testMuted else { return }
        guard GameplayHapticsPreference.enabled else {
            if lastCue != nil { pause() }
            score.rebase(nuking: nuking); lastTick = tick
            return
        }
        if let lastTick, tick < lastTick {
            seek(nuking: nuking, tick: tick)
            return
        }
        lastTick = tick
        if !nuking, lastCue?.isNuke == true { cancel() }
        let events = cues + Self.cues(for: sequel)
        let landing = GameplayTactileMix.select(for: .fallLanding, from: events, viewport: viewport)
        let effects = events.compactMap { event in
            event.effect != .splat || (event.isFatalLanding && landing != nil) ? event.effect : nil
        }
        guard let cue = score.update(nuking: nuking, cues: effects, at: time, secondsToBlast: secondsToBlast),
              let mix = cue == .fallLanding ? landing : GameplayTactileMix.select(for: cue, from: events, viewport: viewport)
        else { return }
        play(cue, mix: mix)
    }

    public func seek(nuking: Bool, tick: Int) {
        pause()
        score.rebase(nuking: nuking)
        lastTick = tick
    }

    public func pause() {
        lastCue = nil
        device.stop()
        for (_, actuator) in controllerActuators { actuator.stop() }
        controllerActuators.removeAll()
        controllerID = nil
    }

    public func reset() { pause(); lastTick = nil; score.rebase(nuking: false) }

    private func cancel() {
        lastCue = nil
        device.cancel()
        for (_, actuator) in controllerActuators { actuator.cancel() }
    }

    private func play(_ cue: GameplayTactileCue, mix: GameplayTactileMix) {
        let supported = GCController.controllers().filter { $0.haptics?.supportedLocalities.isEmpty == false }
        let controller = supported.first { $0.extendedGamepad is GCDualSenseGamepad } ?? supported.first
        let next = controller.map(ObjectIdentifier.init)
        if controllerID != next {
            for (_, actuator) in controllerActuators { actuator.stop() }
            controllerActuators.removeAll()
            controllerID = next
            if let haptics = controller?.haptics {
                let localities = haptics.supportedLocalities
                if localities.contains(.leftHandle), localities.contains(.rightHandle) {
                    controllerActuators = [
                        (.left, Actuator { haptics.createEngine(withLocality: .leftHandle) }),
                        (.right, Actuator { haptics.createEngine(withLocality: .rightHandle) })
                    ]
                } else if let locality = localities.contains(.handles) ? GCHapticsLocality.handles :
                    localities.contains(.default) ? .default : localities.first {
                    controllerActuators = [(.mono, Actuator { haptics.createEngine(withLocality: locality) })]
                }
            }
        }
        lastCue = cue
        var controllerRendered = false
        for (channel, actuator) in controllerActuators {
            let gain = switch channel {
            case .left: mix.left
            case .right: mix.right
            case .mono: mix.gain
            }
            controllerRendered = actuator.play(cue, gain: gain) || controllerRendered
        }
        _ = device.play(cue, gain: mix.deviceGain(withController: controllerRendered))
    }

    @MainActor private final class Actuator {
        private struct Pattern: Hashable { let cue: GameplayTactileCue; let gainLevel: Int }
        private let makeEngine: () -> CHHapticEngine?
        private var engine: CHHapticEngine?
        private var players: [Pattern: CHHapticPatternPlayer] = [:]
        private var active: Pattern?
        private var pending: Pattern?
        private var started = false
        private var starting = false
        private var generation = 0

        init(_ makeEngine: @escaping () -> CHHapticEngine?) { self.makeEngine = makeEngine }

        func cancel() {
            if let active { try? players[active]?.stop(atTime: CHHapticTimeImmediate) }
            active = nil; pending = nil
        }

        func stop() {
            cancel()
            engine?.stop(completionHandler: nil)
            clearEngine()
        }

        private func clearEngine() {
            generation += 1
            engine = nil; players.removeAll(keepingCapacity: true)
            active = nil; pending = nil; started = false; starting = false
        }

        @discardableResult func play(_ cue: GameplayTactileCue, gain: Float) -> Bool {
            let level = Int((max(0, min(1, gain)) * 16).rounded())
            guard level > 0 else { cancel(); return false }
            if engine == nil {
                guard let created = makeEngine() else { return false }
                created.playsHapticsOnly = true
                created.isAutoShutdownEnabled = true
                engine = created
                let id = generation
                created.stoppedHandler = { [weak self] _ in
                    Task { @MainActor in
                        guard let self, self.generation == id else { return }
                        self.started = false
                    }
                }
                created.resetHandler = { [weak self] in
                    Task { @MainActor in
                        guard let self, self.generation == id else { return }
                        self.clearEngine()
                    }
                }
            }
            guard let engine else { return false }
            let pattern = Pattern(cue: cue, gainLevel: level)
            if started { return play(pattern, on: engine) }
            pending = pattern
            guard !starting else { return true }
            starting = true
            let id = generation
            engine.start { [weak self] error in
                let succeeded = error == nil
                Task { @MainActor in
                    guard let self, self.generation == id else { return }
                    self.starting = false
                    guard succeeded, let engine = self.engine else { self.clearEngine(); return }
                    self.started = true
                    if let pending = self.pending { _ = self.play(pending, on: engine) }
                }
            }
            return true
        }

        private func play(_ pattern: Pattern, on engine: CHHapticEngine) -> Bool {
            do {
                if players[pattern] == nil {
                    let intensityScale = Float(pattern.gainLevel) / 16
                    let events = pattern.cue.pulses.map { pulse in
                        var parameters: [CHHapticEventParameter] = [
                            .init(parameterID: .hapticIntensity, value: pulse.intensity * intensityScale),
                            .init(parameterID: .hapticSharpness, value: pulse.sharpness)
                        ]
                        if pulse.duration > 0 {
                            parameters.append(.init(parameterID: .attackTime, value: 0.02))
                            parameters.append(.init(parameterID: .releaseTime, value: 0.12))
                        }
                        return CHHapticEvent(eventType: pulse.duration > 0 ? .hapticContinuous : .hapticTransient,
                                             parameters: parameters, relativeTime: pulse.start, duration: pulse.duration)
                    }
                    players[pattern] = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
                }
                cancel()
                try players[pattern]?.start(atTime: CHHapticTimeImmediate)
                active = pattern
                return true
            } catch {
                stop()
                return false
            }
        }
    }
}
#endif
