import CryptoKit
import Foundation

/// One recorded winning route for a Lemmings 2 campaign level.
/// The completion gate, the runtime suite and the route solver share this type, so their rules cannot drift.
public struct Lemmings2ReplayWitness: Codable, Sendable {
    public struct Pointer: Codable, Sendable {
        public let tick: Int, x: Int, y: Int, fanX: Int, fanY: Int, fan: Bool
        public init(tick: Int, x: Int, y: Int, fanX: Int, fanY: Int, fan: Bool) {
            self.tick = tick; self.x = x; self.y = y; self.fanX = fanX; self.fanY = fanY; self.fan = fan
        }
    }
    public struct Input: Codable, Sendable {
        public let tick: Int, lemming: Int, skill: Int
        public init(tick: Int, lemming: Int, skill: Int) {
            self.tick = tick; self.lemming = lemming; self.skill = skill
        }
    }
    public let version: Int
    public let levelSHA256: String
    public let population: Int
    public let expectedSaved: Int
    public let expectedTicks: Int
    public let inputs: [Input]
    public let pointers: [Pointer]?

    public init(levelSHA256: String, population: Int, expectedSaved: Int, expectedTicks: Int,
                inputs: [Input], pointers: [Pointer]) {
        version = 1
        self.levelSHA256 = levelSHA256
        self.population = population
        self.expectedSaved = expectedSaved
        self.expectedTicks = expectedTicks
        self.inputs = inputs
        self.pointers = pointers
    }

    public var inputsAreOrdered: Bool {
        zip(inputs, inputs.dropFirst()).allSatisfy { $0.tick <= $1.tick }
    }
}

public struct Lemmings2WitnessOutcome: Sendable {
    public let saved: Int, ticks: Int
    public let medal: Lemmings2Campaign.Medal
    public let stateHash: String
}

public enum Lemmings2WitnessError: Error, Sendable {
    case unknownLevel(String)
    case rejectedInput(Int)
    case outOfOrderInput
    case pointerOutOfViewport(Int)
    case outcomeChanged(String)
}

/// Applies recorded input to a runtime one tick at a time. The replay witness and the
/// route solver both use it, so a route found by the solver replays in the same order.
public struct Lemmings2InputCursor: Sendable {
    public private(set) var command = 0
    public private(set) var pointer = 0

    public init() {}

    /// Applies the pointer and skill input recorded for the runtime's current tick.
    /// Pointer input comes first, then skill assignments, as in the app.
    public mutating func apply(inputsAt game: inout Lemmings2Runtime,
                               inputs: [Lemmings2ReplayWitness.Input],
                               pointers: [Lemmings2ReplayWitness.Pointer]) throws {
        while pointer < pointers.count && pointers[pointer].tick == game.tick {
            let p = pointers[pointer]
            game.setAim(x: p.fan ? p.fanX : p.x, y: p.fan ? p.fanY : p.y, held: !p.fan)
            game.setFan(x: p.fanX, y: p.fanY, active: p.fan)
            pointer += 1
        }
        while command < inputs.count && inputs[command].tick == game.tick {
            let event = inputs[command]
            guard let slot = game.configuration.skills.firstIndex(where: { $0.rawValue == event.skill }) else {
                throw Lemmings2WitnessError.rejectedInput(command)
            }
            // Selecting a skill releases the fan. Selecting it again
            // after the assignment starts a new hold, as in the app.
            game.setFan(x: 0, y: 0, active: false)
            guard game.assign(slot: slot, to: event.lemming) else {
                throw Lemmings2WitnessError.rejectedInput(command)
            }
            if pointer > 0, pointers[pointer - 1].fan {
                let p = pointers[pointer - 1]
                game.setFan(x: p.fanX, y: p.fanY, active: true)
            }
            command += 1
        }
    }
}

extension Lemmings2ReplayWitness {
    /// Replays the route from a fresh runtime and returns its outcome.
    public func run(level: Lemmings2Level, style: Lemmings2Style,
                    masks: Lemmings2TerrainMasks) throws -> Lemmings2WitnessOutcome {
        guard inputsAreOrdered else { throw Lemmings2WitnessError.outOfOrderInput }
        guard levelSHA256 == level.fingerprint else {
            throw Lemmings2WitnessError.unknownLevel(levelSHA256)
        }
        var game = try Lemmings2Runtime(level: level, style: style, masks: masks, total: population)
        let pointers = self.pointers ?? []
        for (index, p) in pointers.enumerated() {
            let insideX = (level.minimumScreenX...level.maximumScreenX + 319).contains(p.x)
            let insideY = (level.minimumScreenY...level.maximumScreenY + 159).contains(p.y)
            guard insideX, insideY, !p.fan || (p.x == p.fanX && p.y == p.fanY) else {
                throw Lemmings2WitnessError.pointerOutOfViewport(index)
            }
        }
        var cursor = Lemmings2InputCursor()
        while !game.isComplete && game.tick <= expectedTicks {
            try cursor.apply(inputsAt: &game, inputs: inputs, pointers: pointers)
            game.step()
        }
        guard cursor.command == inputs.count, cursor.pointer == pointers.count, game.didWin,
              game.saved == expectedSaved, game.tick == expectedTicks else {
            throw Lemmings2WitnessError.outcomeChanged(levelSHA256)
        }
        return .init(saved: game.saved, ticks: game.tick,
            medal: Lemmings2Campaign.medal(saved: game.saved, total: population,
                allowedLosses: level.allowedLossesForGold),
            stateHash: game.stateFingerprint)
    }
}

extension Lemmings2Runtime {
    /// A stable hash of the whole simulation state. Two runs of one route must produce the same value.
    public var stateFingerprint: String {
        var hasher = SHA256()
        func add(_ value: Int) { withUnsafeBytes(of: Int64(value).littleEndian) { hasher.update(bufferPointer: $0) } }
        hasher.update(data: Data(pixels))
        supplies.forEach(add)
        for lemming in lemmings {
            [lemming.id, lemming.x, lemming.y, lemming.direction, lemming.age, lemming.fallDistance,
             lemming.work, lemming.slider ? 1 : 0, lemming.skater ? 1 : 0, lemming.iceDirection].forEach(add)
            // State is String-backed, so hash its name rather than an integer.
            hasher.update(data: Data(lemming.state.rawValue.utf8))
        }
        add(tick)
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
