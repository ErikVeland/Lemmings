# Lemmings 2 Seeded Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chain Lemmings 2 tribes by searching from recorded routes, promoting better routes, and recording played routes in the game.

**Architecture:** Route file version 2 stores one ordered event list that the gate, the runtime and the solver apply through one cursor in NxlvKit. The solver's candidates carry the applied events plus the seed events still to come, and a lenient cursor drops refused events. A tribe runner chains levels through an injectable level solver, and a promotion step writes accepted routes into the gate directories. The app converts its existing run recovery log to version 2 routes on completion.

**Tech Stack:** Swift 6 with swiftc (no SwiftPM), `-warnings-as-errors`, zsh scripts, Python 3 for the manifest.

Spec: `docs/superpowers/specs/2026-09-14-lemmings2-seeded-search-design.md`.

## Global Constraints

- Swift 6, `swiftc -swift-version 6 -warnings-as-errors`, macOS 13 target. No SwiftPM.
- The solver must never change runtime physics to fit a route.
- A route counts only after two strict replays agree on state hash, saved count and ticks.
- Existing version 1 fixtures stay unchanged on disk.
- Beam width 64, location cell 8 pixels, re-fire window 150 ticks, budget 900 seconds of one core for each level.
- Depth limit: decision points on a replay of the seed (or a run without input), plus 40.
- Exit codes: 0 accepted route, 2 no route within the budget, 1 error.
- Prose follows the user's STE-flavored style. Stage files by path. End commits with `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
- Changing `Sources/NxlvKit` changes the Trolley engine fingerprint. Re-verify certificates and hints in the last task.

## File Structure

| File | Responsibility |
| --- | --- |
| `Sources/NxlvKit/Lemmings2ReplayWitness.swift` | Version 2 events, conversion from version 1, strict and lenient event cursor, replay without expected values |
| `Tools/Lemmings2Completion/main.swift` | Accept versions 1 and 2 |
| `Tests/Lemmings2CompletionTests/events.swift` | Every fixture replays the same as events; version 2 negative cases |
| `Scripts/verify-lemmings2-completion.sh` | Build and run the events test |
| `Tools/Lemmings2Solver/Scoring.swift` | Candidate holds events and an event cursor |
| `Tools/Lemmings2Solver/Actions.swift` | Seed edit actions and event recording |
| `Tools/Lemmings2Solver/Search.swift` | Seeded root, winners by saved count |
| `Tools/Lemmings2Solver/LevelRun.swift` | Solve one level with an optional seed and verify the written route |
| `Tools/Lemmings2Solver/Chain.swift` | Tribe chaining with backtracking over an injected level solver |
| `Tools/Lemmings2Solver/Promotion.swift` | Promotion rules into Fixtures and Chains |
| `Tools/Lemmings2Solver/main.swift` | `level` and `tribe` commands |
| `Scripts/solve-lemmings2-level.sh`, `Scripts/solve-lemmings2-tribes.sh` | Build and run |
| `Tests/Lemmings2SolverTests/main.swift` | Solver tests |
| `Sources/LemmingsLocal/Lemmings2RouteRecorder.swift` | Convert the recovery log to a version 2 route and save it |
| `Sources/LemmingsLocal/Lemmings2PlayWindow.swift`, `Sources/LemmingsLocal/main.swift` | Save on completion, menu item |
| `Tests/SequelMacArtworkAppTests/checks.swift` | Recording round trip |
| `Documentation/Lemmings2Completion/SeededSearch.md` | Run results |

---

### Task 1: Route file version 2 in NxlvKit and the gate

**Files:**
- Modify: `Sources/NxlvKit/Lemmings2ReplayWitness.swift`
- Modify: `Tools/Lemmings2Completion/main.swift:42`
- Create: `Tests/Lemmings2CompletionTests/events.swift`
- Modify: `Scripts/verify-lemmings2-completion.sh`

**Interfaces:**
- Produces:
  - `public enum Lemmings2RouteEvent: Codable, Sendable, Equatable { case assign(skill: Int, lemming: Int); case aim(x: Int, y: Int, held: Bool); case fan(x: Int, y: Int, active: Bool); case releasePointer; case machine(x: Int, y: Int); case chain(x: Int, y: Int); case nuke }`
  - `public struct Lemmings2TimedEvent: Codable, Sendable, Equatable { public let tick: Int; public let event: Lemmings2RouteEvent }`
  - `Lemmings2ReplayWitness.events: [Lemmings2TimedEvent]?`, `init(levelSHA256:population:expectedSaved:expectedTicks:events:)` (version 2)
  - `func timedEvents() -> [Lemmings2TimedEvent]` (version 1 converted, or the stored events)
  - `func outcome(level:style:masks:) throws -> Lemmings2WitnessOutcome` (replay to completion, no expected check)
  - `public struct Lemmings2EventCursor { public private(set) var next: Int; mutating func apply(eventsAt:events:) throws; mutating func applyDroppingRefused(eventsAt:events:) -> Int }`
  - `static func Lemmings2EventCursor.perform(_ event: Lemmings2RouteEvent, on game: inout Lemmings2Runtime) -> Bool`

- [ ] **Step 1: Write the failing events test**

Create `Tests/Lemmings2CompletionTests/events.swift`:

```swift
import Foundation
import NxlvKit

// Every recorded route must replay the same as version 1 and as converted events,
// and version 2 must stay as strict as version 1.
let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Sources/Ports/Lemm2")
let fixtures = URL(fileURLWithPath: "Tests/Lemmings2CompletionTests/Fixtures")
let campaign = try Lemmings2Campaign(root: root)
let masks = try Lemmings2TerrainMasks(root: root)
func fail(_ message: String) -> Never { print("FAIL \(message)"); exit(1) }
func style(_ level: Lemmings2Level) throws -> Lemmings2Style {
    try Lemmings2Style(data: Data(contentsOf: root.appendingPathComponent("STYLES/\(Lemmings2Campaign.styleNames[level.style]).DAT")))
}
var checked = 0
var sample: (Lemmings2ReplayWitness, Lemmings2Level)?
for url in try FileManager.default.contentsOfDirectory(at: fixtures, includingPropertiesForKeys: nil).sorted(by: { $0.path < $1.path })
    where url.pathExtension == "json" {
    let witness = try JSONDecoder().decode(Lemmings2ReplayWitness.self, from: Data(contentsOf: url))
    guard let level = campaign.levels.first(where: { $0.fingerprint == witness.levelSHA256 }) else { fail("unknown level \(url.lastPathComponent)") }
    let original = try witness.run(level: level, style: try style(level), masks: masks)
    let converted = Lemmings2ReplayWitness(levelSHA256: witness.levelSHA256, population: witness.population,
        expectedSaved: witness.expectedSaved, expectedTicks: witness.expectedTicks, events: witness.timedEvents())
    let encoded = try JSONEncoder().encode(converted)
    let decoded = try JSONDecoder().decode(Lemmings2ReplayWitness.self, from: encoded)
    guard decoded.version == 2, decoded.inputs.isEmpty, decoded.events == converted.events else { fail("version 2 did not round trip: \(url.lastPathComponent)") }
    let events = try decoded.run(level: level, style: try style(level), masks: masks)
    guard events.stateHash == original.stateHash, events.saved == original.saved, events.ticks == original.ticks else {
        fail("events replay differently from version 1: \(url.lastPathComponent)")
    }
    if sample == nil, witness.inputs.count > 2 { sample = (converted, level) }
    checked += 1
}
print("PASS \(checked) routes replay the same as version 1 and as events")

guard let (base, level) = sample else { fail("no sample route") }
func expectFailure(_ name: String, _ events: [Lemmings2TimedEvent]) throws {
    let witness = Lemmings2ReplayWitness(levelSHA256: base.levelSHA256, population: base.population,
        expectedSaved: base.expectedSaved, expectedTicks: base.expectedTicks, events: events)
    do { _ = try witness.run(level: level, style: try style(level), masks: masks); fail("accepted \(name)") } catch {}
}
var refused = base.timedEvents()
let first = refused.firstIndex { if case .assign = $0.event { return true }; return false }!
if case let .assign(_, lemming) = refused[first].event { refused[first] = .init(tick: refused[first].tick, event: .assign(skill: 999, lemming: lemming)) }
try expectFailure("an unknown skill", refused)
try expectFailure("an aim outside the viewport", [.init(tick: 0, event: .aim(x: -9999, y: -9999, held: true))] + base.timedEvents())
try expectFailure("out-of-order events", base.timedEvents().reversed())

// A lenient replay drops a refused event without a trace.
var game = try Lemmings2Runtime(level: level, style: try style(level), masks: masks, total: base.population)
var lenient = base.timedEvents()
lenient.insert(.init(tick: lenient[first].tick, event: .assign(skill: 999, lemming: 0)), at: first)
var cursor = Lemmings2EventCursor()
var dropped = 0
while !game.isComplete { dropped += cursor.applyDroppingRefused(eventsAt: &game, events: &lenient); game.step() }
guard dropped == 1, lenient == base.timedEvents(), game.stateFingerprint == (try base.outcome(level: level, style: try style(level), masks: masks)).stateHash else {
    fail("the lenient replay left a trace of the dropped event")
}
print("PASS version 2 rejects refused, off-viewport and out-of-order events; lenient replay drops without a trace")
```

- [ ] **Step 2: Add the test to the gate script and run it to verify it fails**

In `Scripts/verify-lemmings2-completion.sh`, after the `verify` build, add:

```zsh
swiftc -O -swift-version 6 -warnings-as-errors \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  Tests/Lemmings2CompletionTests/events.swift -o "$build_dir/events"
"$build_dir/events" "$data"
```

Run: `zsh Scripts/verify-lemmings2-completion.sh`
Expected: compile error, `Lemmings2TimedEvent` not found.

- [ ] **Step 3: Implement version 2 in `Lemmings2ReplayWitness.swift`**

Add after `Lemmings2InputCursor`:

```swift
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
    public init(tick: Int, event: Lemmings2RouteEvent) { self.tick = tick; self.event = event }
}

/// Applies version 2 events. The strict form throws on a refused event. The lenient form, which the
/// solver uses, removes a refused event from the list. A refusal is found before any runtime call,
/// so a strict replay of the kept list reaches the same state.
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
        case let .aim(x, y, held): game.setAim(x: x, y: y, held: held); return true
        case let .fan(x, y, active): game.setFan(x: x, y: y, active: active); return true
        case .releasePointer: game.releasePointerInput(); return true
        case let .machine(x, y): return game.moveMachine(x: x, y: y)
        case let .chain(x, y): return game.releaseChain(x: x, y: y)
        case .nuke:
            guard !game.isComplete, !game.isNuking else { return false }
            game.nuke(); return true
        }
    }

    public mutating func apply(eventsAt game: inout Lemmings2Runtime, events: [Lemmings2TimedEvent]) throws {
        while next < events.count && events[next].tick == game.tick {
            guard Self.perform(events[next].event, on: &game) else { throw Lemmings2WitnessError.rejectedInput(next) }
            next += 1
        }
    }

    /// Returns the number of events removed. An event for a tick already passed also counts as refused.
    public mutating func applyDroppingRefused(eventsAt game: inout Lemmings2Runtime, events: inout [Lemmings2TimedEvent]) -> Int {
        var dropped = 0
        while next < events.count && events[next].tick <= game.tick {
            if events[next].tick == game.tick && Self.perform(events[next].event, on: &game) { next += 1 }
            else { events.remove(at: next); dropped += 1 }
        }
        return dropped
    }
}
```

In `Lemmings2ReplayWitness`, add `public let events: [Lemmings2TimedEvent]?`, a version 2 initialiser, custom coding that omits `inputs` and `pointers` for version 2, and conversion:

```swift
    public init(levelSHA256: String, population: Int, expectedSaved: Int, expectedTicks: Int,
                events: [Lemmings2TimedEvent]) {
        version = 2
        self.levelSHA256 = levelSHA256; self.population = population
        self.expectedSaved = expectedSaved; self.expectedTicks = expectedTicks
        inputs = []; pointers = nil; self.events = events
    }

    private enum CodingKeys: String, CodingKey {
        case version, levelSHA256, population, expectedSaved, expectedTicks, inputs, pointers, events
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        levelSHA256 = try c.decode(String.self, forKey: .levelSHA256)
        population = try c.decode(Int.self, forKey: .population)
        expectedSaved = try c.decode(Int.self, forKey: .expectedSaved)
        expectedTicks = try c.decode(Int.self, forKey: .expectedTicks)
        inputs = try c.decodeIfPresent([Input].self, forKey: .inputs) ?? []
        pointers = try c.decodeIfPresent([Pointer].self, forKey: .pointers)
        events = try c.decodeIfPresent([Lemmings2TimedEvent].self, forKey: .events)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(levelSHA256, forKey: .levelSHA256)
        try c.encode(population, forKey: .population)
        try c.encode(expectedSaved, forKey: .expectedSaved)
        try c.encode(expectedTicks, forKey: .expectedTicks)
        if let events { try c.encode(events, forKey: .events) }
        else { try c.encode(inputs, forKey: .inputs); try c.encodeIfPresent(pointers, forKey: .pointers) }
    }

    /// The route as events. Version 1 converts exactly: a pointer sets the aim and the fan, and an
    /// assignment releases the fan, assigns, and holds the fan again when the last pointer held it.
    public func timedEvents() -> [Lemmings2TimedEvent] {
        if let events { return events }
        var result: [Lemmings2TimedEvent] = []
        let pointers = self.pointers ?? []
        var p = 0, i = 0
        var last: Pointer?
        while p < pointers.count || i < inputs.count {
            let tick = min(p < pointers.count ? pointers[p].tick : .max, i < inputs.count ? inputs[i].tick : .max)
            while p < pointers.count && pointers[p].tick == tick {
                let q = pointers[p]
                result.append(.init(tick: tick, event: .aim(x: q.fan ? q.fanX : q.x, y: q.fan ? q.fanY : q.y, held: !q.fan)))
                result.append(.init(tick: tick, event: .fan(x: q.fanX, y: q.fanY, active: q.fan)))
                last = q; p += 1
            }
            while i < inputs.count && inputs[i].tick == tick {
                result.append(.init(tick: tick, event: .fan(x: 0, y: 0, active: false)))
                result.append(.init(tick: tick, event: .assign(skill: inputs[i].skill, lemming: inputs[i].lemming)))
                if let last, last.fan { result.append(.init(tick: tick, event: .fan(x: last.fanX, y: last.fanY, active: true))) }
                i += 1
            }
        }
        return result
    }
```

Version 1 applies an assignment's fan release before checking the skill, so a refused assignment was already an error. The conversion therefore matches for every route that the gate accepts.

Split `run` into `outcome` and the expected check. In `outcome`, validate pointer coordinates (version 1) or event coordinates (version 2) against the same viewport rule, then replay with `Lemmings2InputCursor` for version 1 or `Lemmings2EventCursor.apply` for version 2, until `isComplete`. It throws `outOfOrderInput` when ticks are not ordered and `outcomeChanged` when not every input or event applied. `run` checks `game.tick <= expectedTicks` by requiring `outcome.ticks == expectedTicks`, `didWin` (saved > 0) and `saved == expectedSaved`.

```swift
    public func outcome(level: Lemmings2Level, style: Lemmings2Style,
                        masks: Lemmings2TerrainMasks) throws -> Lemmings2WitnessOutcome {
        guard levelSHA256 == level.fingerprint else { throw Lemmings2WitnessError.unknownLevel(levelSHA256) }
        var game = try Lemmings2Runtime(level: level, style: style, masks: masks, total: population)
        let xRange = level.minimumScreenX...(level.maximumScreenX + 319)
        let yRange = level.minimumScreenY...(level.maximumScreenY + 159)
        if let events {
            guard zip(events, events.dropFirst()).allSatisfy({ $0.tick <= $1.tick }) else { throw Lemmings2WitnessError.outOfOrderInput }
            for (index, timed) in events.enumerated() {
                switch timed.event {
                case let .aim(x, y, _), let .fan(x, y, _), let .machine(x, y), let .chain(x, y):
                    guard xRange.contains(x) || (x == 0 && y == 0), yRange.contains(y) || (x == 0 && y == 0) else {
                        throw Lemmings2WitnessError.pointerOutOfViewport(index)
                    }
                default: break
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
            medal: Lemmings2Campaign.medal(saved: game.saved, total: population, allowedLosses: level.allowedLossesForGold),
            stateHash: game.stateFingerprint)
    }

    public func run(level: Lemmings2Level, style: Lemmings2Style,
                    masks: Lemmings2TerrainMasks) throws -> Lemmings2WitnessOutcome {
        let result = try outcome(level: level, style: style, masks: masks)
        guard result.saved > 0, result.saved == expectedSaved, result.ticks == expectedTicks else {
            throw Lemmings2WitnessError.outcomeChanged(levelSHA256)
        }
        return result
    }
```

The version 1 loop previously stopped at `expectedTicks`. A route that completes later now fails on the tick check, as before. The version 2 viewport rule accepts `fan(0, 0, false)`, which the conversion writes.

- [ ] **Step 4: Accept version 2 in the gate**

In `Tools/Lemmings2Completion/main.swift`, replace `witness.version == 1` with:

```swift
guard witness.version == 1 || (witness.version == 2 && witness.events != nil && witness.inputs.isEmpty),
```

- [ ] **Step 5: Run the gate, its negative mode and the runtime suite**

Run: `zsh Scripts/verify-lemmings2-completion.sh && zsh Scripts/verify-lemmings2-completion.sh --negative && zsh Scripts/run-lemmings2-runtime-tests.sh && zsh Scripts/run-lemmings2-solver-tests.sh`
Expected: `PASS 64 routes replay the same as version 1 and as events`, the version 2 negative line, the gate's `Verified 64` summary, and every other suite passing. The solver suite still compiles because Task 2 has not changed it.

- [ ] **Step 6: Commit**

```bash
git add Sources/NxlvKit/Lemmings2ReplayWitness.swift Tools/Lemmings2Completion/main.swift Tests/Lemmings2CompletionTests/events.swift Scripts/verify-lemmings2-completion.sh
git commit -m "Add Lemmings 2 route version 2 with one ordered event list"
```

### Task 2: Solver candidates on events, seeded search and seed edits

**Files:**
- Modify: `Tools/Lemmings2Solver/Scoring.swift`, `Actions.swift`, `Search.swift`
- Create: `Tools/Lemmings2Solver/LevelRun.swift`
- Modify: `Tools/Lemmings2Solver/main.swift`, `Scripts/solve-lemmings2-level.sh`
- Modify: `Tests/Lemmings2SolverTests/main.swift`

**Interfaces:**
- Consumes: Task 1 `Lemmings2TimedEvent`, `Lemmings2EventCursor`, `timedEvents()`, `outcome(level:style:masks:)`.
- Produces:
  - `struct Candidate { var game; var cursor: Lemmings2EventCursor; var events: [Lemmings2TimedEvent]; var depth; var fingerprint; var detector; var decision; var applied: [Lemmings2TimedEvent] { Array(events.prefix(cursor.next)) } }`
  - `enum SolverAction { case wait; case assign(slot:lemming:); case aimedAssign(slot:lemming:x:y:); case retime(index: Int, tick: Int); case retarget(index: Int, lemming: Int); case drop(index: Int) }`
  - `func actions(in game:, candidates:, bounds:, pending: [Lemmings2TimedEvent], from next: Int) -> [SolverAction]`
  - `func apply(_ action: SolverAction, to candidate: inout Candidate)`
  - `func search(from start: Lemmings2Runtime, seed: [Lemmings2TimedEvent], bounds:, limits:) -> SearchReport` with `report.winners: [Candidate]` (best winner for each saved count, most saved first)
  - `func decisionCount(start: Lemmings2Runtime, seed: [Lemmings2TimedEvent], limits: SearchLimits) -> (points: Int, ticks: Int)`
  - `struct LevelResult { let status: Status (solved, unsolved); let witness: Lemmings2ReplayWitness?; let partial: Lemmings2ReplayWitness?; let winners: [Lemmings2ReplayWitness]; let summary: String }`
  - `func solveLevel(level:, style:, masks:, population:, seed: [Lemmings2TimedEvent], limits: SearchLimits) throws -> LevelResult` — throws `SolverError.replayMismatch(String)` when the double replay disagrees

- [ ] **Step 1: Write the failing seeded tests**

Replace `testScoring`'s candidate builder and `testActions`' record check with event forms, update `testPlantedRouteIsFound` to replay `best.applied` with `Lemmings2EventCursor`, and add:

```swift
func testSeededSearchRestoresPlantedRoute() throws {
    let game = try fixture(wall: true)
    let bounds = AimBounds(x: 0...(game.configuration.width - 1), y: 0...(game.configuration.height - 1))
    let basher = Lemmings2Runtime.Skill.basher.rawValue
    // The seed assigns the basher on tick 90, after the window closes, so it saves nothing.
    let seed = [Lemmings2TimedEvent(tick: 90, event: .assign(skill: basher, lemming: 0))]
    let report = search(from: game, seed: seed, bounds: bounds, limits: SearchLimits(beamWidth: 16, maxDepth: 6, budgetSeconds: 120))
    check(report.best?.game.saved == 3, "Seeded search saved \(report.best?.game.saved ?? 0) of 3")
    print("PASS seeded search restores the planted route from a late seed")
}
try testSeededSearchRestoresPlantedRoute()

func testSeedFollowsAfterAction() throws {
    var candidate = Candidate(game: try fixture(wall: true), events: [.init(tick: 200, event: .nuke)])
    while candidate.game.tick < 62 { candidate.game.step() }
    let basher = candidate.game.configuration.skills.firstIndex(of: .basher)!
    apply(.assign(slot: basher, lemming: 0), to: &candidate)
    check(candidate.events.count == 2 && candidate.events[0].tick == 62 && candidate.events[1].event == .nuke,
          "A new action was not inserted before the pending seed events")
    apply(.drop(index: 1), to: &candidate)
    check(candidate.events.count == 1, "Drop did not remove the pending event")
    print("PASS actions insert before pending seed events and edits change them")
}
try testSeedFollowsAfterAction()
```

- [ ] **Step 2: Run to verify failure**

Run: `zsh Scripts/run-lemmings2-solver-tests.sh`
Expected: compile errors for `seed:` and `Candidate(game:events:)`.

- [ ] **Step 3: Implement**

`Scoring.swift`:

```swift
struct Candidate: Sendable {
    var game: Lemmings2Runtime
    var cursor = Lemmings2EventCursor()
    /// Events that applied, then events still to come. A refused event is removed.
    var events: [Lemmings2TimedEvent]
    var depth = 0
    var fingerprint = ""
    var detector = DecisionDetector()
    var decision: Decision?
    init(game: Lemmings2Runtime, events: [Lemmings2TimedEvent] = [], detector: DecisionDetector = DecisionDetector()) {
        self.game = game; self.events = events; self.detector = detector
    }
    var applied: [Lemmings2TimedEvent] { Array(events.prefix(cursor.next)) }
}
```

`Score.init` uses `candidate.applied.count` for `inputs`. `mergeKey` uses the pointer state from the last applied `aim` or `fan` event, plus the pending events after `cursor.next`, so candidates that differ only in their future seed events do not merge:

```swift
private func mergeKey(_ candidate: Candidate) -> String {
    let pointer = candidate.applied.last(where: {
        if case .aim = $0.event { return true }; if case .fan = $0.event { return true }; return false
    }).map { "\($0.event)" } ?? "-"
    let pending = candidate.events.dropFirst(candidate.cursor.next).map { "\($0.tick):\($0.event)" }.joined(separator: ";")
    return candidate.fingerprint + "|" + pointer + "|" + pending
}
```

`Actions.swift` adds the edit cases, the pending `assign` edits and `apply`:

```swift
enum SolverAction: Sendable, Hashable {
    case wait
    case assign(slot: Int, lemming: Int)
    case aimedAssign(slot: Int, lemming: Int, x: Int, y: Int)
    case retime(index: Int, tick: Int)
    case retarget(index: Int, lemming: Int)
    case drop(index: Int)
}

func actions(in game: Lemmings2Runtime, candidates: [Int], bounds: AimBounds,
             pending events: [Lemmings2TimedEvent] = [], from next: Int = 0) -> [SolverAction] {
    // existing wait, assign and roper aim code, then:
    if let index = events.indices.dropFirst(next).first(where: {
        if case .assign = events[$0].event { return true }; return false
    }), case let .assign(_, lemming) = events[index].event {
        let tick = events[index].tick
        add(.retime(index: index, tick: tick + 8))
        if max(game.tick, tick - 8) != tick { add(.retime(index: index, tick: max(game.tick, tick - 8))) }
        for id in candidates where id != lemming { add(.retarget(index: index, lemming: id)) }
        add(.drop(index: index))
    }
    return result
}

/// The events that an assignment action adds on `tick`.
func events(for action: SolverAction, tick: Int, skills: [Lemmings2Runtime.Skill]) -> [Lemmings2TimedEvent] {
    switch action {
    case let .assign(slot, lemming):
        return [.init(tick: tick, event: .assign(skill: skills[slot].rawValue, lemming: lemming))]
    case let .aimedAssign(slot, lemming, x, y):
        return [.init(tick: tick, event: .aim(x: x, y: y, held: true)), .init(tick: tick, event: .fan(x: x, y: y, active: false)),
                .init(tick: tick, event: .assign(skill: skills[slot].rawValue, lemming: lemming))]
    case .wait, .retime, .retarget, .drop:
        return []
    }
}

/// Applies an action at the candidate's current tick. New events go before the pending events.
func apply(_ action: SolverAction, to candidate: inout Candidate) {
    let tick = candidate.game.tick, next = candidate.cursor.next
    func insertSorted(_ event: Lemmings2TimedEvent) {
        let index = candidate.events.indices.dropFirst(next).first { candidate.events[$0].tick > event.tick } ?? candidate.events.count
        candidate.events.insert(event, at: index)
    }
    switch action {
    case .wait: break
    case .assign, .aimedAssign:
        candidate.events.insert(contentsOf: events(for: action, tick: tick, skills: candidate.game.configuration.skills), at: next)
    case let .retime(index, newTick):
        let old = candidate.events.remove(at: index)
        insertSorted(.init(tick: newTick, event: old.event))
    case let .retarget(index, lemming):
        if case let .assign(skill, _) = candidate.events[index].event {
            candidate.events[index] = .init(tick: candidate.events[index].tick, event: .assign(skill: skill, lemming: lemming))
        }
    case let .drop(index):
        candidate.events.remove(at: index)
    }
}
```

A retime to the current tick must sit at `next`, not after events of the current tick that already applied. `insertSorted` searches only from `next`, so it does.

`Search.swift`: `advance` applies `applyDroppingRefused` and no longer throws. `search(from:seed:bounds:limits:)` builds the root with the seed events, considers `finish(root)` so the unchanged seed is a result, expands with `actions(... pending: node.events, from: node.cursor.next)` and `apply`. `consider` keeps `winners[saved]` as the best winning candidate for each saved count. Children that exist only as `wait` for the root still count toward `expanded`.

```swift
func advance(_ candidate: inout Candidate) -> Decision? {
    while !candidate.game.isComplete {
        var cursor = candidate.cursor
        _ = cursor.applyDroppingRefused(eventsAt: &candidate.game, events: &candidate.events)
        candidate.cursor = cursor
        candidate.game.step()
        if let decision = candidate.detector.update(TickObservation(candidate.game)) { return decision }
    }
    return nil
}

func finish(_ candidate: Candidate) -> Candidate {
    var tail = candidate
    while advance(&tail) != nil {}
    return tail
}

func decisionCount(start: Lemmings2Runtime, seed: [Lemmings2TimedEvent], limits: SearchLimits) -> (points: Int, ticks: Int) {
    var run = Candidate(game: start, events: seed, detector: DecisionDetector(cell: limits.cell, refire: limits.refire))
    var points = 0
    while advance(&run) != nil { points += 1 }
    return (points, run.game.tick)
}
```

`LevelRun.swift` holds the body of the old `main.swift` after level lookup: the depth from `decisionCount`, the search, writing the witness with `events: best.applied`, and the double replay check through `run`. It returns every winner as a witness, so Task 3 can backtrack.

```swift
import Foundation
import NxlvKit

enum SolverError: Error { case replayMismatch(String) }

struct LevelResult {
    enum Status { case solved, unsolved }
    let status: Status
    let witness: Lemmings2ReplayWitness?
    let partial: Lemmings2ReplayWitness?
    let winners: [Lemmings2ReplayWitness]
    let summary: String
}

func witness(_ candidate: Candidate, level: Lemmings2Level, population: Int) -> Lemmings2ReplayWitness {
    Lemmings2ReplayWitness(levelSHA256: level.fingerprint, population: population, expectedSaved: candidate.game.saved,
        expectedTicks: candidate.game.tick, events: candidate.applied)
}

func solveLevel(level: Lemmings2Level, style: Lemmings2Style, masks: Lemmings2TerrainMasks, population: Int,
                seed: [Lemmings2TimedEvent], limits base: SearchLimits, depth: Int? = nil) throws -> LevelResult {
    let start = try Lemmings2Runtime(level: level, style: style, masks: masks, total: population)
    var limits = base
    let passive = decisionCount(start: start, seed: seed, limits: limits)
    limits.maxDepth = depth ?? passive.points + 40
    let report = search(from: start, seed: seed, bounds: AimBounds(level: level), limits: limits)
    let density = String(format: "%.1f", Double(passive.points) * 100 / Double(max(1, passive.ticks)))
    let summary = "density \(density) per 100 ticks, decision points \(report.decisionPoints) (fallback \(report.fallbackPoints)), expanded \(report.expanded), \(Int(report.seconds)) s, depth \(limits.maxDepth)"
    let winners = report.winners.map { witness($0, level: level, population: population) }
    guard let best = report.best else {
        return LevelResult(status: .unsolved, witness: nil,
            partial: report.bestPartial.map { witness(finish($0), level: level, population: population) },
            winners: [], summary: summary)
    }
    let route = witness(best, level: level, population: population)
    let data = try JSONEncoder().encode(route)
    let written = try JSONDecoder().decode(Lemmings2ReplayWitness.self, from: data)
    let first = try written.run(level: level, style: style, masks: masks)
    let second = try written.run(level: level, style: style, masks: masks)
    guard first.stateHash == second.stateHash, first.saved == best.game.saved, first.ticks == best.game.tick else {
        throw SolverError.replayMismatch(level.fingerprint)
    }
    return LevelResult(status: .solved, witness: route, partial: nil, winners: winners, summary: summary)
}
```

`main.swift` gains `--seed <file>`. It reads the witness, requires `levelSHA256 == level.fingerprint` (exit 1 otherwise), passes `timedEvents()`, and prints the same `SOLVED` and `UNSOLVED` lines. `SOLVED` adds `from seed saved <n>` when seeded, where `n` is the seed's `expectedSaved`.

- [ ] **Step 4: Run solver tests**

Run: `zsh Scripts/run-lemmings2-solver-tests.sh`
Expected: every PASS line, including both new tests.

- [ ] **Step 5: Run the `classic-01` recovery test**

Add to `Tests/Lemmings2SolverTests/main.swift`, guarded by the game data path:

```swift
func testClassicRecovery() throws {
    let data = URL(fileURLWithPath: "Sources/Ports/Lemm2")
    guard FileManager.default.fileExists(atPath: data.appendingPathComponent("LEVELS/LEVEL000.DAT").path) else {
        print("SKIP classic-01 recovery: game data not present"); return
    }
    let campaign = try Lemmings2Campaign(root: data)
    let masks = try Lemmings2TerrainMasks(root: data)
    let fixture = try JSONDecoder().decode(Lemmings2ReplayWitness.self,
        from: Data(contentsOf: URL(fileURLWithPath: "Tests/Lemmings2CompletionTests/Fixtures/classic-01.json")))
    let level = campaign.levels.first { $0.fingerprint == fixture.levelSHA256 }!
    let style = try Lemmings2Style(data: Data(contentsOf: data.appendingPathComponent("STYLES/\(Lemmings2Campaign.styleNames[level.style]).DAT")))
    let events = fixture.timedEvents()
    // Remove each assignment in turn and keep the first removal that loses lemmings.
    var damaged: [Lemmings2TimedEvent]?
    var damagedSaved = 0
    for index in events.indices {
        guard case .assign = events[index].event else { continue }
        var trial = events; trial.remove(at: index)
        let outcome = try? Lemmings2ReplayWitness(levelSHA256: fixture.levelSHA256, population: 60, expectedSaved: 1,
            expectedTicks: 1, events: trial).outcome(level: level, style: style, masks: masks)
        // A strict replay can refuse a later assignment. Replay leniently for the saved count.
        var game = try Lemmings2Runtime(level: level, style: style, masks: masks, total: 60)
        var cursor = Lemmings2EventCursor()
        while !game.isComplete { _ = cursor.applyDroppingRefused(eventsAt: &game, events: &trial); game.step() }
        _ = outcome
        if game.saved < 60 { damaged = trial; damagedSaved = game.saved; break }
    }
    guard let damaged else { check(false, "No single removal damaged classic-01"); return }
    let result = try solveLevel(level: level, style: style, masks: masks, population: 60, seed: damaged, limits: SearchLimits())
    check(result.witness?.expectedSaved == 60, "Seeded search recovered \(result.witness?.expectedSaved ?? 0) of 60 from a seed saving \(damagedSaved)")
    print("PASS classic-01 recovery: \(damagedSaved) of 60 seed restored to 60 of 60; \(result.summary)")
}
try testClassicRecovery()
```

Run: `zsh Scripts/run-lemmings2-solver-tests.sh`
Expected: `PASS classic-01 recovery`. If it fails, stop and debug the search before any real run.

- [ ] **Step 6: Run the gate and commit**

Run: `zsh Scripts/verify-lemmings2-completion.sh`
Expected: pass.

```bash
git add Tools/Lemmings2Solver Tests/Lemmings2SolverTests/main.swift Scripts/solve-lemmings2-level.sh
git commit -m "Search Lemmings 2 routes from a seed and follow its remaining events"
```

### Task 3: Tribe chaining and promotion

**Files:**
- Create: `Tools/Lemmings2Solver/Chain.swift`, `Tools/Lemmings2Solver/Promotion.swift`
- Modify: `Tools/Lemmings2Solver/main.swift`
- Create: `Scripts/solve-lemmings2-tribes.sh`
- Modify: `Tests/Lemmings2SolverTests/main.swift`

**Interfaces:**
- Consumes: `solveLevel`, `LevelResult`.
- Produces:
  - `struct ChainLevel: Codable { let number: Int; let population: Int; let saved: Int?; let seedSource: String; let seconds: Double }`
  - `struct ChainReport: Codable { let tribe: String; var levels: [ChainLevel]; var brokeAt: Int?; var arkReady: Bool }`
  - `func runChain(tribe: String, solve: (Int, Int) throws -> LevelResult, accept: (Int, Lemmings2ReplayWitness) throws -> Void) rethrows -> ChainReport`
  - `enum PromotionOutcome: Equatable { case fixture, chain, kept(String) }`
  - `func promote(_ route: Lemmings2ReplayWitness, name: String, fixtures: URL, chains: URL) throws -> PromotionOutcome`
  - `func seeds(for name: String, level: Lemmings2Level, population: Int, fixtures: URL, chains: URL, extra: URL?) -> (events: [Lemmings2TimedEvent], source: String)`

- [ ] **Step 1: Write failing tests**

```swift
func route(_ saved: Int, population: Int) -> Lemmings2ReplayWitness {
    Lemmings2ReplayWitness(levelSHA256: "x", population: population, expectedSaved: saved, expectedTicks: 10, events: [])
}
func result(_ winners: [Int], population: Int) -> LevelResult {
    let routes = winners.map { route($0, population: population) }
    return LevelResult(status: routes.isEmpty ? .unsolved : .solved, witness: routes.first, partial: nil, winners: routes, summary: "")
}

func testChainPassesPopulationAndBacktracks() throws {
    var calls: [(Int, Int)] = []
    // Level 2 wins with 30 or 25 lemmings. Level 3 wins only with 25, so level 2 must backtrack to 25.
    let report = runChain(tribe: "classic", solve: { number, population in
        calls.append((number, population))
        switch number {
        case 1: return result([30, 25], population: population)
        case 2: return population == 30 || population == 25 ? result([population], population: population) : result([], population: population)
        case 3: return population == 25 ? result([20], population: population) : result([], population: population)
        default: return result([], population: population)
        }
    }, accept: { _, _ in })
    check(calls.prefix(3).map { $0.1 } == [60, 30, 30], "Population did not pass forward: \(calls)")
    check(report.levels.count >= 3 && report.levels[2].saved == 20, "Backtracking did not reach level 3: \(report.levels)")
    check(report.brokeAt == 4, "The chain did not break at level 4")
    print("PASS chain passes population forward, backtracks one level and records the break")
}
try testChainPassesPopulationAndBacktracks()

func testPromotionRules() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("l2-promote-\(UUID())")
    let fixtures = dir.appendingPathComponent("Fixtures"), chains = dir.appendingPathComponent("Chains")
    try FileManager.default.createDirectory(at: fixtures, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: chains, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    check(try promote(route(10, population: 60), name: "classic-02", fixtures: fixtures, chains: chains) == .fixture, "A new 60 route was not promoted")
    check(try promote(route(5, population: 60), name: "classic-02", fixtures: fixtures, chains: chains) != .fixture, "A worse 60 route replaced a better one")
    check(try promote(route(4, population: 30), name: "classic-02", fixtures: fixtures, chains: chains) == .chain, "A carry-over route was not promoted")
    check(try promote(route(3, population: 30), name: "classic-02", fixtures: fixtures, chains: chains) != .chain, "A worse carry-over route replaced a better one")
    check(try promote(route(2, population: 20), name: "classic-02", fixtures: fixtures, chains: chains) == .chain, "A carry-over route at a new population was not promoted")
    print("PASS promotion never replaces a better route")
}
try testPromotionRules()
```

- [ ] **Step 2: Run to verify failure**

Run: `zsh Scripts/run-lemmings2-solver-tests.sh`
Expected: compile error for `runChain`.

- [ ] **Step 3: Implement `Chain.swift`**

```swift
import Foundation
import NxlvKit

struct ChainLevel: Codable, Sendable {
    let number: Int, population: Int, saved: Int?, seedSource: String, seconds: Double
}

struct ChainReport: Codable, Sendable {
    let tribe: String
    var levels: [ChainLevel] = []
    var brokeAt: Int?
    var arkReady = false
}

/// Solves levels 1 to 10 in order. Each level starts with the saved count of the chosen route before it.
/// When a level cannot pass, the previous level's other winners are tried, most saved first, up to three.
func runChain(tribe: String, seedSource: (Int, Int) -> String = { _, _ in "" },
              solve: (Int, Int) throws -> LevelResult,
              accept: (Int, Lemmings2ReplayWitness) throws -> Void) rethrows -> ChainReport {
    var report = ChainReport(tribe: tribe)
    var population = 60
    var previous: LevelResult?
    var number = 1
    while number <= 10 {
        let started = Date()
        var result = try solve(number, population)
        var level = ChainLevel(number: number, population: population, saved: result.witness?.expectedSaved,
                               seedSource: seedSource(number, population), seconds: Date().timeIntervalSince(started))
        if result.witness == nil, number > 1, let before = previous {
            for alternative in before.winners.filter({ $0.expectedSaved != population }).prefix(3) {
                let retry = try solve(number, alternative.expectedSaved)
                if retry.witness != nil {
                    report.levels[report.levels.count - 1] = ChainLevel(number: number - 1, population: alternative.population,
                        saved: alternative.expectedSaved, seedSource: report.levels.last!.seedSource, seconds: report.levels.last!.seconds)
                    try accept(number - 1, alternative)
                    population = alternative.expectedSaved
                    result = retry
                    level = ChainLevel(number: number, population: population, saved: retry.witness?.expectedSaved,
                                       seedSource: seedSource(number, population), seconds: Date().timeIntervalSince(started))
                    break
                }
            }
        }
        report.levels.append(level)
        guard let route = result.witness else { report.brokeAt = number; return report }
        try accept(number, route)
        population = route.expectedSaved
        previous = result
        number += 1
    }
    report.arkReady = population >= 30
    return report
}
```

The test sets level 1 winners [30, 25]. Level 2 passes with 30. Level 3 fails with 30, so the chain retries level 3 with level 2's other winners. Level 2's only winner saves 30, so the test's level 2 must return winners for both populations. Adjust the test's level 2 closure to `result([30, 25].filter { $0 <= population }, population: population)` so that level 2 at 30 offers a 25 winner, and level 3 then passes with 25.

- [ ] **Step 4: Implement `Promotion.swift`**

```swift
import Foundation
import NxlvKit

enum PromotionOutcome: Equatable { case fixture, chain, kept(String) }

/// Writes an accepted route into the gate's directories. Never replaces a route that saves more.
func promote(_ route: Lemmings2ReplayWitness, name: String, fixtures: URL, chains: URL) throws -> PromotionOutcome {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    func existing(_ url: URL) -> Lemmings2ReplayWitness? {
        (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(Lemmings2ReplayWitness.self, from: $0) }
    }
    let fixture = fixtures.appendingPathComponent(name + ".json")
    if route.population == 60 {
        if let old = existing(fixture), old.population == 60, old.expectedSaved >= route.expectedSaved {
            return .kept("fixture saves \(old.expectedSaved)")
        }
        try encoder.encode(route).write(to: fixture)
        return .fixture
    }
    if let old = existing(fixture), old.population == route.population {
        if old.expectedSaved >= route.expectedSaved { return .kept("fixture at \(old.population) saves \(old.expectedSaved)") }
        try encoder.encode(route).write(to: fixture)
        return .fixture
    }
    let chain = chains.appendingPathComponent(name + ".json")
    if let old = existing(chain), old.population == route.population, old.expectedSaved >= route.expectedSaved {
        return .kept("chain route saves \(old.expectedSaved)")
    }
    try encoder.encode(route).write(to: chain)
    return .chain
}
```

The gate forbids a chain route at the same population as its fixture, and a chain route without a fixture. `promote` writes a non-60 route to Fixtures when the fixture already has that population, and a `tribe` run promotes only levels whose fixture exists or whose population is 60. A level without a fixture and a non-60 route is kept as a candidate.

- [ ] **Step 5: Implement seed choice and the `tribe` command in `main.swift`**

```swift
/// The seed for a level: a route at the starting population first, then the best route at any population.
func seeds(for name: String, level: Lemmings2Level, population: Int, fixtures: URL, chains: URL, extra: URL?)
    -> (events: [Lemmings2TimedEvent], source: String) {
    var found: [(Lemmings2ReplayWitness, String)] = []
    func read(_ url: URL, _ label: String) {
        guard let data = try? Data(contentsOf: url), let witness = try? JSONDecoder().decode(Lemmings2ReplayWitness.self, from: data),
              witness.levelSHA256 == level.fingerprint else { return }
        found.append((witness, label))
    }
    read(chains.appendingPathComponent(name + ".json"), "chain")
    read(fixtures.appendingPathComponent(name + ".json"), "fixture")
    if let extra, let files = try? FileManager.default.contentsOfDirectory(at: extra, includingPropertiesForKeys: nil) {
        for file in files.sorted(by: { $0.path < $1.path }) where file.pathExtension == "json" { read(file, "recorded " + file.lastPathComponent) }
    }
    if let exact = found.first(where: { $0.0.population == population }) { return (exact.0.timedEvents(), exact.1) }
    if let best = found.max(by: { $0.0.expectedSaved < $1.0.expectedSaved }) { return (best.0.timedEvents(), best.1) }
    return ([], "none")
}
```

`main.swift` dispatch: `solver level <data> <tribe-NN> [--seed FILE] [--population N] [--promote] ...` and `solver tribe <data> <tribe> [--seeds DIR] [--budget S] [--promote] [--out DIR]`. The level command's `--promote` calls `promote` on the accepted route. The tribe command calls `runChain` with a `solve` closure that picks seeds with `seeds(for:)`, calls `solveLevel`, writes the candidate or partial file to `--out`, and prints `SOLVED` or `UNSOLVED` lines; `accept` writes the route to `--out` and, with `--promote`, calls `promote`. It writes `<out>/tribes/<tribe>.json` with the `ChainReport` and exits 0 when the chain reaches level 10, 2 otherwise. After a promoting run, it prints `Run python3 Tools/Lemmings2Completion/report.py and the completion gate.`

`Scripts/solve-lemmings2-level.sh` passes `level` before its arguments. `Scripts/solve-lemmings2-tribes.sh` builds once, then runs one background process for each named tribe (all twelve by default), each with its log in `.build/l2-solver/tribes/<tribe>.log`, and waits for all of them.

```zsh
#!/bin/zsh
# Builds the Lemmings 2 route solver and runs one tribe chain for each named tribe, in parallel.
# Usage: zsh Scripts/solve-lemmings2-tribes.sh [tribe ...] [-- solver options]
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/l2-solver"
cd "$project_dir"
data="$project_dir/Sources/Ports/Lemm2"
[[ -f "$data/LEVELS/LEVEL000.DAT" ]] || data="$project_dir/.build/local/Ultimate Lemmings.app/Contents/Resources/Ports/Lemm2"
[[ -f "$data/LEVELS/LEVEL000.DAT" ]] || { echo "Lemmings 2 data not found." >&2; exit 1; }
tribes=()
while (( $# )) && [[ "$1" != -- ]]; do tribes+=("$1"); shift; done
[[ "${1:-}" == -- ]] && shift
(( ${#tribes} )) || tribes=(classic beach cavelem circus egyptian highland medieval outdoor polar shadow space sports)
mkdir -p "$build_dir/modules" "$build_dir/tribes"
swiftc -O -swift-version 6 -warnings-as-errors -parse-as-library \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" Sources/NxlvKit/*.swift
swiftc -O -swift-version 6 -warnings-as-errors \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  Tools/Lemmings2Solver/*.swift -o "$build_dir/solver"
pids=()
for tribe in "${tribes[@]}"; do
  "$build_dir/solver" tribe "$data" "$tribe" "$@" > "$build_dir/tribes/$tribe.log" 2>&1 &
  pids+=($!)
done
status=0
for pid in "${pids[@]}"; do wait "$pid" || status=1; done
for tribe in "${tribes[@]}"; do tail -n 1 "$build_dir/tribes/$tribe.log"; done
exit $status
```

A chain that breaks exits 2, so the script reports status 1 when any tribe breaks. That is a result, not a build failure.

- [ ] **Step 6: Run tests, then a one-level smoke run**

Run: `zsh Scripts/run-lemmings2-solver-tests.sh`
Expected: all PASS.

Run: `zsh Scripts/solve-lemmings2-level.sh egyptian-01 --seed Tests/Lemmings2CompletionTests/Fixtures/egyptian-01.json --budget 60`
Expected: `SOLVED egyptian-01: saved n of 60 ... from seed saved m` with `n >= m`.

- [ ] **Step 7: Commit**

```bash
git add Tools/Lemmings2Solver Tests/Lemmings2SolverTests/main.swift Scripts/solve-lemmings2-level.sh Scripts/solve-lemmings2-tribes.sh
git commit -m "Chain Lemmings 2 tribes through seeded search and promote better routes"
```

### Task 4: Record routes in the game

**Files:**
- Create: `Sources/LemmingsLocal/Lemmings2RouteRecorder.swift`
- Modify: `Sources/LemmingsLocal/Lemmings2PlayWindow.swift` (`finishIfComplete`)
- Modify: `Sources/LemmingsLocal/main.swift` (menu)
- Modify: `Scripts/run-sequel-mac-artwork-tests.sh` only if the new file needs listing (it compiles `Sources/LemmingsLocal/*.swift`, so it does not)
- Modify: `Tests/SequelMacArtworkAppTests/checks.swift`

**Interfaces:**
- Consumes: Task 1 version 2 witness, `outcome(level:style:masks:)`.
- Produces:
  - `enum Lemmings2RouteRecorder { static var folder: URL; static func events(_ inputs: [L2RunRecovery.Input], skills: [Lemmings2Runtime.Skill]) -> [Lemmings2TimedEvent]; static func route(level: Lemmings2Level, population: Int, game: Lemmings2Runtime, inputs: [L2RunRecovery.Input]) -> Lemmings2ReplayWitness; static func save(_ route:, tribe: String, number: Int, level:, style:, masks:, date: Date) throws -> URL }`

- [ ] **Step 1: Write the failing app check**

In `Tests/SequelMacArtworkAppTests/checks.swift`, add an extension on `Lemmings2PlayWindow` with `checkRouteRecording()`: start the current campaign level, step 70 ticks, assign the first assignable skill to the first active lemming through `performRecoveryInput`, start a nuke and undo it through the existing nuke path, run the level to completion by stepping `game`, then call `Lemmings2RouteRecorder.route(level:population:game:inputs:)` with `recoveryInputs`. Replay it with `outcome(level:style:masks:)` and require the saved count and ticks of the played game. Also require `Lemmings2RouteRecorder.events` to map an `.assign(slot: 0, lemming: 3)` input to `.assign(skill: configuration.skills[0].rawValue, lemming: 3)`. Print `PASS L2 route recording replays to the played result`. Call it after `checkPracticeRecovery`.

The test calls private members, as the existing recovery checks do. Change `performRecoveryInput` from `private` to `fileprivate` only if the combined `main.swift` compilation requires it; the script concatenates the play window and the checks into one file, so `private` members stay reachable from an extension in that file.

- [ ] **Step 2: Run to verify failure**

Run: `zsh Scripts/run-sequel-mac-artwork-tests.sh`
Expected: compile error, `Lemmings2RouteRecorder` not found.

- [ ] **Step 3: Implement the recorder**

```swift
import Foundation
import NxlvKit

/// Saves a played Lemmings 2 campaign level as a version 2 route, so the solver can start from it.
enum Lemmings2RouteRecorder {
    static var folder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Ultimate Lemmings/Lemmings2Routes", isDirectory: true)
    }

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

    static func route(level: Lemmings2Level, population: Int, game: Lemmings2Runtime, inputs: [L2RunRecovery.Input]) -> Lemmings2ReplayWitness {
        Lemmings2ReplayWitness(levelSHA256: level.fingerprint, population: population, expectedSaved: game.saved,
            expectedTicks: game.tick, events: events(inputs, skills: game.configuration.skills))
    }

    /// Replays the route once, then writes it. A route that replays differently is kept as an unverified seed.
    static func save(_ route: Lemmings2ReplayWitness, tribe: String, number: Int, level: Lemmings2Level,
                     style: Lemmings2Style, masks: Lemmings2TerrainMasks, date: Date = Date()) throws -> URL {
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
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(written)) as! [String: Any]
        object.merge(extra) { $1 }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyyMMdd-HHmmss"
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(String(format: "%@-%02d-saved%d-%@.json", tribe, number, route.expectedSaved, formatter.string(from: date)))
        try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]).write(to: url)
        return url
    }
}
```

- [ ] **Step 4: Save on completion**

In `Lemmings2PlayWindow.finishIfComplete`, inside `if game.isComplete`, before `show(.results)`:

```swift
if practiceLevel == nil, game.saved > 0, let style {
    let route = Lemmings2RouteRecorder.route(level: level, population: game.configuration.total, game: game, inputs: recoveryInputs)
    let tribe = level.style == 2 ? "cavelem" : Lemmings2Campaign.tribeNames[level.style].lowercased()
    let number = campaign.progress.level + 1, level = self.level, masks = self.masks
    DispatchQueue.global(qos: .utility).async {
        _ = try? Lemmings2RouteRecorder.save(route, tribe: tribe, number: number, level: level, style: style, masks: masks)
    }
}
```

This must run before `campaign.record(game)`, which can advance the level. Capture `level` and the number first.

- [ ] **Step 5: Menu item**

In `Sources/LemmingsLocal/main.swift`, after the `nativeL2` item:

```swift
    let routes = NSMenuItem(title: "Show Recorded Routes", action: #selector(showRecordedRoutes), keyEquivalent: "")
    routes.target = self
    appMenu.addItem(routes)
```

and the action:

```swift
  @objc private func showRecordedRoutes() {
    let folder = Lemmings2RouteRecorder.folder
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    NSWorkspace.shared.activateFileViewerSelecting([folder])
  }
```

- [ ] **Step 6: Run the app checks and the app build**

Run: `zsh Scripts/run-sequel-mac-artwork-tests.sh && zsh Scripts/build-local-app.sh`
Expected: `PASS L2 route recording replays to the played result` and a clean build.

- [ ] **Step 7: Commit**

```bash
git add Sources/LemmingsLocal/Lemmings2RouteRecorder.swift Sources/LemmingsLocal/Lemmings2PlayWindow.swift Sources/LemmingsLocal/main.swift Tests/SequelMacArtworkAppTests/checks.swift
git commit -m "Record played Lemmings 2 campaign levels as seed routes"
```

### Task 5: Run the tribes, promote, and record the results

**Files:**
- Modify: `Tests/Lemmings2CompletionTests/Fixtures/*.json`, `Tests/Lemmings2CompletionTests/Chains/*.json` (promotion only)
- Modify: `Documentation/Lemmings2Completion/evidence.json` (regenerated)
- Create: `Documentation/Lemmings2Completion/SeededSearch.md`

- [ ] **Step 1: Egyptian first**

Run: `zsh Scripts/solve-lemmings2-tribes.sh egyptian -- --promote`
Expected: `.build/l2-solver/tribes/egyptian.json` and promotion lines.

- [ ] **Step 2: Regenerate the manifest and run the gate**

Run: `python3 Tools/Lemmings2Completion/report.py && zsh Scripts/verify-lemmings2-completion.sh`
Expected: the gate passes, and `chainedLevels.egyptian` is at least 8.

- [ ] **Step 3: The other eleven tribes in parallel**

Run in the background: `zsh Scripts/solve-lemmings2-tribes.sh classic beach cavelem circus highland medieval outdoor polar shadow space sports -- --promote`
Then Step 2 again.

- [ ] **Step 4: Write `SeededSearch.md`**

A table for each tribe: levels chained before and after, the break level, whether level 10 saves 30, and for each level the population, saved count, seed source and time. State the number of one-lemming routes before and after, taken from the manifest's `quality.bareSurvivals`.

- [ ] **Step 5: Commit**

```bash
git add Tests/Lemmings2CompletionTests/Fixtures Tests/Lemmings2CompletionTests/Chains Documentation/Lemmings2Completion/evidence.json Documentation/Lemmings2Completion/SeededSearch.md
git commit -m "Promote seeded Lemmings 2 routes and record the tribe runs"
```

### Task 6: Re-verify engine evidence and hand over

**Files:**
- Modify: `Resources/Trolley/verified-maxima.json`, `Resources/Trolley/engine-fingerprint.txt` (via the script), `Resources/Hints/classic.json` (regenerated)
- Modify: `Documentation/WorkCoordination.md`

- [ ] **Step 1: Re-certify**

Run: `zsh Scripts/verify-trolley-maxima.sh && zsh Scripts/generate-level-hints.sh && python3 Tools/TrolleyVerification/catalogue.py check`
Expected: every certificate re-verified with no outcome change, and the catalogue check passes.

- [ ] **Step 2: Full regression**

Run: `zsh Scripts/run-lemmings2-runtime-tests.sh && zsh Scripts/verify-lemmings2-completion.sh && zsh Scripts/verify-lemmings2-completion.sh --negative && zsh Scripts/run-lemmings2-solver-tests.sh && zsh Scripts/run-playfield-draw-tests.sh`
Expected: all pass.

- [ ] **Step 3: Hand over to Codex in `WorkCoordination.md`**

Add a dated entry: the new route version, the re-verified certificates, the new scripts, the recorded routes folder and menu item, and the tribe results.

- [ ] **Step 4: Commit**

```bash
git add Resources/Trolley Resources/Hints Documentation/WorkCoordination.md
git commit -m "Re-verify rescue proofs and hints for the route version 2 engine change"
```
