import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let catalogue = try JSONDecoder().decode(LevelHintCatalogue.self,
    from: Data(contentsOf: root.appendingPathComponent("Resources/Hints/classic.json")))
require(catalogue.levels.count == 350, "Expected all official and conversion hint decks")
for (rank, count) in [("Lemmings Versus", 20), ("Oh No! More Lemmings Versus", 10), ("Mega Drive Sunsoft", 30)] {
    require(Set(catalogue.levels.filter { $0.rank == rank }.map(\.number)) == Set(1...count),
            "Incomplete conversion hints: \(rank)")
}
for rank in ["Fun", "Tricky", "Taxing", "Mayhem"] {
    require(Set(catalogue.levels.filter { $0.rank == rank }.map(\.number)) == Set(1...30),
        "Missing original hints for \(rank)")
}
require(Set(catalogue.levels.map(\.fingerprint)).count == catalogue.levels.count, "Ambiguous hint identities")
let ropeBridge = catalogue.levels.first { $0.rank == "Lemmings Versus" && $0.number == 18 }
require(ropeBridge?.opening.count == 1, "Off-canvas assignments must not create invalid map markers")
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
    let presentation = deck.presentation(at: 0)
    require(presentation.title == "Checked example route", "Checked route must name its evidence")
    require(!presentation.body.contains("No level-specific hints available."), "Checked route lost its availability")
    require(presentation.accessibilityText.contains(presentation.title), "Accessible route lost its evidence")
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

for (title, skills, chronicles) in [("Unmatched Classic", ["builder"], false),
                                    ("Lemmings 2", ["Hopper", "Fencer"], false),
                                    ("Lemmings 3", [], true)] {
    let deck = LevelHintDeck.practice(title: title, skills: skills, chronicles: chronicles)
    require(!deck.checked, "Generic coaching claimed a checked route")
    for index in deck.stages.indices {
        let presentation = deck.presentation(at: index)
        require(presentation.title == "General coaching", "Unmatched level must name general coaching")
        require(presentation.body.hasPrefix("No level-specific hints available.\n\n"), "Missing availability before coaching")
        require(presentation.progress.hasPrefix("COACHING"), "Generic coaching presented as bespoke hints")
        require(presentation.accessibilityText.contains("No level-specific hints available."), "Accessible coaching hid its availability")
        require(deck.stages[index].moves.isEmpty, "Generic coaching invented route markers")
    }
}
require(catalogue.level(for: catalogue.levels[0].fingerprint, engine: "stale") == nil,
    "A changed engine borrowed checked route hints")
let firstLesson = catalogue.levels.first { $0.rank == "Fun" && $0.number == 1 }!
require(firstLesson.deck.stages[0].body.contains("platform carrying the crowd"), "Exact first lesson lost obstacle reasoning")
let changedIdentity = LevelHintCatalogue.Level(fingerprint: "changed", title: firstLesson.title, rank: firstLesson.rank,
    number: firstLesson.number, width: firstLesson.width, height: firstLesson.height,
    opening: firstLesson.opening, skillOrder: firstLesson.skillOrder, rates: firstLesson.rates)
require(!changedIdentity.deck.stages[0].body.contains("platform carrying the crowd"),
    "A matching title borrowed another level's obstacle reasoning")

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
