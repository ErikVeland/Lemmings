import Foundation
import NxlvKit

/// A guide route may end before a full winning replay. This format keeps its source identity checks.
struct L3GuideSeed: Decodable {
    let version: Int
    let level: Int
    let levelSHA256: String
    let population: Int
    let initialStateHash: String
    let inputs: [L3Replay.Input]
}

/// The state needed to compare one guide instruction with its next replay attempt.
struct L3GuideTraceSnapshot: Codable, Equatable {
    let tick: Int
    let saved: Int
    let lost: Int
    let reserve: Int
    let released: Int
    let complete: Bool
    let stateHash: String
    let lemming: L3GuideTraceLemming?
}

/// The selected lemming state at a guide instruction.
struct L3GuideTraceLemming: Codable, Equatable {
    let id: Int
    let x: Int
    let y: Int
    let direction: Int
    let state: String
    let tool: String?
    let quantity: Int
    let workDirection: String
}

/// One accepted guide instruction and the state immediately before and after it.
struct L3GuideTraceEntry: Codable {
    let index: Int
    let input: L3Replay.Input
    let before: L3GuideTraceSnapshot
    let accepted: Bool
    let after: L3GuideTraceSnapshot
}

/// A state transition observed between scheduled guide instructions.
struct L3GuideTraceEvent: Codable {
    let tick: Int
    let from: String
    let to: String
    let lemming: L3GuideTraceLemming
}

/// The result of replaying a checked guide prefix to a fixed tick.
struct L3GuideTraceResult: Codable {
    let entries: [L3GuideTraceEntry]
    let events: [L3GuideTraceEvent]
    let final: L3GuideTraceSnapshot
}

enum L3GuideTrace {
    /// Replays a guide prefix and records every scheduled action without requiring a completed level.
    static func replay(seed: L3GuideSeed, from base: Lemmings3Runtime, levelData: Data,
                       throughTick: Int) throws -> L3GuideTraceResult {
        guard seed.version == 1,
              seed.population == base.configuration.total,
              seed.levelSHA256 == L3Replay.digest(levelData),
              seed.initialStateHash == L3Replay.stateHash(base),
              seed.inputs.count <= 100_000,
              (0..<30_000).contains(throughTick),
              seed.inputs.allSatisfy({ (0...throughTick).contains($0.tick) }),
              zip(seed.inputs, seed.inputs.dropFirst()).allSatisfy({ $0.tick <= $1.tick }) else {
            throw SequelDataError.invalid("L3 guide source, checkpoint or input order differs.")
        }

        var game = base
        var cursor = 0
        var entries: [L3GuideTraceEntry] = []
        var previousStates = Dictionary(uniqueKeysWithValues: game.lemmings.map { ($0.id, $0.state) })
        var events: [L3GuideTraceEvent] = []
        while !game.isComplete && game.tick <= throughTick {
            while cursor < seed.inputs.count && seed.inputs[cursor].tick == game.tick {
                let input = seed.inputs[cursor]
                let before = snapshot(game, lemming: input.lemming)
                let accepted = L3Replay.apply(input, to: &game)
                let after = snapshot(game, lemming: input.lemming)
                entries.append(.init(index: cursor, input: input, before: before, accepted: accepted, after: after))
                guard accepted else {
                    throw SequelDataError.invalid("L3 guide input \(cursor) failed at tick \(game.tick).")
                }
                cursor += 1
            }
            if game.tick == throughTick { break }
            game.step()
            for actor in game.lemmings {
                guard let previous = previousStates[actor.id], previous != actor.state else { continue }
                events.append(.init(tick: game.tick, from: previous.rawValue, to: actor.state.rawValue,
                                    lemming: lemmingSnapshot(actor)))
            }
            previousStates = Dictionary(uniqueKeysWithValues: game.lemmings.map { ($0.id, $0.state) })
        }
        guard cursor == seed.inputs.count else {
            throw SequelDataError.invalid("L3 guide ended before input \(cursor).")
        }
        return .init(entries: entries, events: events, final: snapshot(game, lemming: nil))
    }

    /// Produces a stable, serialisable checkpoint that names the selected actor where one exists.
    static func snapshot(_ game: Lemmings3Runtime, lemming id: Int?) -> L3GuideTraceSnapshot {
        let lemming = id.flatMap { selected in game.lemmings.first(where: { $0.id == selected }).map(lemmingSnapshot) }
        return .init(tick: game.tick, saved: game.saved, lost: game.lost, reserve: game.reserve,
                     released: game.released, complete: game.isComplete, stateHash: L3Replay.stateHash(game),
                     lemming: lemming)
    }

    /// Produces the actor portion of a checkpoint or transition event.
    static func lemmingSnapshot(_ actor: Lemmings3Runtime.Lemming) -> L3GuideTraceLemming {
        .init(id: actor.id, x: actor.x, y: actor.y, direction: actor.direction, state: actor.state.rawValue,
              tool: actor.tool?.label, quantity: actor.quantity, workDirection: actor.workDirection.rawValue)
    }
}
