# Lemmings 2 Completion Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Lemmings 2 route evidence the same strict, tamper-evident gate the Classic family already has.

**Architecture:** One replay implementation moves from the runtime test file into `NxlvKit`. A command line tool, a Python manifest generator and a shell script use that one implementation. The runtime suite calls it too, so the gate and the suite cannot drift apart.

**Tech Stack:** Swift 6 (`swiftc`, no SwiftPM), Python 3 for the manifest, zsh scripts. macOS 13 target.

## Global Constraints

- Swift version: `-swift-version 6`. Scripts compile with `swiftc` directly, not SwiftPM.
- Target: `-target $arch-apple-macos13.0`. Both `arm64` and `x86_64` must build.
- Tool scripts use `-warnings-as-errors`. Do not introduce warnings.
- Fixture JSON stays sorted and pretty printed, so the manifest hashes stay stable.
- Never refresh a manifest to hide a regression. A changed outcome is a failure.
- A win requires `game.didWin`. A matching start state is not evidence.
- Read `Documentation/UIPrinciples.md` before changing any visible interface. This
  plan changes no interface.

---

### Task 1: Move the replay witness into NxlvKit

**Files:**
- Create: `Sources/NxlvKit/Lemmings2ReplayWitness.swift`
- Modify: `Tests/Lemmings2RuntimeTests/main.swift:1465-1564`
- Test: `Tests/Lemmings2RuntimeTests/main.swift` (existing suite proves the move)

**Interfaces:**
- Consumes: `Lemmings2Runtime`, `Lemmings2Level`, `Lemmings2Style`, `Lemmings2TerrainMasks`, `Lemmings2Campaign` (all existing in NxlvKit).
- Produces:
  - `public struct Lemmings2ReplayWitness: Decodable` with `version: Int`, `levelSHA256: String`, `population: Int`, `expectedSaved: Int`, `expectedTicks: Int`, `inputs: [Input]`, `pointers: [Pointer]?`
  - `public struct Lemmings2WitnessOutcome` with `saved: Int`, `ticks: Int`, `medal: Lemmings2Campaign.Medal`, `stateHash: String`
  - `public enum Lemmings2WitnessError: Error` with cases `unknownLevel(String)`, `rejectedInput(Int)`, `outOfOrderInput(Int)`, `pointerOutOfViewport(Int)`, `outcomeChanged(String)`
  - `public func run(level:style:masks:) throws -> Lemmings2WitnessOutcome`

- [ ] **Step 1: Write the failing test**

Add to `Tests/Lemmings2RuntimeTests/main.swift`, immediately before the existing
fixture loop at line 1512:

```swift
func testWitnessRejectsOutOfOrderInputs() throws {
    let json = """
    {"version":1,"levelSHA256":"deadbeef","population":60,"expectedSaved":1,
     "expectedTicks":100,"pointers":[],
     "inputs":[{"tick":50,"lemming":0,"skill":7},{"tick":10,"lemming":0,"skill":7}]}
    """
    let witness = try JSONDecoder().decode(Lemmings2ReplayWitness.self, from: Data(json.utf8))
    check(witness.inputsAreOrdered == false, "Witness accepted out-of-order inputs")
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `zsh Scripts/run-lemmings2-runtime-tests.sh`
Expected: FAIL. The compiler reports `cannot find 'Lemmings2ReplayWitness' in scope`.

- [ ] **Step 3: Create the witness type**

Create `Sources/NxlvKit/Lemmings2ReplayWitness.swift`. Move the `Replay` struct
from the test file verbatim, then add the ordering check and the run method. The
replay loop is the existing loop from `Tests/Lemmings2RuntimeTests/main.swift:1534-1561`,
moved without behaviour change.

```swift
import Foundation

/// One recorded winning route for a Lemmings 2 campaign level.
/// The gate and the runtime suite share this type, so their rules cannot drift.
public struct Lemmings2ReplayWitness: Decodable, Sendable {
    public struct Pointer: Decodable, Sendable {
        public let tick: Int, x: Int, y: Int, fanX: Int, fanY: Int, fan: Bool
    }
    public struct Input: Decodable, Sendable {
        public let tick: Int, lemming: Int, skill: Int
    }
    public let version: Int
    public let levelSHA256: String
    public let population: Int
    public let expectedSaved: Int
    public let expectedTicks: Int
    public let inputs: [Input]
    public let pointers: [Pointer]?

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
    case outOfOrderInput(Int)
    case pointerOutOfViewport(Int)
    case outcomeChanged(String)
}

extension Lemmings2ReplayWitness {
    /// Replays the route from a fresh runtime and returns its outcome.
    public func run(level: Lemmings2Level, style: Lemmings2Style,
                    masks: Lemmings2TerrainMasks) throws -> Lemmings2WitnessOutcome {
        guard inputsAreOrdered else { throw Lemmings2WitnessError.outOfOrderInput(0) }
        guard levelSHA256 == level.fingerprint else {
            throw Lemmings2WitnessError.unknownLevel(levelSHA256)
        }
        var game = try Lemmings2Runtime(level: level, style: style, masks: masks,
            total: population, allowExperimentalTribes: true)
        let pointers = self.pointers ?? []
        for (index, p) in pointers.enumerated() {
            let insideX = (level.minimumScreenX...level.maximumScreenX + 319).contains(p.x)
            let insideY = (level.minimumScreenY...level.maximumScreenY + 159).contains(p.y)
            guard insideX, insideY, !p.fan || (p.x == p.fanX && p.y == p.fanY) else {
                throw Lemmings2WitnessError.pointerOutOfViewport(index)
            }
        }
        var command = 0, pointer = 0
        while !game.isComplete && game.tick <= expectedTicks {
            while pointer < pointers.count && pointers[pointer].tick == game.tick {
                let p = pointers[pointer]
                game.setAim(x: p.fan ? p.fanX : p.x, y: p.fan ? p.fanY : p.y, held: !p.fan)
                game.setFan(x: p.fanX, y: p.fanY, active: p.fan)
                pointer += 1
            }
            while command < inputs.count && inputs[command].tick == game.tick {
                let event = inputs[command]
                guard let slot = game.configuration.skills.firstIndex(
                    where: { $0.rawValue == event.skill }) else {
                    throw Lemmings2WitnessError.rejectedInput(command)
                }
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
            game.step()
        }
        guard command == inputs.count, pointer == pointers.count, game.didWin,
              game.saved == expectedSaved, game.tick == expectedTicks else {
            throw Lemmings2WitnessError.outcomeChanged(levelSHA256)
        }
        return .init(saved: game.saved, ticks: game.tick,
            medal: Lemmings2Campaign.medal(saved: game.saved, total: population,
                allowedLosses: level.allowedLossesForGold),
            stateHash: game.stateFingerprint)
    }
}
```

`Lemmings2Runtime` has no `stateFingerprint`. Add one in the same new file.
`pixels`, `supplies`, `lemmings` and `tick` are all `public private(set)` on
`Lemmings2Runtime`, so an extension outside the type can read them.

```swift
import CryptoKit

extension Lemmings2Runtime {
    /// A stable hash of the whole simulation state. Two runs of the same route
    /// must produce the same value.
    public var stateFingerprint: String {
        var hasher = SHA256()
        hasher.update(data: Data(pixels))
        for value in supplies { withUnsafeBytes(of: Int32(value)) { hasher.update(data: Data($0)) } }
        for lemming in lemmings {
            for value in [lemming.id, lemming.x, lemming.y, lemming.direction,
                          lemming.state.rawValue, lemming.age, lemming.fallDistance,
                          lemming.work, lemming.slider ? 1 : 0, lemming.skater ? 1 : 0,
                          lemming.iceDirection] {
                withUnsafeBytes(of: Int32(value)) { hasher.update(data: Data($0)) }
            }
        }
        withUnsafeBytes(of: Int32(tick)) { hasher.update(data: Data($0)) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
```

`State` must expose `rawValue`. Confirm with
`grep -n "enum State" Sources/NxlvKit/Lemmings2Runtime.swift`. If it has no raw
type, add `: Int` to its declaration.

- [ ] **Step 4: Replace the inline block in the test file**

In `Tests/Lemmings2RuntimeTests/main.swift`, delete the local `struct Replay`
(line 1465) and replace the replay loop body (lines 1534-1562) with a call:

```swift
let witness = try JSONDecoder().decode(Lemmings2ReplayWitness.self, from: Data(contentsOf: url))
let outcome = try witness.run(level: level, style: style, masks: masks)
print("PASS \(name): \(outcome.saved) rescued, \(outcome.ticks) ticks, recorded pointer and skill inputs")
```

Keep the existing name, duplicate and fingerprint checks above it unchanged.

- [ ] **Step 5: Run the full suite**

Run: `zsh Scripts/run-lemmings2-runtime-tests.sh`
Expected: PASS, including the line `PASS 64 distinct recorded campaign level completions`
and the new `testWitnessRejectsOutOfOrderInputs`.

- [ ] **Step 6: Commit**

```bash
git add Sources/NxlvKit/Lemmings2ReplayWitness.swift Tests/Lemmings2RuntimeTests/main.swift
git commit -m "Share one Lemmings 2 replay witness between the suite and the gate"
```

---

### Task 2: Move the fixtures to their own test directory

**Files:**
- Move: `Tests/Lemmings2RuntimeTests/Fixtures/*.json` to `Tests/Lemmings2CompletionTests/Fixtures/`
- Modify: `Tests/Lemmings2RuntimeTests/main.swift:1512`, `:1571`

**Interfaces:**
- Consumes: Task 1's `Lemmings2ReplayWitness`.
- Produces: the path `Tests/Lemmings2CompletionTests/Fixtures`, which Tasks 3 to 6 read.

- [ ] **Step 1: Move the files with git**

```bash
mkdir -p Tests/Lemmings2CompletionTests
git mv Tests/Lemmings2RuntimeTests/Fixtures Tests/Lemmings2CompletionTests/Fixtures
ls Tests/Lemmings2CompletionTests/Fixtures | wc -l
```

Expected: `64`

- [ ] **Step 2: Run the suite and confirm it fails**

Run: `zsh Scripts/run-lemmings2-runtime-tests.sh`
Expected: FAIL. The suite cannot read the fixture directory.

- [ ] **Step 3: Update both fixture paths**

In `Tests/Lemmings2RuntimeTests/main.swift`, replace both occurrences of

```swift
URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("Fixtures")
```

with

```swift
URL(fileURLWithPath:#filePath).deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent("Lemmings2CompletionTests/Fixtures")
```

The second occurrence is inside the carry-over chain check and uses
`appendingPathComponent(String(format: "Fixtures/\(prefix)-%02d.json", number))`.
Change its prefix the same way.

- [ ] **Step 4: Run the suite**

Run: `zsh Scripts/run-lemmings2-runtime-tests.sh`
Expected: PASS with `PASS 64 distinct recorded campaign level completions`.

- [ ] **Step 5: Commit**

```bash
git add -A Tests/Lemmings2RuntimeTests Tests/Lemmings2CompletionTests
git commit -m "Keep Lemmings 2 route evidence in its own test directory"
```

---

### Task 3: Generate the committed manifest

**Files:**
- Create: `Tools/Lemmings2Completion/report.py`
- Create: `Documentation/Lemmings2Completion/evidence.json` (generated)

**Interfaces:**
- Consumes: `Tests/Lemmings2CompletionTests/Fixtures/*.json` from Task 2.
- Produces: `Documentation/Lemmings2Completion/evidence.json` with keys
  `schemaVersion`, `coverage`, `quality`, `chains`, `fixtures`.
  `report.py --check` exits non-zero on any difference.

- [ ] **Step 1: Write the generator**

Create `Tools/Lemmings2Completion/report.py`. It mirrors
`Tools/CampaignCompletion/report.py`, which is the pattern this repository already
uses.

```python
"""Manifest for preserved Lemmings 2 routes, independent of the runtime suite."""
from collections import Counter
from hashlib import sha256
import json
from pathlib import Path
import sys

project = Path(__file__).resolve().parents[2]
output = project / 'Documentation/Lemmings2Completion/evidence.json'
source = project / 'Tests/Lemmings2CompletionTests/Fixtures'
fixtures = []
for path in sorted(source.glob('*.json')):
    data = path.read_bytes()
    value = json.loads(data)
    tribe, number = path.stem.rsplit('-', 1)
    fixtures.append({'fixture': str(path.relative_to(project)),
                     'sha256': sha256(data).hexdigest(),
                     'tribe': tribe, 'level': int(number),
                     'levelSHA256': value['levelSHA256'],
                     'startingPopulation': value['population'],
                     'saved': value['expectedSaved'],
                     'ticks': value['expectedTicks']})
bare = sum(1 for f in fixtures if f['saved'] == 1)
manifest = {'schemaVersion': 1,
            'coverage': dict(Counter(f['tribe'] for f in fixtures)),
            'quality': {'bareSurvivals': bare},
            'fixtures': fixtures}
if '--check' in sys.argv:
    assert json.loads(output.read_text()) == manifest, \
        'Lemmings 2 fixtures changed, disappeared or lack a matching manifest.'
    print(f'PASS {len(fixtures)} Lemmings 2 fixture hashes and coverage manifest')
else:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(manifest['coverage']))
```

Medal counts and `chains` need the engine, so Task 6 adds them. Keep
`quality` limited to `bareSurvivals` until then.

- [ ] **Step 2: Generate and inspect the manifest**

```bash
python3 Tools/Lemmings2Completion/report.py
```

Expected: a JSON coverage line naming twelve tribes. Confirm the totals:

```bash
python3 -c "import json;d=json.load(open('Documentation/Lemmings2Completion/evidence.json'));print(len(d['fixtures']), sum(d['coverage'].values()), d['quality'])"
```

Expected: `64 64 {'bareSurvivals': 46}`

- [ ] **Step 3: Prove the check catches a changed fixture**

```bash
cp Tests/Lemmings2CompletionTests/Fixtures/beach-01.json /tmp/beach-01.bak
python3 -c "
import json,pathlib
p=pathlib.Path('Tests/Lemmings2CompletionTests/Fixtures/beach-01.json')
v=json.loads(p.read_text()); v['expectedSaved']=99
p.write_text(json.dumps(v,indent=1,sort_keys=True)+chr(10))"
python3 Tools/Lemmings2Completion/report.py --check; echo "exit=$?"
cp /tmp/beach-01.bak Tests/Lemmings2CompletionTests/Fixtures/beach-01.json
python3 Tools/Lemmings2Completion/report.py --check
```

Expected: the first check raises `AssertionError` with a non-zero exit. After the
restore, the check prints `PASS 64 Lemmings 2 fixture hashes and coverage manifest`.

- [ ] **Step 4: Commit**

```bash
git add Tools/Lemmings2Completion/report.py Documentation/Lemmings2Completion/evidence.json
git commit -m "Hash every Lemmings 2 route into a committed manifest"
```

---

### Task 4: Build the standalone gate tool

**Files:**
- Create: `Tools/Lemmings2Completion/main.swift`
- Create: `Scripts/verify-lemmings2-completion.sh`

**Interfaces:**
- Consumes: Task 1's `Lemmings2ReplayWitness.run`, Task 2's fixture directory.
- Produces: a binary accepting `verify-known` (default) and `verify`, plus the
  flag `--require-all`. Exit code 0 means every rule held.

- [ ] **Step 1: Write the tool**

Create `Tools/Lemmings2Completion/main.swift`:

```swift
import Foundation
import NxlvKit

let args = CommandLine.arguments
let root = URL(fileURLWithPath: args.count > 1 ? args[1]
    : ".build/local/Ultimate Lemmings.app/Contents/Resources/Ports/Lemm2")
let requireAll = args.contains("--require-all")
let fixtures = URL(fileURLWithPath: ProcessInfo.processInfo.environment["L2_COMPLETION_FIXTURES"]
    ?? "Tests/Lemmings2CompletionTests/Fixtures")

let campaign = try Lemmings2Campaign(root: root)
let masks = try Lemmings2TerrainMasks(root: root)
var verified = 0, missing: [String] = []
for index in 0..<120 {
    let level = campaign.levels[index]
    let prefix = level.style == 2 ? "cavelem" : Lemmings2Campaign.tribeNames[level.style].lowercased()
    let name = String(format: "\(prefix)-%02d", index % 10 + 1)
    let url = fixtures.appendingPathComponent(name + ".json")
    guard FileManager.default.fileExists(atPath: url.path) else { missing.append(name); continue }
    let witness = try JSONDecoder().decode(Lemmings2ReplayWitness.self, from: Data(contentsOf: url))
    let style = try Lemmings2Style(data: Data(contentsOf: root.appendingPathComponent(
        "STYLES/\(Lemmings2Campaign.styleNames[level.style]).DAT")))
    let first = try witness.run(level: level, style: style, masks: masks)
    let second = try witness.run(level: level, style: style, masks: masks)
    guard first.stateHash == second.stateHash, first.saved == second.saved else {
        print("FAIL \(name): the route is not deterministic")
        exit(1)
    }
    print("PASS \(name): \(first.saved)/\(witness.population) \(first.medal.name) in \(first.ticks) ticks")
    verified += 1
}
print("Verified \(verified); missing \(missing.count).")
if requireAll && !missing.isEmpty {
    print("MISSING \(missing.joined(separator: ", "))")
    exit(1)
}
```

`Lemmings2TerrainMasks(root:)` is the initialiser the runtime suite already uses
at `Tests/Lemmings2RuntimeTests/main.swift:1416`. The call above matches it.

- [ ] **Step 2: Write the script**

Create `Scripts/verify-lemmings2-completion.sh`, modelled on
`Scripts/verify-campaign-completion.sh`:

```zsh
#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/l2-completion"
ports="$project_dir/.build/local/Ultimate Lemmings.app/Contents/Resources/Ports/Lemm2"
mkdir -p "$build_dir/modules"
cd "$project_dir"
python3 Tools/Lemmings2Completion/report.py --check
swiftc -O -swift-version 6 -warnings-as-errors -parse-as-library \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" Sources/NxlvKit/*.swift
swiftc -O -swift-version 6 -warnings-as-errors \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  Tools/Lemmings2Completion/main.swift -o "$build_dir/verify"
"$build_dir/verify" "$ports" "$@"
```

Then: `chmod +x Scripts/verify-lemmings2-completion.sh`

- [ ] **Step 3: Run the gate**

Run: `zsh Scripts/verify-lemmings2-completion.sh`
Expected: 64 `PASS` lines, then `Verified 64; missing 56.` Exit code 0.

- [ ] **Step 4: Run the gate in strict mode**

Run: `zsh Scripts/verify-lemmings2-completion.sh --require-all; echo "exit=$?"`
Expected: the same 64 passes, a `MISSING` line naming 56 levels, and `exit=1`.

- [ ] **Step 5: Commit**

```bash
git add Tools/Lemmings2Completion/main.swift Scripts/verify-lemmings2-completion.sh
git commit -m "Add a standalone Lemmings 2 completion gate"
```

---

### Task 5: Prove the gate rejects damaged evidence

**Files:**
- Create: `Tests/Lemmings2CompletionTests/negative.swift`
- Modify: `Scripts/verify-lemmings2-completion.sh` (add a `--negative` mode)

**Interfaces:**
- Consumes: Task 1's `Lemmings2WitnessError`, Task 4's tool.
- Produces: a `--negative` run that damages one field at a time and requires a
  failure for each.

- [ ] **Step 1: Write the negative cases**

Create `Tests/Lemmings2CompletionTests/negative.swift`. Each case copies a good
fixture, damages one field, and requires a throw.

```swift
import Foundation
import NxlvKit

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1]
    : ".build/local/Ultimate Lemmings.app/Contents/Resources/Ports/Lemm2")
let campaign = try Lemmings2Campaign(root: root)
let masks = try Lemmings2TerrainMasks(root: root)
let good = URL(fileURLWithPath: "Tests/Lemmings2CompletionTests/Fixtures/beach-01.json")
let base = try JSONSerialization.jsonObject(with: Data(contentsOf: good)) as! [String: Any]
let level = campaign.levels.first { $0.fingerprint == base["levelSHA256"] as! String }!
let style = try Lemmings2Style(data: Data(contentsOf: root.appendingPathComponent(
    "STYLES/\(Lemmings2Campaign.styleNames[level.style]).DAT")))

/// Damages one field of a good route and requires the gate to reject it.
func expectFailure(_ label: String, _ change: (inout [String: Any]) -> Void) {
    var damaged = base
    change(&damaged)
    do {
        let data = try JSONSerialization.data(withJSONObject: damaged)
        let witness = try JSONDecoder().decode(Lemmings2ReplayWitness.self, from: data)
        _ = try witness.run(level: level, style: style, masks: masks)
        print("FAIL \(label): the gate accepted damaged evidence")
        exit(1)
    } catch {
        print("PASS \(label) rejected")
    }
}

expectFailure("changed starting population") { $0["population"] = 59 }
expectFailure("changed level hash") { $0["levelSHA256"] = String(repeating: "0", count: 64) }
expectFailure("changed saved count") { $0["expectedSaved"] = ($0["expectedSaved"] as! Int) + 1 }
expectFailure("changed tick count") { $0["expectedTicks"] = ($0["expectedTicks"] as! Int) + 1 }
expectFailure("rejected input") {
    var inputs = $0["inputs"] as! [[String: Any]]
    inputs[0]["skill"] = 999
    $0["inputs"] = inputs
}
expectFailure("out-of-order inputs") {
    var inputs = $0["inputs"] as! [[String: Any]]
    inputs.reverse()
    $0["inputs"] = inputs
}
expectFailure("pointer outside the viewport") {
    $0["pointers"] = [["tick": 0, "x": -9999, "y": -9999,
                       "fanX": -9999, "fanY": -9999, "fan": false]]
}
print("PASS seven damaged Lemmings 2 routes rejected")
```

`beach-01.json` has four inputs and an empty pointer list, so reversing the
inputs produces descending ticks and the pointer case starts from nothing.

The remaining two cases from the spec, a fixture with no manifest entry and a
manifest entry with no fixture, belong to the manifest rather than the engine.
Task 3 Step 3 already proves `report.py --check` catches both.

- [ ] **Step 2: Add the negative mode to the script**

In `Scripts/verify-lemmings2-completion.sh`, before the final `"$build_dir/verify"`
line, add:

```zsh
if [[ "${1:-}" == --negative ]]; then
  swiftc -O -swift-version 6 -warnings-as-errors \
    -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
    -Xlinker -rpath -Xlinker "$build_dir" \
    Tests/Lemmings2CompletionTests/negative.swift -o "$build_dir/negative"
  "$build_dir/negative" "$ports"
  exit $?
fi
```

- [ ] **Step 3: Run and confirm every case fails the gate**

Run: `zsh Scripts/verify-lemmings2-completion.sh --negative`
Expected: seven `PASS ... rejected` lines, then
`PASS seven damaged Lemmings 2 routes rejected`, and exit code 0.

- [ ] **Step 4: Prove the negative suite itself can fail**

Temporarily change one `expectFailure` body to a no-op, run the script, and
confirm it prints `FAIL` and exits non-zero. Restore the body afterwards.

- [ ] **Step 5: Commit**

```bash
git add Tests/Lemmings2CompletionTests/negative.swift Scripts/verify-lemmings2-completion.sh
git commit -m "Reject damaged Lemmings 2 route evidence"
```

---

### Task 6: Report medals and tribe chaining

**Files:**
- Modify: `Tools/Lemmings2Completion/main.swift`
- Modify: `Tools/Lemmings2Completion/report.py`
- Create: `Documentation/Lemmings2Completion/README.md`

**Interfaces:**
- Consumes: Task 4's tool, Task 3's manifest.
- Produces: `chains` and full `quality` counts in `evidence.json`, and a coverage
  document stating both.

- [ ] **Step 1: Add the chain rule to the tool**

A tribe chains when level 1 assumes 60, and every later level assumes a
population no greater than the saved count of the level before it. Add to
`Tools/Lemmings2Completion/main.swift`, after the verify loop:

```swift
var chains: [String: Bool] = [:]
for tribe in 0..<12 {
    let name = tribe == 2 ? "cavelem" : Lemmings2Campaign.tribeNames[tribe].lowercased()
    var expected = 60, ok = true
    for number in 1...10 {
        let url = fixtures.appendingPathComponent(String(format: "\(name)-%02d.json", number))
        guard let data = try? Data(contentsOf: url),
              let w = try? JSONDecoder().decode(Lemmings2ReplayWitness.self, from: data),
              w.population <= expected else { ok = false; break }
        expected = w.expectedSaved
    }
    chains[name] = ok
    print("CHAIN \(name): \(ok ? "chains" : "broken")")
}
```

- [ ] **Step 2: Run the tool and record the result**

Run: `zsh Scripts/verify-lemmings2-completion.sh`
Expected: twelve `CHAIN` lines. Every tribe reports `broken`, because no tribe
has all ten routes yet.

- [ ] **Step 3: Add chain status to the manifest**

Chain status needs no engine. It follows from the starting population and the
saved count, both of which the fixtures already hold. Medal counts do need the
engine, because gold depends on `level.allowedLossesForGold`. Medals therefore
stay in the tool output and the coverage document, not in the manifest.

In `Tools/Lemmings2Completion/report.py`, insert before the `manifest = {...}`
line:

```python
tribes = sorted({f['tribe'] for f in fixtures})
chains = {}
for tribe in tribes:
    routes = {f['level']: f for f in fixtures if f['tribe'] == tribe}
    expected, ok = 60, True
    for number in range(1, 11):
        route = routes.get(number)
        if route is None or route['startingPopulation'] > expected:
            ok = False
            break
        expected = route['saved']
    chains[tribe] = ok
```

Then add `'chains': chains,` to the `manifest` dictionary, directly after the
`'coverage'` entry.

- [ ] **Step 4: Regenerate and confirm the manifest agrees with the tool**

```bash
python3 Tools/Lemmings2Completion/report.py
python3 -c "import json;d=json.load(open('Documentation/Lemmings2Completion/evidence.json'));print(d['chains'])"
```

Expected: every tribe maps to `False`, matching the twelve `CHAIN ... broken`
lines from Step 2. If the two disagree, the rules have drifted. Fix the code, do
not edit the manifest by hand.

- [ ] **Step 5: Write the coverage document**

Create `Documentation/Lemmings2Completion/README.md`. State the counts plainly.
It must say all of this:

- 64 of 120 levels have a recorded route. 56 do not.
- 46 routes rescue exactly one lemming of sixty.
- Every winning route earns at least bronze, so a medal alone does not show a
  bare survival.
- No tribe chains all ten levels under the carry-over rule.
- Loading and rendering are separate checks. They do not prove a solution.

- [ ] **Step 6: Commit**

```bash
git add Tools/Lemmings2Completion Documentation/Lemmings2Completion
git commit -m "Report Lemmings 2 medals and tribe chaining"
```

---

### Task 7: Put the gate in the release register

**Files:**
- Modify: `Documentation/ReleaseReadiness/gates.json`
- Modify: `README.md` verification section

**Interfaces:**
- Consumes: Tasks 3 to 6.
- Produces: no code. The register names the new gate and its current result.

- [ ] **Step 1: Add the script to the README suite list**

In `README.md`, add `verify-lemmings2-completion` to the verification commands.

- [ ] **Step 2: Update the campaign gate progress**

In `Documentation/ReleaseReadiness/gates.json`, append to the progress field of
the gate named `All advertised campaign solutions`: the Lemmings 2 gate now runs
standalone, verifies 64 of 120 routes, counts 46 bare survivals, and reports no
chaining tribe.

- [ ] **Step 3: Run every affected check**

```bash
zsh Scripts/verify-lemmings2-completion.sh
zsh Scripts/run-lemmings2-runtime-tests.sh
python3 Tools/Lemmings2Completion/report.py --check
python3 -c "import json;json.load(open('Documentation/ReleaseReadiness/gates.json'))"
```

Expected: all four succeed.

- [ ] **Step 4: Commit**

```bash
git add README.md Documentation/ReleaseReadiness/gates.json
git commit -m "Register the Lemmings 2 completion gate"
```

---

## Out of scope for this plan

Each of these needs its own plan.

- **Native L2 achievement wiring.** `recordCompletion` in
  `Sources/LemmingsLocal/main.swift:2567` runs only on the Classic path, so
  `lemmings2Complete` is unreachable from native L2 play.
- **QoL and Hot Seat parity.** L2 lacks the paused keyboard overlay, the minimap,
  menu and text scaling, wide VoiceOver labelling, and the Hot Seat handover flow.
- **The stronger L2 solver.** The existing Classic solver found no new routes in
  a 40 minute run and marked two levels unverified.
- **The 56 missing routes.** The gate reports them. It does not find them.
