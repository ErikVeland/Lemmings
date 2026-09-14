import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let catalogue = try JSONDecoder().decode(LevelHintCatalogue.self,
    from: Data(contentsOf: root.appendingPathComponent("Resources/Hints/classic.json")))
require(catalogue.levels.count == 248, "Expected the verified Classic-family catalogue")
for rank in ["Fun", "Tricky", "Taxing", "Mayhem"] {
    require(Set(catalogue.levels.filter { $0.rank == rank }.map(\.number)) == Set(1...30),
        "Missing original hints for \(rank)")
}
require(Set(catalogue.levels.map(\.fingerprint)).count == catalogue.levels.count, "Ambiguous hint identities")
for rank in ["Tame", "Crazy", "Wild", "Wicked", "Havoc", "Xmas", "Flurry", "Blizzard", "Frost", "Hail"] {
    require(catalogue.levels.contains { $0.rank == rank }, "Missing supported campaign rank \(rank)")
}
for level in catalogue.levels {
    require(catalogue.level(for: level.fingerprint, engine: catalogue.engineFingerprint) != nil,
        "Invalid checked hint markers for \(level.title)")
}
var rateContexts = 0
for level in catalogue.levels {
    let deck = level.deck
    require(deck.stages.count == 3, "Each level must retain three tiers")
    require(!deck.stages[0].body.contains("Release rate in this example:"), "Nudge reveals opening rate changes")
    require(!deck.stages[1].body.contains("Release rate in this example:"), "Approach reveals opening rate changes")
    require(deck.stages[2].moves == level.opening, "Map markers changed")
    if !level.rates.isEmpty {
        require(deck.stages[2].body.contains("Release rate in this example:"), "Missing rate context: \(level.title)")
        rateContexts += 1
    } else {
        require(!deck.stages[2].body.contains("Release rate in this example:"), "Invented rate changes")
    }
}

let fixture = LevelHintCatalogue.Level(fingerprint: "test", title: "Timing", rank: "Fun", number: 1,
    width: 100, height: 100,
    opening: [
        .init(skill: "builder", lemmingID: 0, x: 10, y: 10, tick: 20, facingLeft: false),
        .init(skill: "builder", lemmingID: 1, x: 20, y: 10, tick: 40, facingLeft: false),
        .init(skill: "builder", lemmingID: 2, x: 30, y: 10, tick: 40, facingLeft: false)
    ], skillOrder: ["builder"], rates: [
        .init(tick: 5, value: 50), .init(tick: 5, value: 89),
        .init(tick: 10, value: 99), .init(tick: 25, value: 99),
        .init(tick: 40, value: 50)
    ])
let body = fixture.deck.stages[2].body
require(body.contains("Before move 1: 89 → 99."), "Must retain effective rate order")
require(body.contains("Before move 2: 50."), "Must show changes at the next assignment tick")
require(!body.contains("Before move 3:"), "Same-tick moves must not repeat rate changes")
require(!body.contains("50 → 89"), "Same-tick intermediate rates do not affect spacing")
require(!body.contains("99 → 50"), "Unchanged rates must not repeat across moves")
require(body.contains("Their timing matters too."), "Must explain timing limits")
print("PASS: \(catalogue.levels.count) hint decks; \(rateContexts) release-rate contexts; event ordering and spoiler boundaries")
