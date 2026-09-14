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
    /// Version 2 routes hold one ordered event list and no inputs or pointers.
    public let events: [Lemmings2TimedEvent]?

    public init(levelSHA256: String, population: Int, expectedSaved: Int, expectedTicks: Int,
                inputs: [Input], pointers: [Pointer]) {
        version = 1
        self.levelSHA256 = levelSHA256
        self.population = population
        self.expectedSaved = expectedSaved
        self.expectedTicks = expectedTicks
        self.inputs = inputs
        self.pointers = pointers
        events = nil
    }

    public init(levelSHA256: String, population: Int, expectedSaved: Int, expectedTicks: Int,
                events: [Lemmings2TimedEvent]) {
        version = 2
        self.levelSHA256 = levelSHA256
        self.population = population
        self.expectedSaved = expectedSaved
        self.expectedTicks = expectedTicks
        inputs = []
        pointers = nil
        self.events = events
    }

    private enum CodingKeys: String, CodingKey {
        case version, levelSHA256, population, expectedSaved, expectedTicks, inputs, pointers, events
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        levelSHA256 = try container.decode(String.self, forKey: .levelSHA256)
        population = try container.decode(Int.self, forKey: .population)
        expectedSaved = try container.decode(Int.self, forKey: .expectedSaved)
        expectedTicks = try container.decode(Int.self, forKey: .expectedTicks)
        inputs = try container.decodeIfPresent([Input].self, forKey: .inputs) ?? []
        pointers = try container.decodeIfPresent([Pointer].self, forKey: .pointers)
        events = try container.decodeIfPresent([Lemmings2TimedEvent].self, forKey: .events)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(levelSHA256, forKey: .levelSHA256)
        try container.encode(population, forKey: .population)
        try container.encode(expectedSaved, forKey: .expectedSaved)
        try container.encode(expectedTicks, forKey: .expectedTicks)
        if let events {
            try container.encode(events, forKey: .events)
        } else {
            try container.encode(inputs, forKey: .inputs)
            try container.encodeIfPresent(pointers, forKey: .pointers)
        }
    }

    /// The route as events. Version 1 converts exactly: a pointer sets the aim and the fan, and an
    /// assignment releases the fan, assigns, and holds the fan again when the last pointer held it.
    public func timedEvents() -> [Lemmings2TimedEvent] {
        if let events { return events }
        let pointers = self.pointers ?? []
        var result: [Lemmings2TimedEvent] = []
        var p = 0, i = 0
        var last: Pointer?
        while p < pointers.count || i < inputs.count {
            let tick = min(p < pointers.count ? pointers[p].tick : .max, i < inputs.count ? inputs[i].tick : .max)
            while p < pointers.count && pointers[p].tick == tick {
                let q = pointers[p]
                result.append(.init(tick: tick, event: .aim(x: q.fan ? q.fanX : q.x, y: q.fan ? q.fanY : q.y, held: !q.fan)))
                result.append(.init(tick: tick, event: .fan(x: q.fanX, y: q.fanY, active: q.fan)))
                last = q
                p += 1
            }
            while i < inputs.count && inputs[i].tick == tick {
                result.append(.init(tick: tick, event: .fan(x: 0, y: 0, active: false)))
                result.append(.init(tick: tick, event: .assign(skill: inputs[i].skill, lemming: inputs[i].lemming)))
                if let last, last.fan {
                    result.append(.init(tick: tick, event: .fan(x: last.fanX, y: last.fanY, active: true)))
                }
                i += 1
            }
        }
        return result
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

/// One runtime call in a version 2 route. Events apply in list order on their tick, before the runtime steps.
public enum Lemmings2RouteEvent: Codable, Sendable, Equatable {
    case assign(skill: Int, lemming: Int)
    case aim(x: Int, y: Int, held: Bool)
    case fan(x: Int, y: Int, active: Bool)
    case releasePointer
    case machine(x: Int, y: Int)
    case chain(x: Int, y: Int)
    case nuke
}

public struct Lemmings2TimedEvent: Codable, Sendable, Equatable {
    public let tick: Int
    public let event: Lemmings2RouteEvent
    public init(tick: Int, event: Lemmings2RouteEvent) {
        self.tick = tick
        self.event = event
    }
}

/// Applies version 2 events. The strict form throws on a refused event. The lenient form, which the
/// solver uses, removes a refused event from the list. A refusal is found before any runtime call
/// changes state, so a strict replay of the kept list reaches the same state.
public struct Lemmings2EventCursor: Sendable {
    public private(set) var next = 0

    public init() {}

    /// Performs one event. Returns false, without changing the runtime, when the runtime refuses it.
    public static func perform(_ event: Lemmings2RouteEvent, on game: inout Lemmings2Runtime) -> Bool {
        switch event {
        case let .assign(skill, lemming):
            guard let slot = game.configuration.skills.firstIndex(where: { $0.rawValue == skill }),
                  game.canAssign(slot: slot, to: lemming) else { return false }
            return game.assign(slot: slot, to: lemming)
        case let .aim(x, y, held):
            game.setAim(x: x, y: y, held: held)
            return true
        case let .fan(x, y, active):
            game.setFan(x: x, y: y, active: active)
            return true
        case .releasePointer:
            game.releasePointerInput()
            return true
        case let .machine(x, y):
            return game.moveMachine(x: x, y: y)
        case let .chain(x, y):
            return game.releaseChain(x: x, y: y)
        case .nuke:
            guard !game.isComplete, !game.isNuking else { return false }
            game.nuke()
            return true
        }
    }

    /// Applies the events for the runtime's current tick. Throws when the runtime refuses one.
    public mutating func apply(eventsAt game: inout Lemmings2Runtime, events: [Lemmings2TimedEvent]) throws {
        while next < events.count && events[next].tick == game.tick {
            guard Self.perform(events[next].event, on: &game) else { throw Lemmings2WitnessError.rejectedInput(next) }
            next += 1
        }
    }

    /// Applies the events for the current tick and removes each refused event. An event for a tick
    /// that has already passed counts as refused. Returns the number of events removed.
    public mutating func applyDroppingRefused(eventsAt game: inout Lemmings2Runtime,
                                              events: inout [Lemmings2TimedEvent]) -> Int {
        var dropped = 0
        while next < events.count && events[next].tick <= game.tick {
            if events[next].tick == game.tick && Self.perform(events[next].event, on: &game) {
                next += 1
            } else {
                events.remove(at: next)
                dropped += 1
            }
        }
        return dropped
    }
}

extension Lemmings2ReplayWitness {
    /// Replays the route from a fresh runtime to the end of the level and returns its outcome.
    /// Unlike `run`, it does not compare the outcome with the expected values.
    public func outcome(level: Lemmings2Level, style: Lemmings2Style,
                        masks: Lemmings2TerrainMasks) throws -> Lemmings2WitnessOutcome {
        guard levelSHA256 == level.fingerprint else {
            throw Lemmings2WitnessError.unknownLevel(levelSHA256)
        }
        var game = try Lemmings2Runtime(level: level, style: style, masks: masks, total: population)
        let xRange = level.minimumScreenX...(level.maximumScreenX + 319)
        let yRange = level.minimumScreenY...(level.maximumScreenY + 159)
        if let events {
            guard zip(events, events.dropFirst()).allSatisfy({ $0.tick <= $1.tick }) else {
                throw Lemmings2WitnessError.outOfOrderInput
            }
            for (index, timed) in events.enumerated() {
                let point: (x: Int, y: Int)?
                switch timed.event {
                case let .aim(x, y, _), let .machine(x, y), let .chain(x, y): point = (x, y)
                // A released fan has no position, so only an active fan is checked.
                case let .fan(x, y, active): point = active ? (x, y) : nil
                case .assign, .releasePointer, .nuke: point = nil
                }
                if let point, !xRange.contains(point.x) || !yRange.contains(point.y) {
                    throw Lemmings2WitnessError.pointerOutOfViewport(index)
                }
            }
            var cursor = Lemmings2EventCursor()
            while !game.isComplete {
                try cursor.apply(eventsAt: &game, events: events)
                game.step()
            }
            guard cursor.next == events.count else { throw Lemmings2WitnessError.outcomeChanged(levelSHA256) }
        } else {
            guard inputsAreOrdered else { throw Lemmings2WitnessError.outOfOrderInput }
            let pointers = self.pointers ?? []
            for (index, p) in pointers.enumerated() {
                guard xRange.contains(p.x), yRange.contains(p.y), !p.fan || (p.x == p.fanX && p.y == p.fanY) else {
                    throw Lemmings2WitnessError.pointerOutOfViewport(index)
                }
            }
            var cursor = Lemmings2InputCursor()
            while !game.isComplete {
                try cursor.apply(inputsAt: &game, inputs: inputs, pointers: pointers)
                game.step()
            }
            guard cursor.command == inputs.count, cursor.pointer == pointers.count else {
                throw Lemmings2WitnessError.outcomeChanged(levelSHA256)
            }
        }
        return .init(saved: game.saved, ticks: game.tick,
            medal: Lemmings2Campaign.medal(saved: game.saved, total: population,
                allowedLosses: level.allowedLossesForGold),
            stateHash: game.stateFingerprint)
    }

    /// Replays the route and requires the expected win, saved count and ticks.
    public func run(level: Lemmings2Level, style: Lemmings2Style,
                    masks: Lemmings2TerrainMasks) throws -> Lemmings2WitnessOutcome {
        let result = try outcome(level: level, style: style, masks: masks)
        guard result.saved > 0, result.saved == expectedSaved, result.ticks == expectedTicks else {
            throw Lemmings2WitnessError.outcomeChanged(levelSHA256)
        }
        return result
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
