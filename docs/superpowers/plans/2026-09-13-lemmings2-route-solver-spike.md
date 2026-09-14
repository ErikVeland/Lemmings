# Lemmings 2 Route Solver Spike Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build phase 1 of the Lemmings 2 route solver and run the go or no-go spike on four levels.

**Architecture:** A crowd beam search branches only at decision points that a detector reads from the running game. Candidates are ranked by saved lemmings, then losses, then crowd distance. The solver applies inputs through the same `Lemmings2InputCursor` that the replay witness uses, so a found route replays exactly. A route counts only after the witness replays the written file twice.

**Tech Stack:** Swift 6 compiled with `swiftc` (no SwiftPM), zsh scripts, Python 3 for the spike report. macOS 13 target.

**Spec:** `docs/superpowers/specs/2026-09-13-lemmings2-route-solver-design.md`, including its "Amendments during planning" section.

## Global Constraints

- Compile with `-swift-version 6`. Tool and test scripts add `-warnings-as-errors`. A warning fails the build.
- Never change runtime physics in `Sources/NxlvKit/Lemmings2Runtime.swift` to make a route work.
- Phase 1 never writes to `Tests/Lemmings2CompletionTests/Fixtures/`. Candidates go to `.build/l2-solver/candidates/`.
- A route counts only after `Lemmings2ReplayWitness.run` replays the written file twice with a matching state hash, saved count and tick count.
- The search is deterministic. The same level and limits give the same route.
- Do not move `fixture(wall:)` or `syntheticMasks()` out of `Tests/Lemmings2RuntimeTests/main.swift`. `Tools/ReleaseReadiness/audit.py` compiles each suite from its `main.swift` alone.
- Do not edit `Tools/ReleaseReadiness/audit.py`. Codex owns release integration.
- Work in a worktree on a feature branch. The worktree links `Sources/Ports`, `Sources/Music` and `Content` to the main checkout. Stage files by path. Never run `git add -A`, because the `.gitignore` patterns end in `/` and do not exclude these links.
- A level without a found route is "unsolved by search". Never describe it as broken.
- Write prose in the STE-flavored style from `~/.claude/skills/ste-writing/SKILL.md`.

## File Structure

| File | Action | Responsibility |
| --- | --- | --- |
| `Sources/NxlvKit/Lemmings2ReplayWitness.swift` | Modify | Make the witness `Codable` with public initialisers. Add `Lemmings2InputCursor`, the shared per-tick input application. |
| `Tests/Lemmings2RuntimeTests/main.swift` | Modify | Add an encode, decode and replay round trip for all 64 routes. |
| `Tools/Lemmings2Solver/DecisionPoints.swift` | Create | `DecisionTrigger`, `LemmingObservation`, `TickObservation`, `Decision` and `DecisionDetector` |
| `Tools/Lemmings2Solver/Actions.swift` | Create | `SolverAction`, `AimBounds`, `actions(in:candidates:bounds:)` and `record(_:tick:skills:)` |
| `Tools/Lemmings2Solver/Scoring.swift` | Create | `Candidate`, `Score` and `mergeByFingerprint(_:)` |
| `Tools/Lemmings2Solver/Search.swift` | Create | `SearchLimits`, `SearchReport`, `advance(_:)`, `finish(_:)` and `search(from:bounds:limits:)` |
| `Tools/Lemmings2Solver/main.swift` | Create | The `solve-level` command, witness writing and acceptance |
| `Tests/Lemmings2SolverTests/SyntheticRuntime.swift` | Create | A verbatim copy of the synthetic level builder |
| `Tests/Lemmings2SolverTests/main.swift` | Create | Solver unit tests and the planted solution test |
| `Scripts/run-lemmings2-solver-tests.sh` | Create | Build the solver sources with the tests and run them |
| `Scripts/solve-lemmings2-level.sh` | Create | Build the solver and solve one campaign level |
| `Documentation/Lemmings2Completion/SolverSpike.md` | Create | Spike results and the go or no-go verdict |

Measured facts this plan relies on:

- The synthetic wall level saves 0 of 3 lemmings with no input.
- On that level, a basher assigned to lemming 0 on any tick from 60 to 67 saves 3 of 3. Lemming 0 turns at the wall on tick 70. No basher assignment after tick 70 saves 3 of 3.
- The wall ahead condition first holds on tick 62, when lemming 0 is at x=42, y=60.
- On the flat synthetic level, the edge ahead condition never holds for a walking lemming. That level saves 3 of 3 with no input.
- `Lemmings2Runtime.isSolid(_:_:)` returns `false` outside the level, so detector probes cannot read out of bounds.
- A detector that follows one lead lemming fires 2,894 decisions on `classic-01` and 24 on `highland-03`, where 23 come from the fallback. Keyed by location, the same levels fire 118 and 521. `highland-03` stays dense, which the spike reports as detector tuning.

---

### Task 1: Share per-tick input application and make the witness encodable

**Files:**
- Modify: `Sources/NxlvKit/Lemmings2ReplayWitness.swift` (whole file)
- Modify: `Tests/Lemmings2RuntimeTests/main.swift` (the fixture loop)

**Interfaces:**
- Consumes: `Lemmings2Runtime`, `Lemmings2Level`, `Lemmings2Style`, `Lemmings2TerrainMasks`, `Lemmings2Campaign.medal(saved:total:allowedLosses:)`.
- Produces:
  - `public struct Lemmings2ReplayWitness: Codable, Sendable` with `public init(levelSHA256: String, population: Int, expectedSaved: Int, expectedTicks: Int, inputs: [Input], pointers: [Pointer])`
  - `public struct Lemmings2ReplayWitness.Input: Codable, Sendable` with `public init(tick: Int, lemming: Int, skill: Int)`
  - `public struct Lemmings2ReplayWitness.Pointer: Codable, Sendable` with `public init(tick: Int, x: Int, y: Int, fanX: Int, fanY: Int, fan: Bool)`
  - `public struct Lemmings2InputCursor: Sendable` with `public init()`, `public private(set) var command: Int`, `public private(set) var pointer: Int` and `public mutating func apply(inputsAt game: inout Lemmings2Runtime, inputs: [Lemmings2ReplayWitness.Input], pointers: [Lemmings2ReplayWitness.Pointer]) throws`
  - Unchanged: `run(level:style:masks:) throws -> Lemmings2WitnessOutcome`, `Lemmings2WitnessError`, `Lemmings2Runtime.stateFingerprint`

- [ ] **Step 1: Write the failing round trip test**

In `Tests/Lemmings2RuntimeTests/main.swift`, find the line in the fixture loop that prints `recorded pointer and skill inputs`:

```swift
            print("PASS \(name): \(outcome.saved) rescued, \(outcome.ticks) ticks, recorded pointer and skill inputs")
```

Insert these lines directly after it:

```swift
            let encoded = try JSONEncoder().encode(replay)
            let decoded = try JSONDecoder().decode(Replay.self, from: encoded)
            let again = try decoded.run(level:level,style:style,masks:masks)
            check(again.saved == outcome.saved && again.ticks == outcome.ticks && again.stateHash == outcome.stateHash,
                  "Encoded witness changed its outcome: \(name)")
```

- [ ] **Step 2: Run the suite and confirm it fails**

Run: `zsh Scripts/run-lemmings2-runtime-tests.sh 2>&1 | grep -m1 "error:"`
Expected: a compiler error that `Lemmings2ReplayWitness` does not conform to `Encodable`.

- [ ] **Step 3: Replace the witness file**

Replace the whole of `Sources/NxlvKit/Lemmings2ReplayWitness.swift` with:

```swift
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
```

- [ ] **Step 4: Run the runtime suite**

Run: `zsh Scripts/run-lemmings2-runtime-tests.sh 2>&1 | grep -E "FAIL|error:|distinct recorded|carry-over verified" | head -8`
Expected: `PASS 64 distinct recorded campaign level completions` and five `survivor carry-over verified` lines. No `FAIL` and no `error:`.

- [ ] **Step 5: Run the completion gate and its negative mode**

Run: `zsh Scripts/verify-lemmings2-completion.sh | grep -E "^Verified|^Tribes chained"; zsh Scripts/verify-lemmings2-completion.sh --negative | tail -1`
Expected: `Verified 64; missing 56.`, `Tribes chained through all ten levels: 0 of 12.` and `PASS seven damaged Lemmings 2 routes rejected`.

- [ ] **Step 6: Commit**

```bash
git add Sources/NxlvKit/Lemmings2ReplayWitness.swift Tests/Lemmings2RuntimeTests/main.swift
git commit -m "Share per-tick Lemmings 2 input application with the route solver"
```

---

### Task 2: Solver test harness and the planted level

**Files:**
- Create: `Scripts/run-lemmings2-solver-tests.sh`
- Create: `Tests/Lemmings2SolverTests/main.swift`
- Create: `Tests/Lemmings2SolverTests/SyntheticRuntime.swift`

**Interfaces:**
- Consumes: `Lemmings2Runtime.Configuration`, `Lemmings2Runtime(configuration:)`.
- Produces: `func check(_ condition: Bool, _ message: String)`, `func fixture(wall: Bool = false) throws -> Lemmings2Runtime`, `func syntheticMasks() throws -> Lemmings2TerrainMasks`, and a test script that later tasks extend by adding source files.

- [ ] **Step 1: Write the test script**

Create `Scripts/run-lemmings2-solver-tests.sh`:

```zsh
#!/bin/zsh
# Builds the Lemmings 2 solver sources with their tests and runs them.
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/l2-solver-tests"
cd "$project_dir"
mkdir -p "$build_dir/modules"
swiftc -O -swift-version 6 -warnings-as-errors -parse-as-library \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" Sources/NxlvKit/*.swift
solver=(Tools/Lemmings2Solver/*.swift(N))
solver=("${(@)solver:#*/main.swift}")
swiftc -O -swift-version 6 -warnings-as-errors \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  "${solver[@]}" Tests/Lemmings2SolverTests/*.swift -o "$build_dir/SolverTests"
"$build_dir/SolverTests"
```

Then run: `chmod +x Scripts/run-lemmings2-solver-tests.sh`

- [ ] **Step 2: Write the first test**

Create `Tests/Lemmings2SolverTests/main.swift`:

```swift
import Foundation
import NxlvKit

func check(_ condition: Bool, _ message: String) {
    guard condition else {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8)); exit(1)
    }
}

// The planted level must be proven before a search result on it means anything.
func testPlantedLevel() throws {
    var passive = try fixture(wall: true)
    while !passive.isComplete { passive.step() }
    check(passive.saved == 0, "The synthetic wall level saves \(passive.saved) lemmings without input")
    var planted = try fixture(wall: true)
    let basher = planted.configuration.skills.firstIndex(of: .basher)!
    while planted.tick < 62 { planted.step() }
    check(planted.assign(slot: basher, to: 0), "The planted basher assignment was refused")
    while !planted.isComplete { planted.step() }
    check(planted.saved == 3, "The planted basher route saved \(planted.saved) of 3")
    print("PASS synthetic wall level: 0 of 3 without input, 3 of 3 with a basher on tick 62")
}
try testPlantedLevel()
```

- [ ] **Step 3: Run the tests and confirm they fail**

Run: `zsh Scripts/run-lemmings2-solver-tests.sh 2>&1 | grep -m1 "error:"`
Expected: `cannot find 'fixture' in scope`.

- [ ] **Step 4: Copy the synthetic level builder**

Run this command from the repository root. It copies both functions verbatim:

```zsh
{
  printf 'import Foundation\nimport NxlvKit\n\n'
  printf '// Copied from Tests/Lemmings2RuntimeTests/main.swift. The release audit compiles each\n'
  printf '// suite from its main.swift alone, so the runtime suite keeps its own copy.\n\n'
  sed -n '/^func fixture(wall: Bool = false)/,/^}/p' Tests/Lemmings2RuntimeTests/main.swift
  echo
  sed -n '/^func syntheticMasks() throws/,/^}/p' Tests/Lemmings2RuntimeTests/main.swift
} > Tests/Lemmings2SolverTests/SyntheticRuntime.swift
grep -c "^func " Tests/Lemmings2SolverTests/SyntheticRuntime.swift
```

Expected: `2`

- [ ] **Step 5: Run the tests**

Run: `zsh Scripts/run-lemmings2-solver-tests.sh`
Expected: `PASS synthetic wall level: 0 of 3 without input, 3 of 3 with a basher on tick 62`

- [ ] **Step 6: Commit**

```bash
git add Scripts/run-lemmings2-solver-tests.sh Tests/Lemmings2SolverTests/main.swift Tests/Lemmings2SolverTests/SyntheticRuntime.swift
git commit -m "Add the Lemmings 2 solver test harness and a proven planted level"
```

---

### Task 3: Location-keyed decision point detector

**Files:**
- Create: `Tools/Lemmings2Solver/DecisionPoints.swift`
- Modify: `Tests/Lemmings2SolverTests/main.swift` (append tests)

**Interfaces:**
- Consumes: `Lemmings2Runtime`, `Lemmings2Runtime.State`, `fixture(wall:)`, `check(_:_:)`.
- Produces:
  - `enum DecisionTrigger: String, Sendable, Equatable` with cases `wallAhead`, `edgeAhead`, `fallStart`, `turn`, `fallback`, and `var priority: Int`
  - `struct LemmingObservation: Sendable, Equatable` with memberwise `init(id: Int, x: Int, y: Int, direction: Int, state: Lemmings2Runtime.State, wallAhead: Bool, edgeAhead: Bool)`
  - `struct TickObservation: Sendable, Equatable` with memberwise `init(tick: Int, lemmings: [LemmingObservation], nearestToExit: Int?)` and `init(_ game: Lemmings2Runtime)`
  - `struct Decision: Sendable, Equatable` with `let trigger: DecisionTrigger` and `let lemmings: [Int]`
  - `struct DecisionDetector: Sendable` with `init(cell: Int = 8, refire: Int = 150, fallback: Int = 150)` and `mutating func update(_ observation: TickObservation) -> Decision?`

A decision belongs to a place, not to one lemming. Measured on real levels, a detector that follows one lead lemming fires about once per tick on `classic-01` and misses every wall on `highland-03`. See the spec's "Location-keyed detector" amendment.

- [ ] **Step 1: Write the failing tests**

Append to `Tests/Lemmings2SolverTests/main.swift`:

```swift
func testWallAheadFiresInsideBasherWindow() throws {
    var game = try fixture(wall: true)
    var detector = DecisionDetector()
    var found: (tick: Int, decision: Decision)?
    while !game.isComplete && found == nil {
        game.step()
        if let decision = detector.update(TickObservation(game)), decision.trigger == .wallAhead {
            found = (game.tick, decision)
        }
    }
    check(found.map { (60...67).contains($0.tick) && $0.decision.lemmings.first == 0 } == true,
          "Wall ahead fired as \(String(describing: found)), expected lemming 0 inside ticks 60...67")
    print("PASS wall ahead fires on tick \(found?.tick ?? -1) for lemming 0, inside the basher window")
}
try testWallAheadFiresInsideBasherWindow()

func testNoTerrainTriggersOnFlatGround() throws {
    var game = try fixture(wall: false)
    var detector = DecisionDetector()
    var fired: [DecisionTrigger] = []
    while !game.isComplete {
        game.step()
        if let decision = detector.update(TickObservation(game)) { fired.append(decision.trigger) }
    }
    check(!fired.contains(.edgeAhead) && !fired.contains(.wallAhead), "Flat ground fired \(fired)")
    print("PASS flat ground fires no wall or edge trigger (other decisions: \(fired.count))")
}
try testNoTerrainTriggersOnFlatGround()

func testLocationKeys() {
    func lemming(_ id: Int, x: Int, wall: Bool = false, direction: Int = 1) -> LemmingObservation {
        LemmingObservation(id: id, x: x, y: 64, direction: direction, state: .walking, wallAhead: wall, edgeAhead: false)
    }
    var walls = DecisionDetector()
    let first = walls.update(TickObservation(tick: 10, lemmings: [lemming(0, x: 40, wall: true)], nearestToExit: 0))
    let sameWall = walls.update(TickObservation(tick: 20, lemmings: [lemming(1, x: 41, wall: true)], nearestToExit: 1))
    let otherWall = walls.update(TickObservation(tick: 30, lemmings: [lemming(2, x: 200, wall: true)], nearestToExit: 2))
    let laterSameWall = walls.update(TickObservation(tick: 170, lemmings: [lemming(3, x: 40, wall: true)], nearestToExit: 3))
    check(first == Decision(trigger: .wallAhead, lemmings: [0]), "The first wall did not fire for lemming 0")
    check(sameWall == nil, "A second lemming at the same wall fired again inside the re-fire window")
    check(otherWall == Decision(trigger: .wallAhead, lemmings: [2]), "A wall at another location did not fire")
    check(laterSameWall == Decision(trigger: .wallAhead, lemmings: [3]), "The same wall did not fire again after the re-fire window")

    var quiet = DecisionDetector()
    var fallback: (tick: Int, decision: Decision)?
    for tick in 1...200 where fallback == nil {
        if let decision = quiet.update(TickObservation(tick: tick, lemmings: [lemming(9, x: 100)], nearestToExit: 9)) {
            fallback = (tick, decision)
        }
    }
    check(fallback?.tick == 150 && fallback?.decision == Decision(trigger: .fallback, lemmings: [9]),
          "Fallback fired as \(String(describing: fallback)), expected tick 150 offering lemming 9")

    var turns = DecisionDetector()
    _ = turns.update(TickObservation(tick: 1, lemmings: [lemming(4, x: 80, direction: 1)], nearestToExit: 4))
    let turned = turns.update(TickObservation(tick: 2, lemmings: [lemming(4, x: 80, direction: -1)], nearestToExit: 4))
    check(turned == Decision(trigger: .turn, lemmings: [4]), "A turn did not fire for the lemming that turned")

    var crowd = DecisionDetector()
    let many = crowd.update(TickObservation(tick: 5, lemmings: (0..<6).map { lemming($0, x: 400 + 16 * $0, wall: true) }, nearestToExit: 0))
    check(many == Decision(trigger: .wallAhead, lemmings: [0, 1, 2]), "Candidates were not capped at three in id order")
    print("PASS location keys, re-fire window, fallback lemming, turns and the three lemming cap")
}
testLocationKeys()
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `zsh Scripts/run-lemmings2-solver-tests.sh 2>&1 | grep -m1 "error:"`
Expected: `cannot find 'DecisionDetector' in scope`.

- [ ] **Step 3: Write the detector**

Create `Tools/Lemmings2Solver/DecisionPoints.swift`:

```swift
import NxlvKit

/// Why the solver may branch at the current tick.
enum DecisionTrigger: String, Sendable, Equatable {
    case wallAhead, edgeAhead, fallStart, turn, fallback

    /// Lower values come first when several lemmings fire on one tick.
    var priority: Int {
        switch self {
        case .wallAhead: return 0
        case .edgeAhead: return 1
        case .fallStart: return 2
        case .turn: return 3
        case .fallback: return 4
        }
    }
}

/// What the detector needs to know about one active lemming on one tick.
struct LemmingObservation: Sendable, Equatable {
    var id: Int
    var x: Int
    var y: Int
    var direction: Int
    var state: Lemmings2Runtime.State
    var wallAhead: Bool
    var edgeAhead: Bool
}

/// What the detector needs to know about one tick.
struct TickObservation: Sendable, Equatable {
    var tick: Int
    var lemmings: [LemmingObservation]
    /// The walking lemming nearest to an exit, which the fallback offers.
    var nearestToExit: Int?
}

extension TickObservation {
    /// Reads every active lemming. Wall and edge probes run only for walking lemmings.
    init(_ game: Lemmings2Runtime) {
        let exits = game.configuration.exits
        func distance(_ x: Int, _ y: Int) -> Int {
            exits.map { abs(x - ($0.x + $0.width / 2)) + abs(y - ($0.y + $0.height / 2)) }.min() ?? 0
        }
        var observed: [LemmingObservation] = []
        var nearest: (distance: Int, id: Int)?
        for lemming in game.lemmings where lemming.active {
            var wall = false, edge = false
            if lemming.state == .walking {
                let ahead = lemming.x + lemming.direction * 8
                wall = ((lemming.y - 8)...(lemming.y - 1)).contains(where: { game.isSolid(ahead, $0) })
                edge = !(lemming.y...(lemming.y + 4)).contains(where: { game.isSolid(ahead, $0) })
                let d = distance(lemming.x, lemming.y)
                if nearest.map({ (d, lemming.id) < ($0.distance, $0.id) }) ?? true { nearest = (d, lemming.id) }
            }
            observed.append(LemmingObservation(id: lemming.id, x: lemming.x, y: lemming.y, direction: lemming.direction,
                                               state: lemming.state, wallAhead: wall, edgeAhead: edge))
        }
        self.init(tick: game.tick, lemmings: observed, nearestToExit: nearest?.id)
    }
}

/// A tick where the solver may branch, and the lemmings it may give skills to.
struct Decision: Sendable, Equatable {
    let trigger: DecisionTrigger
    let lemmings: [Int]
}

/// Reports decision points keyed by location. A crowd that meets one wall fires one
/// decision, not one decision for each lemming.
struct DecisionDetector: Sendable {
    let cell: Int
    let refire: Int
    let fallback: Int
    private var lastDirection: [Int: Int] = [:]
    private var lastState: [Int: Lemmings2Runtime.State] = [:]
    private var lastFired: [String: Int] = [:]
    private var lastDecisionTick = 0

    init(cell: Int = 8, refire: Int = 150, fallback: Int = 150) {
        self.cell = cell
        self.refire = refire
        self.fallback = fallback
    }

    /// Claims a location key. Returns false when the key fired inside the re-fire window.
    private mutating func claim(_ trigger: DecisionTrigger, _ lemming: LemmingObservation, tick: Int) -> Bool {
        let key = "\(trigger.rawValue)|\(lemming.x / cell),\(lemming.y / cell),\(lemming.direction)"
        if let fired = lastFired[key], tick - fired < refire { return false }
        lastFired[key] = tick
        return true
    }

    mutating func update(_ observation: TickObservation) -> Decision? {
        var fired: [(trigger: DecisionTrigger, id: Int)] = []
        for lemming in observation.lemmings {
            let previousDirection = lastDirection[lemming.id]
            let previousState = lastState[lemming.id]
            lastDirection[lemming.id] = lemming.direction
            lastState[lemming.id] = lemming.state
            if previousState == .walking && lemming.state == .falling,
               claim(.fallStart, lemming, tick: observation.tick) {
                fired.append((.fallStart, lemming.id))
            }
            guard lemming.state == .walking else { continue }
            if let previousDirection, previousDirection != lemming.direction,
               claim(.turn, lemming, tick: observation.tick) {
                fired.append((.turn, lemming.id))
            }
            if lemming.wallAhead, claim(.wallAhead, lemming, tick: observation.tick) {
                fired.append((.wallAhead, lemming.id))
            }
            if lemming.edgeAhead, claim(.edgeAhead, lemming, tick: observation.tick) {
                fired.append((.edgeAhead, lemming.id))
            }
        }
        if fired.isEmpty {
            guard observation.tick - lastDecisionTick >= fallback else { return nil }
            lastDecisionTick = observation.tick
            return Decision(trigger: .fallback, lemmings: observation.nearestToExit.map { [$0] } ?? [])
        }
        lastDecisionTick = observation.tick
        let ordered = fired.sorted { ($0.trigger.priority, $0.id) < ($1.trigger.priority, $1.id) }
        var offered: [Int] = []
        for entry in ordered where !offered.contains(entry.id) {
            if offered.count == 3 { break }
            offered.append(entry.id)
        }
        return Decision(trigger: ordered[0].trigger, lemmings: offered)
    }
}
```

- [ ] **Step 4: Run the tests**

Run: `zsh Scripts/run-lemmings2-solver-tests.sh`
Expected, in order:

```
PASS synthetic wall level: 0 of 3 without input, 3 of 3 with a basher on tick 62
PASS wall ahead fires on tick 62 for lemming 0, inside the basher window
PASS flat ground fires no wall or edge trigger (other decisions: N)
PASS location keys, re-fire window, fallback lemming, turns and the three lemming cap
```

`N` can be any count.

- [ ] **Step 5: Commit**

```bash
git add Tools/Lemmings2Solver/DecisionPoints.swift Tests/Lemmings2SolverTests/main.swift
git commit -m "Detect Lemmings 2 decision points by location"
```

---

### Task 4: Actions at a decision point

**Files:**
- Create: `Tools/Lemmings2Solver/Actions.swift`
- Modify: `Tests/Lemmings2SolverTests/main.swift` (append tests)

**Interfaces:**
- Consumes: `Lemmings2Runtime.canAssign(slot:to:)`, `Lemmings2Runtime.Skill`, `Lemmings2Level`, `Lemmings2ReplayWitness.Input`, `Lemmings2ReplayWitness.Pointer`.
- Produces:
  - `enum SolverAction: Sendable, Hashable` with cases `wait`, `assign(slot: Int, lemming: Int)` and `aimedAssign(slot: Int, lemming: Int, x: Int, y: Int)`
  - `struct AimBounds: Sendable, Equatable` with `init(x: ClosedRange<Int>, y: ClosedRange<Int>)`, `init(level: Lemmings2Level)` and `func clamp(x: Int, y: Int) -> (x: Int, y: Int)`
  - `func actions(in game: Lemmings2Runtime, candidates: [Int], bounds: AimBounds) -> [SolverAction]`
  - `func record(_ action: SolverAction, tick: Int, skills: [Lemmings2Runtime.Skill]) -> (inputs: [Lemmings2ReplayWitness.Input], pointers: [Lemmings2ReplayWitness.Pointer])`

- [ ] **Step 1: Write the failing test**

Append to `Tests/Lemmings2SolverTests/main.swift`:

```swift
func testActions() throws {
    var game = try fixture(wall: true)
    while game.tick < 62 { game.step() }
    let bounds = AimBounds(x: 0...(game.configuration.width - 1), y: 0...(game.configuration.height - 1))
    let list = actions(in: game, candidates: [0, 0], bounds: bounds)
    let basher = game.configuration.skills.firstIndex(of: .basher)!
    check(list.first == .wait, "Wait is not the first action")
    check(list.contains(.assign(slot: basher, lemming: 0)), "The basher assignment is missing at the wall")
    check(Set(list).count == list.count, "Repeated candidates produced repeated actions")
    let aimed = list.compactMap { action -> (Int, Int)? in
        if case let .aimedAssign(_, _, x, y) = action { return (x, y) }
        return nil
    }
    check(aimed.count <= 10, "The roper produced \(aimed.count) aim targets, expected at most 10")
    check(aimed.allSatisfy { bounds.x.contains($0.0) && bounds.y.contains($0.1) }, "An aim target lies outside the witness bounds")
    let roper = game.configuration.skills.firstIndex(of: .roper)!
    let recorded = record(.aimedAssign(slot: roper, lemming: 0, x: 10, y: 20), tick: 62, skills: game.configuration.skills)
    check(recorded.inputs.count == 1 && recorded.pointers.count == 1 && recorded.pointers[0].tick == 62
          && recorded.pointers[0].x == 10 && !recorded.pointers[0].fan,
          "An aimed assignment did not record one input and one held pointer")
    check(record(.wait, tick: 62, skills: game.configuration.skills).inputs.isEmpty, "Wait recorded input")
    print("PASS actions: wait first, basher at the wall, bounded roper aim, no repeats")
}
try testActions()
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `zsh Scripts/run-lemmings2-solver-tests.sh 2>&1 | grep -m1 "error:"`
Expected: `cannot find 'AimBounds' in scope`.

- [ ] **Step 3: Write the action model**

Create `Tools/Lemmings2Solver/Actions.swift`:

```swift
import NxlvKit

/// One move the solver can make at a decision point.
enum SolverAction: Sendable, Hashable {
    case wait
    case assign(slot: Int, lemming: Int)
    case aimedAssign(slot: Int, lemming: Int, x: Int, y: Int)
}

/// Pointer limits that the replay witness accepts.
struct AimBounds: Sendable, Equatable {
    let x: ClosedRange<Int>
    let y: ClosedRange<Int>

    init(x: ClosedRange<Int>, y: ClosedRange<Int>) {
        self.x = x
        self.y = y
    }

    init(level: Lemmings2Level) {
        x = level.minimumScreenX...(level.maximumScreenX + 319)
        y = level.minimumScreenY...(level.maximumScreenY + 159)
    }

    func clamp(x: Int, y: Int) -> (x: Int, y: Int) {
        (min(max(x, self.x.lowerBound), self.x.upperBound), min(max(y, self.y.lowerBound), self.y.upperBound))
    }
}

/// Skills whose assignment reads the aim point during the spike.
let aimedSkills: Set<Lemmings2Runtime.Skill> = [.roper]

/// Lists the actions at a decision point. Skills go to the given candidate lemmings,
/// never to the whole crowd. Wait is always first.
func actions(in game: Lemmings2Runtime, candidates: [Int], bounds: AimBounds) -> [SolverAction] {
    var result: [SolverAction] = [.wait]
    var added: Set<SolverAction> = [.wait]
    func add(_ action: SolverAction) {
        if added.insert(action).inserted { result.append(action) }
    }
    for id in candidates {
        guard let lemming = game.lemmings.first(where: { $0.id == id }) else { continue }
        for (slot, skill) in game.configuration.skills.enumerated() where game.canAssign(slot: slot, to: id) {
            if aimedSkills.contains(skill) {
                for direction in [-1, 1] {
                    for offset in [-48, -24, 0, 24, 48] {
                        let target = bounds.clamp(x: lemming.x + 64 * direction, y: lemming.y + offset)
                        add(.aimedAssign(slot: slot, lemming: id, x: target.x, y: target.y))
                    }
                }
            } else {
                add(.assign(slot: slot, lemming: id))
            }
        }
    }
    return result
}

/// The witness input that replays an action taken on `tick`.
func record(_ action: SolverAction, tick: Int, skills: [Lemmings2Runtime.Skill])
    -> (inputs: [Lemmings2ReplayWitness.Input], pointers: [Lemmings2ReplayWitness.Pointer]) {
    switch action {
    case .wait:
        return ([], [])
    case let .assign(slot, lemming):
        return ([.init(tick: tick, lemming: lemming, skill: skills[slot].rawValue)], [])
    case let .aimedAssign(slot, lemming, x, y):
        return ([.init(tick: tick, lemming: lemming, skill: skills[slot].rawValue)],
                [.init(tick: tick, x: x, y: y, fanX: x, fanY: y, fan: false)])
    }
}
```

- [ ] **Step 4: Run the tests**

Run: `zsh Scripts/run-lemmings2-solver-tests.sh | tail -1`
Expected: `PASS actions: wait first, basher at the wall, bounded roper aim, no repeats`

- [ ] **Step 5: Commit**

```bash
git add Tools/Lemmings2Solver/Actions.swift Tests/Lemmings2SolverTests/main.swift
git commit -m "List Lemmings 2 solver actions and record them as witness input"
```

---

### Task 5: Scoring and fingerprint merging

**Files:**
- Create: `Tools/Lemmings2Solver/Scoring.swift`
- Modify: `Tests/Lemmings2SolverTests/main.swift` (append tests)

**Interfaces:**
- Consumes: `Lemmings2InputCursor`, `DecisionDetector`, `Decision`, `Lemmings2Runtime.stateFingerprint`.
- Produces:
  - `struct Candidate: Sendable` with stored `game: Lemmings2Runtime`, `cursor: Lemmings2InputCursor`, `inputs: [Lemmings2ReplayWitness.Input]`, `pointers: [Lemmings2ReplayWitness.Pointer]`, `depth: Int`, `fingerprint: String`, `detector: DecisionDetector` and `decision: Decision?`, all `var`, with the memberwise initialiser in that order
  - `struct Score: Comparable, Sendable` with memberwise `init(saved: Int, remaining: Int, distance: Int, inputs: Int, fingerprint: String)` and `init(_ candidate: Candidate)`. `a < b` means `a` ranks below `b`.
  - `func mergeByFingerprint(_ candidates: [Candidate]) -> [Candidate]`, which returns the best entry for each merge key, best first

- [ ] **Step 1: Write the failing test**

Append to `Tests/Lemmings2SolverTests/main.swift`:

```swift
func testScoring() throws {
    let base = Score(saved: 1, remaining: 50, distance: 100, inputs: 5, fingerprint: "b")
    check(base < Score(saved: 2, remaining: 0, distance: 9999, inputs: 99, fingerprint: "a"), "More saved lemmings did not rank higher")
    check(base < Score(saved: 1, remaining: 51, distance: 9999, inputs: 99, fingerprint: "a"), "Fewer losses did not rank higher")
    check(base < Score(saved: 1, remaining: 50, distance: 99, inputs: 99, fingerprint: "a"), "A shorter crowd distance did not rank higher")
    check(base < Score(saved: 1, remaining: 50, distance: 100, inputs: 4, fingerprint: "c"), "Fewer inputs did not rank higher")
    check(Score(saved: 1, remaining: 50, distance: 100, inputs: 5, fingerprint: "c") < base, "The fingerprint tie break is not fixed")

    let game = try fixture(wall: true)
    func candidate(inputs: Int, pointerX: Int?) -> Candidate {
        Candidate(game: game, cursor: Lemmings2InputCursor(),
                  inputs: Array(repeating: Lemmings2ReplayWitness.Input(tick: 0, lemming: 0, skill: 1), count: inputs),
                  pointers: pointerX.map { [Lemmings2ReplayWitness.Pointer(tick: 0, x: $0, y: 0, fanX: $0, fanY: 0, fan: false)] } ?? [],
                  depth: 0, fingerprint: "same", detector: DecisionDetector(), decision: nil)
    }
    let merged = mergeByFingerprint([candidate(inputs: 3, pointerX: nil), candidate(inputs: 1, pointerX: nil)])
    check(merged.count == 1 && merged[0].inputs.count == 1, "The merge did not keep the shorter route")
    let aims = mergeByFingerprint([candidate(inputs: 1, pointerX: 10), candidate(inputs: 1, pointerX: 20)])
    check(aims.count == 2, "States that differ only in the held pointer were merged")
    let first = aims.map { $0.pointers[0].x }
    let second = mergeByFingerprint([candidate(inputs: 1, pointerX: 20), candidate(inputs: 1, pointerX: 10)]).map { $0.pointers[0].x }
    check(first == second, "The merge order depends on input order")
    print("PASS scoring order, fixed tie break and fingerprint merge")
}
try testScoring()
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `zsh Scripts/run-lemmings2-solver-tests.sh 2>&1 | grep -m1 "error:"`
Expected: `cannot find 'Score' in scope`.

- [ ] **Step 3: Write the scoring**

Create `Tools/Lemmings2Solver/Scoring.swift`:

```swift
import NxlvKit

/// A solver candidate: a runtime snapshot and the recorded input that produced it.
struct Candidate: Sendable {
    var game: Lemmings2Runtime
    var cursor: Lemmings2InputCursor
    var inputs: [Lemmings2ReplayWitness.Input]
    var pointers: [Lemmings2ReplayWitness.Pointer]
    var depth: Int
    var fingerprint: String
    var detector: DecisionDetector
    /// The decision this candidate stopped at, which names the lemmings it may act on.
    var decision: Decision?
}

/// Ranks candidates. The order compares saved lemmings, then lemmings not yet lost,
/// then distance to an exit, then input count, then the fingerprint as a fixed tie break.
struct Score: Comparable, Sendable {
    let saved: Int
    let remaining: Int
    let distance: Int
    let inputs: Int
    let fingerprint: String

    /// `a < b` means that `a` ranks below `b`.
    static func < (a: Score, b: Score) -> Bool {
        if a.saved != b.saved { return a.saved < b.saved }
        if a.remaining != b.remaining { return a.remaining < b.remaining }
        if a.distance != b.distance { return a.distance > b.distance }
        if a.inputs != b.inputs { return a.inputs > b.inputs }
        return a.fingerprint > b.fingerprint
    }
}

extension Score {
    init(_ candidate: Candidate) {
        let game = candidate.game
        let exits = game.configuration.exits
        func toExit(_ x: Int, _ y: Int) -> Int {
            exits.map { abs(x - ($0.x + $0.width / 2)) + abs(y - ($0.y + $0.height / 2)) }.min() ?? 0
        }
        let entrance = game.configuration.entrance
        // Lemmings not yet released count from the entrance, so releasing fewer gains no rank.
        let waiting = max(0, game.configuration.total - game.released)
        let active = game.lemmings.filter(\.active).reduce(0) { $0 + toExit($1.x, $1.y) }
        self.init(saved: game.saved, remaining: game.configuration.total - game.lost,
                  distance: active + waiting * toExit(entrance.x + entrance.width / 2, entrance.y + entrance.height / 2),
                  inputs: candidate.inputs.count, fingerprint: candidate.fingerprint)
    }
}

/// The state fingerprint omits the held pointer, which can move machines later,
/// so the merge key adds the last recorded pointer.
private func mergeKey(_ candidate: Candidate) -> String {
    let pointer = candidate.pointers.last.map { "\($0.x),\($0.y),\($0.fanX),\($0.fanY),\($0.fan)" } ?? "-"
    return candidate.fingerprint + "|" + pointer
}

/// Keeps the highest ranked candidate for each merge key, best first.
func mergeByFingerprint(_ candidates: [Candidate]) -> [Candidate] {
    var best: [String: (score: Score, candidate: Candidate)] = [:]
    for candidate in candidates {
        let key = mergeKey(candidate), score = Score(candidate)
        if let existing = best[key], !(existing.score < score) { continue }
        best[key] = (score, candidate)
    }
    // Sort by rank, then by key, because dictionary order changes between processes.
    return best.sorted {
        if $0.value.score != $1.value.score { return $1.value.score < $0.value.score }
        return $0.key < $1.key
    }.map { $0.value.candidate }
}
```

- [ ] **Step 4: Run the tests**

Run: `zsh Scripts/run-lemmings2-solver-tests.sh | tail -1`
Expected: `PASS scoring order, fixed tie break and fingerprint merge`

- [ ] **Step 5: Commit**

```bash
git add Tools/Lemmings2Solver/Scoring.swift Tests/Lemmings2SolverTests/main.swift
git commit -m "Rank Lemmings 2 solver candidates by crowd rescue and merge equal states"
```

---

### Task 6: Beam search and the planted solution

**Files:**
- Create: `Tools/Lemmings2Solver/Search.swift`
- Modify: `Tests/Lemmings2SolverTests/main.swift` (append tests)

**Interfaces:**
- Consumes: `Candidate`, `Score`, `mergeByFingerprint(_:)`, `DecisionDetector`, `TickObservation`, `Decision`, `DecisionTrigger`, `actions(in:candidates:bounds:)`, `record(_:tick:skills:)`, `AimBounds`, `Lemmings2InputCursor`.
- Produces:
  - `struct SearchLimits: Sendable` with `var beamWidth = 64`, `var maxDepth = 40`, `var budgetSeconds = 900.0`, `var cell = 8` and `var refire = 150`
  - `struct SearchReport: Sendable` with `var best: Candidate?`, `var bestPartial: Candidate?`, `var decisionPoints = 0`, `var fallbackPoints = 0`, `var expanded = 0` and `var seconds = 0.0`
  - `func advance(_ candidate: inout Candidate) throws -> Decision?`
  - `func finish(_ candidate: Candidate) -> Candidate`
  - `func search(from start: Lemmings2Runtime, bounds: AimBounds, limits: SearchLimits) -> SearchReport`

- [ ] **Step 1: Write the failing planted solution test**

Append to `Tests/Lemmings2SolverTests/main.swift`:

```swift
func testPlantedRouteIsFound() throws {
    let game = try fixture(wall: true)
    let bounds = AimBounds(x: 0...(game.configuration.width - 1), y: 0...(game.configuration.height - 1))
    let report = search(from: game, bounds: bounds, limits: SearchLimits(beamWidth: 16, maxDepth: 6, budgetSeconds: 120))
    guard let best = report.best else {
        check(false, "The search found no winning route on the planted level"); return
    }
    check(best.game.saved == 3, "The search saved \(best.game.saved) of 3 on the planted level, expected the crowd route")
    // Replay the found input from a fresh runtime through the shared cursor.
    var replay = try fixture(wall: true)
    var cursor = Lemmings2InputCursor()
    while !replay.isComplete {
        try cursor.apply(inputsAt: &replay, inputs: best.inputs, pointers: best.pointers)
        replay.step()
    }
    check(replay.saved == 3 && replay.tick == best.game.tick && replay.stateFingerprint == best.game.stateFingerprint,
          "The found route did not replay to the same state")
    print("PASS search finds the planted crowd route: 3 of 3 in \(best.game.tick) ticks, \(best.inputs.count) inputs, \(report.expanded) nodes")
}
try testPlantedRouteIsFound()
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `zsh Scripts/run-lemmings2-solver-tests.sh 2>&1 | grep -m1 "error:"`
Expected: `cannot find 'search' in scope`.

- [ ] **Step 3: Write the search**

Create `Tools/Lemmings2Solver/Search.swift`:

```swift
import Foundation
import NxlvKit

struct SearchLimits: Sendable {
    var beamWidth = 64
    var maxDepth = 40
    var budgetSeconds = 900.0
    var cell = 8
    var refire = 150
}

struct SearchReport: Sendable {
    var best: Candidate?
    var bestPartial: Candidate?
    var decisionPoints = 0
    var fallbackPoints = 0
    var expanded = 0
    var seconds = 0.0
}

/// Runs a candidate through its recorded input until the next decision point.
/// Returns nil when the level ends. Throws when a recorded input is rejected.
func advance(_ candidate: inout Candidate) throws -> Decision? {
    let inputs = candidate.inputs, pointers = candidate.pointers
    while !candidate.game.isComplete {
        var cursor = candidate.cursor
        try cursor.apply(inputsAt: &candidate.game, inputs: inputs, pointers: pointers)
        candidate.cursor = cursor
        candidate.game.step()
        let observation = TickObservation(candidate.game)
        if let decision = candidate.detector.update(observation) { return decision }
    }
    return nil
}

/// Runs a candidate to the end of the level without taking further decisions.
func finish(_ candidate: Candidate) -> Candidate {
    var tail = candidate
    while !tail.game.isComplete {
        do { _ = try advance(&tail) } catch { break }
    }
    return tail
}

/// Searches for the crowd route that saves the most lemmings.
func search(from start: Lemmings2Runtime, bounds: AimBounds, limits: SearchLimits) -> SearchReport {
    let started = Date()
    var report = SearchReport()
    func elapsed() -> Double { Date().timeIntervalSince(started) }
    func settle(_ candidate: inout Candidate, _ decision: Decision?) {
        candidate.fingerprint = candidate.game.stateFingerprint
        candidate.decision = decision
        if let decision {
            report.decisionPoints += 1
            if decision.trigger == .fallback { report.fallbackPoints += 1 }
        }
    }
    func consider(_ candidate: Candidate) {
        let score = Score(candidate)
        if candidate.game.isComplete && candidate.game.didWin,
           report.best.map({ Score($0) < score }) ?? true {
            report.best = candidate
        }
        if report.bestPartial.map({ Score($0) < score }) ?? true { report.bestPartial = candidate }
    }

    var root = Candidate(game: start, cursor: Lemmings2InputCursor(), inputs: [], pointers: [],
                         depth: 0, fingerprint: "", detector: DecisionDetector(cell: limits.cell, refire: limits.refire),
                         decision: nil)
    let firstDecision = try? advance(&root)
    settle(&root, firstDecision)
    consider(root)
    var beam = root.game.isComplete ? [] : [root]

    while !beam.isEmpty {
        if elapsed() >= limits.budgetSeconds {
            if let top = beam.first {
                var tail = finish(top)
                settle(&tail, nil)
                consider(tail)
            }
            break
        }
        var next: [Candidate] = []
        for node in beam {
            if node.depth >= limits.maxDepth {
                var tail = finish(node)
                settle(&tail, nil)
                consider(tail)
                continue
            }
            for action in actions(in: node.game, candidates: node.decision?.lemmings ?? [], bounds: bounds) {
                var child = node
                let recorded = record(action, tick: child.game.tick, skills: child.game.configuration.skills)
                child.inputs += recorded.inputs
                child.pointers += recorded.pointers
                child.depth += 1
                report.expanded += 1
                let decision: Decision?
                do { decision = try advance(&child) } catch { continue }
                settle(&child, decision)
                consider(child)
                if !child.game.isComplete { next.append(child) }
            }
            if elapsed() >= limits.budgetSeconds { break }
        }
        beam = Array(mergeByFingerprint(next).prefix(limits.beamWidth))
    }
    report.seconds = elapsed()
    return report
}
```

- [ ] **Step 4: Run the tests**

Run: `zsh Scripts/run-lemmings2-solver-tests.sh | tail -1`
Expected: a line that starts with `PASS search finds the planted crowd route: 3 of 3`.

If the search returns a route that saves fewer than 3, stop. Do not change the test or the scoring to pass it. The planted level has a proven 3 of 3 route, so a lower result means the detector, the actions or the scoring is wrong. Diagnose it with superpowers:systematic-debugging.

- [ ] **Step 5: Commit**

```bash
git add Tools/Lemmings2Solver/Search.swift Tests/Lemmings2SolverTests/main.swift
git commit -m "Search Lemmings 2 routes by crowd rescue at decision points"
```

---

### Task 7: The solve-level command and the known answer

**Files:**
- Create: `Tools/Lemmings2Solver/main.swift`
- Create: `Scripts/solve-lemmings2-level.sh`

**Interfaces:**
- Consumes: `search(from:bounds:limits:)`, `advance(_:)`, `Candidate`, `DecisionDetector`, `SearchLimits`, `SearchReport`, `AimBounds(level:)`, `Lemmings2ReplayWitness.init(levelSHA256:population:expectedSaved:expectedTicks:inputs:pointers:)`, `Lemmings2ReplayWitness.run(level:style:masks:)`.
- Produces: `zsh Scripts/solve-lemmings2-level.sh <tribe-NN> [--population N] [--beam N] [--depth N] [--budget SECONDS] [--cell PIXELS] [--refire TICKS] [--out DIR]`. Exit code 0 prints `SOLVED`, 2 prints `UNSOLVED` and 1 prints `ERROR`. A solved route is written to `<out>/<tribe-NN>.json`. An unsolved level writes its best partial route to `<out>/<tribe-NN>.partial.json`, which is never an accepted route.

- [ ] **Step 1: Write the build script**

Create `Scripts/solve-lemmings2-level.sh`:

```zsh
#!/bin/zsh
# Builds the Lemmings 2 route solver and solves one campaign level.
# Usage: zsh Scripts/solve-lemmings2-level.sh <tribe-NN> [--population N] [--beam N] [--depth N] [--budget SECONDS] [--cell PIXELS] [--refire TICKS] [--out DIR]
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/l2-solver"
cd "$project_dir"
data="$project_dir/Sources/Ports/Lemm2"
[[ -f "$data/LEVELS/LEVEL000.DAT" ]] || data="$project_dir/.build/local/Ultimate Lemmings.app/Contents/Resources/Ports/Lemm2"
[[ -f "$data/LEVELS/LEVEL000.DAT" ]] || { echo "Lemmings 2 data not found." >&2; exit 1; }
mkdir -p "$build_dir/modules"
swiftc -O -swift-version 6 -warnings-as-errors -parse-as-library \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" Sources/NxlvKit/*.swift
swiftc -O -swift-version 6 -warnings-as-errors \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  Tools/Lemmings2Solver/*.swift -o "$build_dir/solve-level"
exec "$build_dir/solve-level" "$data" "$@"
```

Then run: `chmod +x Scripts/solve-lemmings2-level.sh`

- [ ] **Step 2: Run the script and confirm it fails**

Run: `zsh Scripts/solve-lemmings2-level.sh classic-01 2>&1 | grep -m1 -E "error:|undefined"`
Expected: `error: link command failed with exit code 1`, because no file defines the `_main` entry point until `Tools/Lemmings2Solver/main.swift` exists.

- [ ] **Step 3: Write the command**

Create `Tools/Lemmings2Solver/main.swift`:

```swift
import Foundation
import NxlvKit

// solve-level <data-root> <tribe-NN> [--population N] [--beam N] [--depth N] [--budget SECONDS] [--cell PIXELS] [--refire TICKS] [--out DIR]
let arguments = Array(CommandLine.arguments.dropFirst())

@MainActor func option(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}

guard arguments.count >= 2 else {
    print("usage: solve-level <data-root> <tribe-NN> [--population N] [--beam N] [--depth N] [--budget SECONDS] [--cell PIXELS] [--refire TICKS] [--out DIR]")
    exit(1)
}
let root = URL(fileURLWithPath: arguments[0])
let name = arguments[1]
let population = option("--population").flatMap(Int.init) ?? 60
var limits = SearchLimits()
if let value = option("--beam").flatMap(Int.init) { limits.beamWidth = value }
if let value = option("--budget").flatMap(Double.init) { limits.budgetSeconds = value }
if let value = option("--cell").flatMap(Int.init) { limits.cell = value }
if let value = option("--refire").flatMap(Int.init) { limits.refire = value }
let out = URL(fileURLWithPath: option("--out") ?? ".build/l2-solver/candidates")

let campaign = try Lemmings2Campaign(root: root)
let masks = try Lemmings2TerrainMasks(root: root)
func levelName(_ index: Int, _ level: Lemmings2Level) -> String {
    let tribe = level.style == 2 ? "cavelem" : Lemmings2Campaign.tribeNames[level.style].lowercased()
    return String(format: "\(tribe)-%02d", index % 10 + 1)
}
guard let index = campaign.levels.indices.first(where: { levelName($0, campaign.levels[$0]) == name }) else {
    print("ERROR unknown level \(name)")
    exit(1)
}
let level = campaign.levels[index]
let style = try Lemmings2Style(data: Data(contentsOf: root.appendingPathComponent(
    "STYLES/\(Lemmings2Campaign.styleNames[level.style]).DAT")))
let start = try Lemmings2Runtime(level: level, style: style, masks: masks, total: population)
// Decision density on a run without input. A dense level points to detector tuning.
var passive = Candidate(game: start, cursor: Lemmings2InputCursor(), inputs: [], pointers: [], depth: 0,
                        fingerprint: "", detector: DecisionDetector(cell: limits.cell, refire: limits.refire), decision: nil)
var passivePoints = 0
while (try? advance(&passive)) != nil { passivePoints += 1 }
let density = String(format: "%.1f", Double(passivePoints) * 100 / Double(max(1, passive.game.tick)))
// A depth of 40 decision points stopped every real-level search early. Let the search branch
// through every decision point a run without input meets, plus a margin for new terrain.
limits.maxDepth = option("--depth").flatMap(Int.init) ?? passivePoints + 40
let report = search(from: start, bounds: AimBounds(level: level), limits: limits)
let summary = "density \(density) per 100 ticks, decision points \(report.decisionPoints) (fallback \(report.fallbackPoints)), expanded \(report.expanded), \(Int(report.seconds)) s, depth \(limits.maxDepth)"

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

guard let best = report.best else {
    // Keep the best partial route for inspection. It is not an accepted route.
    if let partial = report.bestPartial.map(finish) {
        let record = Lemmings2ReplayWitness(levelSHA256: level.fingerprint, population: population,
            expectedSaved: partial.game.saved, expectedTicks: partial.game.tick,
            inputs: partial.inputs, pointers: partial.pointers)
        try encoder.encode(record).write(to: out.appendingPathComponent(name + ".partial.json"))
    }
    print("UNSOLVED \(name): best saved \(report.bestPartial?.game.saved ?? 0) of \(population); \(summary)")
    exit(2)
}
let witness = Lemmings2ReplayWitness(levelSHA256: level.fingerprint, population: population,
    expectedSaved: best.game.saved, expectedTicks: best.game.tick, inputs: best.inputs, pointers: best.pointers)
let file = out.appendingPathComponent(name + ".json")
try encoder.encode(witness).write(to: file)

// Accept the route only when the written file replays twice to the solver's outcome.
do {
    let written = try JSONDecoder().decode(Lemmings2ReplayWitness.self, from: Data(contentsOf: file))
    let first = try written.run(level: level, style: style, masks: masks)
    let second = try written.run(level: level, style: style, masks: masks)
    guard first.stateHash == second.stateHash, first.saved == best.game.saved, first.ticks == best.game.tick else {
        print("ERROR \(name): the written route does not replay to the solver's outcome")
        exit(1)
    }
    print("SOLVED \(name): saved \(first.saved) of \(population), \(first.medal.name), \(first.ticks) ticks, \(best.inputs.count) inputs; \(summary)")
} catch {
    print("ERROR \(name): the written route failed replay: \(error)")
    exit(1)
}
```

- [ ] **Step 4: Run a short solve to check the command**

Run: `zsh Scripts/solve-lemmings2-level.sh classic-01 --budget 60; echo "exit=$?"`
Expected: one `SOLVED classic-01` or `UNSOLVED classic-01` line, then `exit=0` or `exit=2`. `exit=1` is a failure. Diagnose it before continuing.

- [ ] **Step 5: Run the known answer and record it**

Run: `zsh Scripts/solve-lemmings2-level.sh classic-01 > .build/l2-solver/known-answer.log 2>&1; echo "exit=$?"; grep -E "^(SOLVED|UNSOLVED|ERROR)" .build/l2-solver/known-answer.log`
Expected: `exit=0` or `exit=2`, and one result line. `exit=1` is a failure. Diagnose it before continuing.

Record the result line in the commit message. Do not raise the beam, the depth or the budget to change it.

The recorded `classic-01` route saves 60 of 60. A solver result below 30 does not stop the plan. Task 8 reports it next to the spike, where it decides whether a no-go verdict can be trusted. Planning measured this command on `classic-01`: it saved 0 of 60 and ended in about 20 seconds, because every branch ended without a win. On `cavelem-01`, the same solver saved 40 of 60 with a Silver medal. Expect a similar `classic-01` result.

- [ ] **Step 6: Run all solver tests again**

Run: `zsh Scripts/run-lemmings2-solver-tests.sh`
Expected: all seven `PASS` lines from Tasks 2 to 6.

- [ ] **Step 7: Commit**

```bash
git add Tools/Lemmings2Solver/main.swift Scripts/solve-lemmings2-level.sh
git commit -m "Add the solve-level command with double replay acceptance"
```

---

### Task 8: Run the spike and record the verdict

**Files:**
- Create: `Documentation/Lemmings2Completion/SolverSpike.md`

**Interfaces:**
- Consumes: `Scripts/solve-lemmings2-level.sh`, `Scripts/verify-lemmings2-completion.sh`, `Scripts/run-lemmings2-runtime-tests.sh`.
- Produces: the spike report and the go or no-go verdict that decides whether phase 2 starts.

- [ ] **Step 1: Run the four spike levels**

Run each level with the default limits. Each run can take up to 15 minutes.

```zsh
mkdir -p .build/l2-solver/spike
for level in classic-01 cavelem-01 highland-03 space-03 medieval-03; do
  zsh Scripts/solve-lemmings2-level.sh "$level" > ".build/l2-solver/spike/$level.log" 2>&1
  echo "$level exit=$?" >> .build/l2-solver/spike/exits.txt
done
cat .build/l2-solver/spike/exits.txt
grep -hE "^(SOLVED|UNSOLVED|ERROR)" .build/l2-solver/spike/*.log
```

Expected: five exit lines and five result lines. An `ERROR` line is a failure that must be diagnosed. It does not count as unsolved.

- [ ] **Step 2: Write the spike report from the logs**

Run this script from the repository root. It reads the four logs and writes the whole report, including the table and the verdict:

```zsh
python3 - <<'PY'
import re, pathlib, hashlib
levels = ["classic-01", "cavelem-01", "highland-03", "space-03", "medieval-03"]
pattern = re.compile(r"^(SOLVED|UNSOLVED|ERROR) \S+: (?:saved|best saved) (\d+) of 60(?:, \w+, (\d+) ticks)?.*?"
                     r"density ([\d.]+) per 100 ticks, decision points (\d+) \(fallback (\d+)\), expanded (\d+), (\d+) s, depth (\d+)", re.M)
rows, accepted = [], {}
for level in levels:
    text = pathlib.Path(f".build/l2-solver/spike/{level}.log").read_text()
    m = pattern.search(text)
    if not m:
        raise SystemExit(f"{level}: no result line in the log. Diagnose an ERROR before writing the report.")
    status, count, ticks, density, points, fallback, expanded, seconds, depth = m.groups()
    accepted[level] = int(count) if status == "SOLVED" else 0
    candidate = pathlib.Path(f".build/l2-solver/candidates/{level}.json")
    digest = hashlib.sha256(candidate.read_bytes()).hexdigest()[:12] if status == "SOLVED" else "-"
    share = f"{100 * int(fallback) // int(points)}%" if int(points) else "-"
    label = f"`{level}` (known answer)" if level == "classic-01" else f"`{level}`"
    rows.append(f"| {label} | {status} | {count} of 60 | {ticks or '-'} | {density} | {depth} | {points} | {share} | {expanded} | {seconds} s | {digest} |")
go = accepted["cavelem-01"] >= 30 and sum(accepted[l] >= 20 for l in ["highland-03", "space-03", "medieval-03"]) >= 2
known = accepted["classic-01"] >= 30
table = "\n".join(["| Level | Result | Saved | Ticks | Density per 100 ticks | Depth limit | Decision points | From fallback | Expanded | Time | Candidate SHA-256 |",
                   "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |", *rows])
verdict = "GO" if go else ("NO-GO" if known else "NO-GO, inconclusive")
report = f"""# Lemmings 2 solver spike

This report records phase 1 of the Lemmings 2 route solver. It tests whether a
crowd search that branches at decision points can find winning routes.

## Method

Each level ran with 60 lemmings, a beam width of 64, a location cell of 8 pixels,
a re-fire window of 150 ticks and a budget of 15 minutes on one core. The depth
limit is the number of decision points on a run without input, plus 40. A route counts only after the written file
replays twice to the same state hash, saved count and tick count.

## Results

{table}

Density counts decision points per 100 ticks on a run without input. A high
density points to detector tuning, not to a level that cannot be solved. The
fallback share shows how many decision points came from the 150 tick fallback. A
high share means that the trigger model misses a mechanic on that level. An unsolved level has no ticks, because no accepted route reached the end.

## Verdict

**{verdict}**

Go requires an accepted `cavelem-01` route that saves at least 30 of 60, and
accepted routes that save at least 20 of 60 on at least two of `highland-03`,
`space-03` and `medieval-03`.

A go verdict starts phase 2, which needs its own plan. A no-go verdict makes
seeded search the primary method.

`classic-01` is the known answer. Its recorded route saves 60 of 60. It does not
change a go verdict. If the verdict is no-go and the solver also saves fewer than
30 on `classic-01`, the verdict is inconclusive: the search fails on a level with a
proven route, so the no-go may come from the search rather than from the levels.

A level without a found route is unsolved by search. It is not a broken level.

## Checks before the spike

- The search found the planted crowd route on the synthetic level: 3 of 3.
- The known answer on `classic-01` appears in the table as its own row.
- The runtime suite, the completion gate and its negative mode still pass.

Candidates stay in `.build/l2-solver/candidates/`. Phase 1 does not promote them
into the fixture directory.
"""
pathlib.Path("Documentation/Lemmings2Completion/SolverSpike.md").write_text(report)
print(table)
print("VERDICT:", verdict)
PY
```

Expected: a Markdown table with five rows, a `VERDICT:` line, and a new `Documentation/Lemmings2Completion/SolverSpike.md`. If the script stops with `no result line in the log`, a level ended in `ERROR`. Diagnose that level before writing the report.

- [ ] **Step 3: Check the report**

Run: `grep -c '^| `' Documentation/Lemmings2Completion/SolverSpike.md; grep -A2 '^## Verdict' Documentation/Lemmings2Completion/SolverSpike.md | tail -1`
Expected: `5`, then the bold verdict that the script printed: `**GO**`, `**NO-GO**` or `**NO-GO, inconclusive**`.

- [ ] **Step 4: Confirm nothing regressed**

Run:

```zsh
zsh Scripts/run-lemmings2-solver-tests.sh | grep -c "^PASS"
zsh Scripts/run-lemmings2-runtime-tests.sh 2>&1 | grep -E "distinct recorded|FAIL" | head -2
zsh Scripts/verify-lemmings2-completion.sh | grep "^Verified"
zsh Scripts/verify-lemmings2-completion.sh --negative | tail -1
git status --short Tests/Lemmings2CompletionTests/Fixtures
```

Expected: `7`, `PASS 64 distinct recorded campaign level completions`, `Verified 64; missing 56.`, `PASS seven damaged Lemmings 2 routes rejected`, and no output from the last command, because phase 1 does not change fixtures.

- [ ] **Step 5: Commit**

```bash
git add Documentation/Lemmings2Completion/SolverSpike.md
git commit -m "Record the Lemmings 2 solver spike verdict"
```

---

## Out of scope for this plan

- Phase 2: tribe chaining, backtracking, the seed hook, promotion into fixtures, all aimed skills, fans, machines, chains and parallel tribes. Phase 2 needs its own plan after a go verdict.
- Adding the solver tests to `Tools/ReleaseReadiness/audit.py`. Codex owns that file.
- Lemmings 3.
