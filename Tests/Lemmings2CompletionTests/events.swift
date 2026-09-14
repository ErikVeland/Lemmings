import Foundation
import NxlvKit

// Every recorded route must replay the same as version 1 and as converted events,
// and version 2 must stay as strict as version 1.
let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Sources/Ports/Lemm2")
let fixtures = URL(fileURLWithPath: "Tests/Lemmings2CompletionTests/Fixtures")
let campaign = try Lemmings2Campaign(root: root)
let masks = try Lemmings2TerrainMasks(root: root)

func fail(_ message: String) -> Never {
    print("FAIL \(message)")
    exit(1)
}

func style(_ level: Lemmings2Level) throws -> Lemmings2Style {
    try Lemmings2Style(data: Data(contentsOf: root.appendingPathComponent(
        "STYLES/\(Lemmings2Campaign.styleNames[level.style]).DAT")))
}

var checked = 0
var sample: (witness: Lemmings2ReplayWitness, level: Lemmings2Level)?
let files = try FileManager.default.contentsOfDirectory(at: fixtures, includingPropertiesForKeys: nil)
for url in files.sorted(by: { $0.path < $1.path }) where url.pathExtension == "json" {
    let witness = try JSONDecoder().decode(Lemmings2ReplayWitness.self, from: Data(contentsOf: url))
    guard let level = campaign.levels.first(where: { $0.fingerprint == witness.levelSHA256 }) else {
        fail("unknown level \(url.lastPathComponent)")
    }
    let original = try witness.run(level: level, style: try style(level), masks: masks)
    let converted = Lemmings2ReplayWitness(levelSHA256: witness.levelSHA256, population: witness.population,
        expectedSaved: witness.expectedSaved, expectedTicks: witness.expectedTicks, events: witness.timedEvents())
    let decoded = try JSONDecoder().decode(Lemmings2ReplayWitness.self, from: JSONEncoder().encode(converted))
    guard decoded.version == 2, decoded.inputs.isEmpty, decoded.pointers == nil, decoded.events == converted.events else {
        fail("version 2 did not round trip: \(url.lastPathComponent)")
    }
    let events = try decoded.run(level: level, style: try style(level), masks: masks)
    guard events.stateHash == original.stateHash, events.saved == original.saved, events.ticks == original.ticks else {
        fail("events replay differently from version 1: \(url.lastPathComponent)")
    }
    if sample == nil, witness.inputs.count > 2 { sample = (converted, level) }
    checked += 1
}
print("PASS \(checked) routes replay the same as version 1 and as converted events")

guard let sample else { fail("no sample route") }
let base = sample.witness, level = sample.level

func expectFailure(_ name: String, _ events: [Lemmings2TimedEvent]) throws {
    let witness = Lemmings2ReplayWitness(levelSHA256: base.levelSHA256, population: base.population,
        expectedSaved: base.expectedSaved, expectedTicks: base.expectedTicks, events: events)
    if (try? witness.run(level: level, style: try style(level), masks: masks)) != nil { fail("accepted \(name)") }
}

let baseEvents = base.timedEvents()
guard let first = baseEvents.firstIndex(where: { if case .assign = $0.event { return true } else { return false } }),
      case let .assign(_, lemming) = baseEvents[first].event else { fail("the sample route has no assignment") }
var refused = baseEvents
refused[first] = .init(tick: baseEvents[first].tick, event: .assign(skill: 999, lemming: lemming))
try expectFailure("an unknown skill", refused)
try expectFailure("an aim outside the viewport", [.init(tick: 0, event: .aim(x: -9999, y: -9999, held: true))] + baseEvents)
try expectFailure("out-of-order events", Array(baseEvents.reversed()))

// A lenient replay drops a refused event and reaches the same state as the route without it.
var game = try Lemmings2Runtime(level: level, style: try style(level), masks: masks, total: base.population)
var lenient = baseEvents
lenient.insert(.init(tick: baseEvents[first].tick, event: .assign(skill: 999, lemming: 0)), at: first)
var cursor = Lemmings2EventCursor()
var dropped = 0
while !game.isComplete {
    dropped += cursor.applyDroppingRefused(eventsAt: &game, events: &lenient)
    game.step()
}
let strict = try base.run(level: level, style: try style(level), masks: masks)
guard dropped == 1, lenient == baseEvents, game.stateFingerprint == strict.stateHash else {
    fail("the lenient replay left a trace of the dropped event")
}
print("PASS version 2 rejects refused, off-viewport and out-of-order events; a lenient replay drops without a trace")
