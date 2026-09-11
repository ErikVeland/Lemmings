import CryptoKit
import Foundation
import NxlvKit

struct L3Replay: Codable {
    struct Input: Codable {
        let tick: Int
        let action: String
        let lemming: Int?
        let direction: String?
    }
    struct Outcome: Codable, Equatable {
        let ticks: Int, saved: Int, lost: Int, reserves: Int
        let stateHash: String
        init(_ game: Lemmings3Runtime) {
            ticks = game.tick; saved = game.saved; lost = game.lost; reserves = game.reserve
            stateHash = L3Replay.stateHash(game)
        }
    }
    var version = 1
    let level: Int
    let levelSHA256: String
    let population: Int
    let initialStateHash: String
    let inputs: [Input]
    let expected: Outcome

    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func stateHash(_ game: Lemmings3Runtime) -> String {
        var hash = SHA256()
        func number(_ value: Int) {
            var value = Int64(value).littleEndian
            withUnsafeBytes(of: &value) { hash.update(data: Data($0)) }
        }
        func text(_ value: String) { let data = Data(value.utf8); number(data.count); hash.update(data: data) }
        let c = game.configuration
        for value in [c.width, c.height, c.total, c.releaseInterval, c.releaseDelay, c.timeLimit,
                      c.sourceLevelReference ?? -1, game.tick, game.released, game.saved, game.lost,
                      game.reserve, game.bonusSeconds, game.isComplete ? 1 : 0] { number(value) }
        for point in [c.entrance] + c.additionalEntrances + c.exits { number(point.x); number(point.y) }
        for grid in [game.attributes, c.backgroundAttributes] {
            number(grid.count)
            var bytes = Data(capacity: grid.count * 2)
            for value in grid { bytes.append(UInt8(truncatingIfNeeded: value)); bytes.append(UInt8(value >> 8)) }
            hash.update(data: bytes)
        }
        number(game.lemmings.count)
        for lem in game.lemmings {
            text(lem.state.rawValue); text(lem.workDirection.rawValue)
            for value in [lem.id, lem.x, lem.y, lem.direction, lem.age, lem.fall, lem.velocityY,
                          lem.tool?.rawValue ?? -1, lem.quantity, lem.swimTicks, lem.trapTicks,
                          lem.mobilityTool?.rawValue ?? -1, lem.mobilityTicks, lem.charmedBy ?? -1,
                          lem.charmTicks, lem.charmImmunity] { number(value) }
        }
        number(game.pickups.count)
        for box in game.pickups {
            for value in [box.id, box.tool.rawValue, box.x, box.y, box.quantity, box.ignoredBy ?? -1] { number(value) }
        }
        number(game.explosives.count)
        for bomb in game.explosives {
            for value in [bomb.id, bomb.tool.rawValue, bomb.x, bomb.y, bomb.velocityX, bomb.velocityY, bomb.age] { number(value) }
        }
        number(game.fireballs.count)
        for ball in game.fireballs { for value in [ball.x, ball.y, ball.direction, ball.age] { number(value) } }
        number(game.creatures.count)
        for creature in game.creatures {
            text(creature.digDirection.rawValue)
            for value in [creature.id, creature.kind.rawValue, creature.x, creature.y, creature.direction,
                          creature.alive ? 1 : 0, creature.target ?? -1, creature.cooldown, creature.age] { number(value) }
        }
        for trap in c.traps.sorted(by: { $0.id < $1.id }) { number(trap.id); number(game.trapFrame(id: trap.id)) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
    @discardableResult static func apply(_ input: Input, to game: inout Lemmings3Runtime) -> Bool {
        guard input.tick == game.tick, !game.isComplete else { return false }
        if input.action == "abort" {
            guard input.lemming == nil, input.direction == nil else { return false }
            game.abort(); return true
        }
        guard let id = input.lemming else { return false }
        if input.action == "use" {
            guard let raw = input.direction, let direction = Lemmings3Runtime.Direction(rawValue: raw) else { return false }
            return game.useTool(to: id, direction: direction)
        }
        guard input.direction == nil, let action = Lemmings3Runtime.Action(rawValue: input.action) else { return false }
        return game.assign(action, to: id)
    }
    func replay(from base: Lemmings3Runtime, levelData: Data) throws -> Lemmings3Runtime {
        guard version == 1, population == base.configuration.total,
              levelSHA256 == Self.digest(levelData), initialStateHash == Self.stateHash(base),
              inputs.count <= 100_000, inputs.allSatisfy({ (0..<30_000).contains($0.tick) }),
              zip(inputs, inputs.dropFirst()).allSatisfy({ $0.tick <= $1.tick }) else {
            throw SequelDataError.invalid("L3 replay identity, initial state or input order differs.")
        }
        var game = base, cursor = 0
        while !game.isComplete && game.tick < 30_000 {
            while cursor < inputs.count && inputs[cursor].tick == game.tick {
                guard Self.apply(inputs[cursor], to: &game) else {
                    throw SequelDataError.invalid("L3 replay input \(cursor) failed at tick \(game.tick).")
                }
                cursor += 1
            }
            game.step()
        }
        guard cursor == inputs.count, game.isComplete, game.saved > 0, Outcome(game) == expected else {
            throw SequelDataError.invalid("L3 replay did not consume every input and reproduce its winning outcome.")
        }
        return game
    }
}
