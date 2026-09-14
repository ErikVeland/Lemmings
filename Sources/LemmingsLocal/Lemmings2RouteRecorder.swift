import Foundation
import NxlvKit

/// Saves a played Lemmings 2 campaign level as a version 2 route, so the route solver can
/// start from it. The play window's run recovery log already holds every input with its tick.
enum Lemmings2RouteRecorder {
    static var folder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Ultimate Lemmings/Lemmings2Routes", isDirectory: true)
    }

    /// Converts logged inputs to route events. An assignment names its skill, not its panel slot.
    static func events(_ inputs: [L2RunRecovery.Input], skills: [Lemmings2Runtime.Skill]) -> [Lemmings2TimedEvent] {
        inputs.compactMap { input in
            let event: Lemmings2RouteEvent
            switch input.action {
            case let .assign(slot, lemming):
                guard skills.indices.contains(slot) else { return nil }
                event = .assign(skill: skills[slot].rawValue, lemming: lemming)
            case let .aim(x, y, held): event = .aim(x: x, y: y, held: held)
            case let .fan(x, y, active): event = .fan(x: x, y: y, active: active)
            case .releasePointer: event = .releasePointer
            case let .machine(x, y): event = .machine(x: x, y: y)
            case let .chain(x, y): event = .chain(x: x, y: y)
            case .nuke: event = .nuke
            }
            return Lemmings2TimedEvent(tick: input.tick, event: event)
        }
    }

    static func route(level: Lemmings2Level, game: Lemmings2Runtime, inputs: [L2RunRecovery.Input]) -> Lemmings2ReplayWitness {
        Lemmings2ReplayWitness(levelSHA256: level.fingerprint, population: game.configuration.total,
            expectedSaved: game.saved, expectedTicks: game.tick, events: events(inputs, skills: game.configuration.skills))
    }

    /// Replays the route once, then writes it. A route that replays to another result is kept as an
    /// unverified seed with its replayed result, and one that fails to replay is kept for inspection.
    @discardableResult
    static func save(_ route: Lemmings2ReplayWitness, tribe: String, number: Int, level: Lemmings2Level,
                     style: Lemmings2Style, masks: Lemmings2TerrainMasks, date: Date = Date(),
                     folder: URL = Lemmings2RouteRecorder.folder) throws -> URL {
        var written = route
        var extra: [String: Any] = [:]
        do {
            let replay = try route.outcome(level: level, style: style, masks: masks)
            if replay.saved != route.expectedSaved || replay.ticks != route.expectedTicks {
                extra = ["verified": false, "playedSaved": route.expectedSaved, "replayedSaved": replay.saved]
                written = Lemmings2ReplayWitness(levelSHA256: route.levelSHA256, population: route.population,
                    expectedSaved: replay.saved, expectedTicks: replay.ticks, events: route.events ?? [])
            }
        } catch {
            extra = ["verified": false, "playedSaved": route.expectedSaved]
        }
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(written)) as? [String: Any] ?? [:]
        object.merge(extra) { $1 }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = String(format: "%@-%02d-saved%d-%@.json", tribe, number, route.expectedSaved, formatter.string(from: date))
        let url = folder.appendingPathComponent(name)
        try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic)
        return url
    }
}
