# Approaching-lemming click targeting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a click could hit more than one lemming, prefer the one still walking toward the click over one that already turned away, in Classic, Lemmings 2 and Lemmings 3, behind a new default-on setting.

**Architecture:** Each engine already narrows a click to eligible lemmings inside a small pick radius, then picks the nearest one by raw distance. Add one more tier to that choice, ahead of distance: among eligible in-range candidates, prefer whichever is still walking toward the click's x-position, using each engine's existing per-lemming facing field. Fall back to today's nearest-eligible result when no candidate is approaching.

**Tech Stack:** Swift 6, AppKit (macOS), the existing `NxlvKit` engine library and `LemmingsLocal` app target. Tests run through the project's own `swiftc`-based scripts in `Scripts/run-*.sh` (no XCTest, no `@testable import` — each script compiles the test's `main.swift` alongside the exact source files it needs).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-09-23-approaching-lemming-targeting-design.md`. Follow it exactly; this plan implements it task by task.
- Setting name: `favorApproachingLemmings`, a `Bool` on `ClassicSettings`, default `true`.
- Approaching formula: the click's x-position lies on the side of the lemming that matches its current facing. As a signed check against a lemming with position `x0` and a rightward-positive direction/facing value `d` (`d > 0` = facing right, `d < 0` or `facingLeft == true` = facing left): `(clickX - x0) * d >= 0`.
- Do not change pick-radius/hit-box sizes in any engine.
- Do not change `canAssign` / eligibility rules in any engine.
- Preserve Lemmings 3's existing `tool == nil` priority as the first tiebreak; approaching-preference is the second tier, distance the third.
- New parameters get default values that preserve today's exact behavior, so no unrelated call site (including existing tests) needs to change.
- UI copy for the new checkbox goes through the STE lint (`python3 ~/.claude/skills/ste-writing/ste-lint.py <file>`) before it's considered final, per the user's global writing-style rule.

---

### Task 1: Add the `favorApproachingLemmings` setting

**Files:**
- Modify: `Sources/NxlvKit/ClassicSettings.swift:158` (stored property), `:200` (init parameter), `:229` (init assignment), `:289` (decode fallback), `:321` (`applyExperiencePreset`)
- Test: `Tests/ClassicSettingsTests/main.swift` (`testOlderSettingsStillLoad`, `testHDEffectsPreference`)

**Interfaces:**
- Produces: `ClassicSettings.favorApproachingLemmings: Bool`, readable/writable by every later task, default `true`, folded into `applyExperiencePreset(modern:)`.

- [ ] **Step 1: Write the failing tests**

In `Tests/ClassicSettingsTests/main.swift`, inside `testOlderSettingsStillLoad` (starts at line 153), add a default-on assertion right after the other "missing setting" checks, and extend the round-trip section:

```swift
    try require(!restored.shuffleGraphics, "a missing setting should default to off")
    try require(!restored.shuffleMusic, "a missing setting should default to off")
    try require(restored.favorApproachingLemmings, "a missing setting should default to on")

    // And the new settings survive a round trip.
    var shuffled = restored
    shuffled.shuffleGraphics = true
    shuffled.shuffleMusic = true
    shuffled.favorApproachingLemmings = false
    let again = try JSONDecoder().decode(
        ClassicSettings.self, from: try JSONEncoder().encode(shuffled))
    try require(again.shuffleGraphics && again.shuffleMusic, "shuffle did not survive saving")
    try require(!again.favorApproachingLemmings, "favor-approaching did not survive saving")
    print("PASS settings written by an older build still load")
```

In the same file, inside `testHDEffectsPreference` (starts at line 212), extend the two multi-condition preset assertions:

```swift
    try require(!experience.pauseOnInterruption && !experience.modernControlsEnabled && !experience.variableSpeedEnabled && !experience.controllerEnabled && !experience.hdEffectsEnabled
      && !experience.confinePointer && !experience.fullScreenHDRFlashes && !experience.djIncludesOtherSoundtracks && !experience.favorApproachingLemmings,
      "OG did not disable the added conveniences together")
```

and:

```swift
    experience.applyExperiencePreset(modern: true)
    try require(experience.pauseOnInterruption && experience.modernControlsEnabled && experience.variableSpeedEnabled && experience.controllerEnabled && experience.hdEffectsEnabled
      && experience.confinePointer && experience.favorApproachingLemmings, "Modern defaults failed to restore the conveniences")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `Scripts/run-settings-tests.sh`
Expected: FAIL — `value of type 'ClassicSettings' has no member 'favorApproachingLemmings'`

- [ ] **Step 3: Add the setting**

In `Sources/NxlvKit/ClassicSettings.swift`, add the stored property right after line 158 (`public var pauseOnInterruption: Bool`):

```swift
    public var pauseOnInterruption: Bool
    public var favorApproachingLemmings: Bool
```

Add the init parameter right after `pauseOnInterruption: Bool = true,` (around line 200):

```swift
        pauseOnInterruption: Bool = true,
        favorApproachingLemmings: Bool = true,
```

Add the init assignment right after `self.pauseOnInterruption = pauseOnInterruption` (around line 229):

```swift
        self.pauseOnInterruption = pauseOnInterruption
        self.favorApproachingLemmings = favorApproachingLemmings
```

Add the decode fallback right after the `pauseOnInterruption = ...` decode line (around line 289):

```swift
        pauseOnInterruption = try values.decodeIfPresent(Bool.self, forKey: .pauseOnInterruption) ?? modernControlsEnabled
        favorApproachingLemmings = try values.decodeIfPresent(Bool.self, forKey: .favorApproachingLemmings) ?? fallback.favorApproachingLemmings
```

Add the preset wiring right after `pauseOnInterruption = modern` inside `applyExperiencePreset(modern:)` (around line 321):

```swift
        pauseOnInterruption = modern
        favorApproachingLemmings = modern
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `Scripts/run-settings-tests.sh`
Expected: every `PASS` line prints, script exits 0.

- [ ] **Step 5: Commit**

```bash
git add Sources/NxlvKit/ClassicSettings.swift Tests/ClassicSettingsTests/main.swift
git commit -m "$(cat <<'EOF'
Add the favorApproachingLemmings setting

A shared, default-on toggle every engine's click targeting reads next.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Classic — prefer the approaching lemming in `PlayfieldView.lemming(at:)`

**Files:**
- Modify: `Sources/LemmingsLocal/PlayfieldView.swift:96` (new property), `:432` (`lemming(at:)`)
- Test: `Tests/PlayfieldDrawTests/main.swift`

**Interfaces:**
- Consumes: `SessionLemming.facingLeft: Bool`, `SessionLemming.x/y: Int` (`GameSession.swift`); `session.canAssign(skillIndex:to:) -> Bool` (protocol extension, `GameSession.swift:77`).
- Produces: `PlayfieldView.favorApproachingLemmings: Bool` (default `true`), read by `main.swift` in Task 3.

- [ ] **Step 1: Write the failing test**

In `Tests/PlayfieldDrawTests/main.swift`, add a new fake session near `BombPreviewSession` (after its closing brace, before `testBombFlashFrames`):

```swift
private final class TargetingSession: GameSession {
  var actors: [SessionLemming] = []
  let levelWidth = 320, levelHeight = 160, ticksPerSecond = 17
  var lemmings: [SessionLemming] { actors }
  let entranceX: Int? = nil
  let released = 0, total = 0, saved = 0, required = 0, rate = 50
  let rateLabel = "Rate"
  let remainingSeconds: Int? = nil
  let isComplete = false, didWin = false, isNuking = false, canUndoNuke = false, supportsRewind = false
  let skills: [SessionSkill] = [], lastCues: [ClassicSoundEffect] = []
  var currentTick = 0
  func tick() {}
  func assign(skillIndex: Int, to lemmingID: Int) -> String? { nil }
  func assignmentState(skillIndex: Int, to lemmingID: Int) -> AssignmentState { .eligible }
  func adjustRate(by delta: Int) {}
  func nuke() {}
  func undoNuke() {}
  func rewind(seconds: Double) -> Bool { false }
  func stepBackward() -> Bool { false }
  func stepForward() -> Bool { false }
}

/// Lemming 1 is one pixel farther from the click than lemming 0, but it is
/// still walking toward the click while lemming 0 already turned away. The
/// setting should pick the farther, still-approaching lemming; turning the
/// setting off should restore plain nearest-distance picking.
@MainActor private func testApproachingLemmingPreferred() throws {
  let view = PlayfieldView(frame: NSRect(x: 0, y: 0, width: 640, height: 320))
  let session = TargetingSession()
  view.session = session
  session.actors = [
    .init(id: 0, x: 99, y: 80, pose: .walking, facingLeft: true, animationFrame: 0, countdown: nil),
    .init(id: 1, x: 98, y: 80, pose: .walking, facingLeft: false, animationFrame: 0, countdown: nil),
  ]
  view.favorApproachingLemmings = true
  try require(view.lemming(at: CGPoint(x: 100, y: 80))?.id == 1,
    "The approaching lemming should win over a closer one that already turned away")
  view.favorApproachingLemmings = false
  try require(view.lemming(at: CGPoint(x: 100, y: 80))?.id == 0,
    "Turning the setting off should restore plain nearest-distance picking")
  session.actors = [
    .init(id: 0, x: 99, y: 80, pose: .walking, facingLeft: true, animationFrame: 0, countdown: nil),
  ]
  view.favorApproachingLemmings = true
  try require(view.lemming(at: CGPoint(x: 100, y: 80))?.id == 0,
    "With no approaching candidate, targeting must fall back to the nearest eligible one")
  print("PASS approaching-lemming targeting prefers the one still walking toward the click")
}
```

Register the call in `run()`, right after `try testBombFlashFrames()`:

```swift
    try testBombFlashFrames()
    try testApproachingLemmingPreferred()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `Scripts/run-playfield-draw-tests.sh`
Expected: FAIL to build — `value of type 'PlayfieldView' has no member 'favorApproachingLemmings'`

- [ ] **Step 3: Implement the preference**

In `Sources/LemmingsLocal/PlayfieldView.swift`, add the stored property after the `reduceFlashes` block (around line 110):

```swift
  var reduceFlashes = false {
    didSet {
      if reduceFlashes { hdrBirths.removeAll(); hdrFlashes.removeAll(); hdrOverlay?.clear() }
      needsDisplay = true
    }
  }
  var favorApproachingLemmings = true
```

Replace `lemming(at:)` (around line 432):

```swift
  /// Both the green reticle and a fresh click use the nearest eligible lemming.
  func lemming(at point: CGPoint) -> SessionLemming? {
    guard let session else { return nil }
    let skill = selectedSkill()
    let candidates = session.lemmings.filter { contains($0, point) }.sorted {
      let a = distanceSquared($0, point), b = distanceSquared($1, point)
      return a == b ? $0.id > $1.id : a < b
    }
    let eligible = candidates.filter { session.canAssign(skillIndex: skill, to: $0.id) }
    if favorApproachingLemmings, let approaching = eligible.first(where: { isApproaching($0, point: point) }) {
      return approaching
    }
    return eligible.first
  }

  /// Whether `point` sits on the side of `lemming` that matches its facing.
  private func isApproaching(_ lemming: SessionLemming, point: CGPoint) -> Bool {
    let direction: CGFloat = lemming.facingLeft ? -1 : 1
    return (point.x - CGFloat(lemming.x)) * direction >= 0
  }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `Scripts/run-playfield-draw-tests.sh`
Expected: `PASS approaching-lemming targeting prefers the one still walking toward the click`, plus every other existing `PASS` line, script exits 0.

- [ ] **Step 5: Commit**

```bash
git add Sources/LemmingsLocal/PlayfieldView.swift Tests/PlayfieldDrawTests/main.swift
git commit -m "$(cat <<'EOF'
Classic: prefer the approaching lemming when a click is ambiguous

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Wire the setting through the Classic app and Settings UI

**Files:**
- Modify: `Sources/LemmingsLocal/main.swift:734-736` (`apply(_:)`), `:776-778` (`restoreSettings()`)
- Modify: `Sources/LemmingsLocal/SettingsWindow.swift:29-31` (new outlet), `:150-167` (`gameplayPane()`), `:399-447` (`rebuildSources()`)

**Interfaces:**
- Consumes: `PlayfieldView.favorApproachingLemmings` (Task 2), `ClassicSettings.favorApproachingLemmings` (Task 1).
- Produces: nothing further tasks depend on; this closes the loop from Settings UI to the playfield.

This task has no isolated automated test (it is wiring between already-tested pieces): verify it manually in Step 4, per `Documentation/UIPrinciples.md`'s "inspect actual renders" and "check mouse and keyboard hit regions" rules.

- [ ] **Step 1: Wire `main.swift`**

In `apply(_ updated: ClassicSettings)` (around line 734), add a line next to the other `playfield.*` assignments:

```swift
    playfield.reduceMotion = settings.reduceMotion
    playfield.reduceFlashes = settings.reduceFlashes
    playfield.hdEffectsEnabled = settings.hdEffectsEnabled
    playfield.favorApproachingLemmings = settings.favorApproachingLemmings
```

In `restoreSettings()` (around line 776), add the same line:

```swift
    playfield.reduceMotion = settings.reduceMotion
    playfield.reduceFlashes = settings.reduceFlashes
    playfield.hdEffectsEnabled = settings.hdEffectsEnabled
    playfield.favorApproachingLemmings = settings.favorApproachingLemmings
```

- [ ] **Step 2: Add the Settings checkbox**

In `Sources/LemmingsLocal/SettingsWindow.swift`, add a new outlet next to the others (around line 31):

```swift
  private var interruptionCheck: NSButton?
  private var favorApproachingCheck: NSButton?
```

In `gameplayPane()` (starts at line 150), add the checkbox and include it in the returned pane:

```swift
  private func gameplayPane() -> NSView {
    let modern = GameCheckButton(title: "Modern keyboard controls", target: self, action: #selector(modernControlsChanged))
    modernControlsCheck = modern
    let variable = GameCheckButton(title: "Variable speed: 2×, 3×, 5×, 10×", target: self, action: #selector(variableSpeedChanged))
    variableSpeedCheck = variable
    let interruption = GameCheckButton(title: "Pause when switching apps or a controller disconnects", target: self, action: #selector(interruptionChanged))
    interruption.state = settings.pauseOnInterruption ? .on : .off
    interruptionCheck = interruption
    let favorApproaching = GameCheckButton(title: "Favor lemmings still approaching", target: self, action: #selector(favorApproachingChanged))
    favorApproaching.toolTip = "When a click could match more than one lemming, choose the one still walking toward it over one that has already turned away."
    favorApproaching.state = settings.favorApproachingLemmings ? .on : .off
    favorApproachingCheck = favorApproaching
    variable.toolTip = SpeedPanelControls.help
    let og = GameButton(title: "Use OG settings", target: self, action: #selector(useOGSettings))
    let defaults = GameButton(title: "Use modern defaults", target: self, action: #selector(useModernDefaults))
    let buttons = NSStackView(views: [og, defaults]); buttons.orientation = .horizontal; buttons.spacing = 16
    og.toolTip = "Restore fixed fast-forward, number keys and original presentation. Saves and volume choices stay as set."
    modern.state = settings.modernControlsEnabled ? .on : .off
    variable.state = settings.variableSpeedEnabled ? .on : .off
    variable.isEnabled = settings.modernControlsEnabled
    return pane([("Controls", modern), ("Speed", variable), ("Pause", interruption), ("Targeting", favorApproaching), ("Experience", buttons)])
  }

  @objc private func favorApproachingChanged(_ sender: NSButton) {
    settings.favorApproachingLemmings = sender.state == .on
    changed()
  }
```

In `rebuildSources()`, add a refresh line next to `interruptionCheck?.state = ...` (around line 430):

```swift
    interruptionCheck?.state = settings.pauseOnInterruption ? .on : .off
    favorApproachingCheck?.state = settings.favorApproachingLemmings ? .on : .off
```

- [ ] **Step 3: Build**

Run: `Scripts/build-local-app.sh` (or the project's usual local build command)
Expected: build succeeds with no new warnings.

- [ ] **Step 4: Manual verification**

1. Launch the built app, open Settings → Gameplay.
2. Confirm "Favor lemmings still approaching" appears next to "Pause when switching apps…", is on by default, and its tooltip reads as written above.
3. Toggle it off and back on; confirm the state persists after closing and reopening Settings.
4. Click "Use OG settings"; confirm the checkbox turns off. Click "Use modern defaults"; confirm it turns back on.
5. Quit and relaunch the app; confirm the last-chosen state survived.

- [ ] **Step 5: Run the STE lint on the new copy**

Run: `python3 ~/.claude/skills/ste-writing/ste-lint.py <(echo 'Favor lemmings still approaching. When a click could match more than one lemming, choose the one still walking toward it over one that has already turned away.')`
Expected: no long sentences, no passive voice, no banned words. Adjust the checkbox title/tooltip in `SettingsWindow.swift` if it flags anything, then repeat Step 4.

- [ ] **Step 6: Commit**

```bash
git add Sources/LemmingsLocal/main.swift Sources/LemmingsLocal/SettingsWindow.swift
git commit -m "$(cat <<'EOF'
Classic: add a Settings toggle for approaching-lemming targeting

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Lemmings 2 — prefer the approaching lemming in `target(slot:x:y:)`

**Files:**
- Modify: `Sources/NxlvKit/Lemmings2Runtime.swift:486` (`target(slot:x:y:)`)
- Modify: `Sources/LemmingsLocal/Lemmings2PlayWindow.swift:629` (call site)
- Test: `Tests/Lemmings2RuntimeTests/main.swift`

**Interfaces:**
- Consumes: `Lemmings2Runtime.Lemming.direction: Int` (`+1` = facing right, `-1` = facing left; `Lemmings2Runtime.swift:73`), `Lemmings2Runtime.canAssign(slot:to:) -> Bool` (`:450`).
- Produces: `Lemmings2Runtime.target(slot:x:y:preferApproaching:) -> Lemming?`, new fourth parameter defaults to `false` so every existing call site (including the four already in this test file) keeps compiling unchanged.

- [ ] **Step 1: Write the failing test**

In `Tests/Lemmings2RuntimeTests/main.swift`, add a new top-level function (near `fixture(wall:)`, after its closing brace):

```swift
func testFavorApproachingLemming() throws {
    let width = 120, height = 80
    var pixels = [UInt8](repeating: 0, count: width * height)
    var solid = [Bool](repeating: false, count: width * height)
    for y in 60..<height { for x in 0..<width { solid[y * width + x] = true; pixels[y * width + x] = 6 } }
    for y in 20..<60 { for x in 50..<56 { solid[y * width + x] = true; pixels[y * width + x] = 6 } }
    let c = try fixture().configuration
    var game = try Lemmings2Runtime(configuration: .init(width: width, height: height, pixels: pixels, solid: solid,
        palette: c.palette, entrance: .init(x: 20, y: 45, width: 1, height: 1),
        exits: [.init(x: 90, y: 50, width: 16, height: 16)], skills: c.skills, supplies: c.supplies, total: 2,
        timeLimit: 120, releaseInterval: 1, terrainMasks: c.terrainMasks, firstReleaseTick: 1))
    while !(game.lemmings.count == 2 && game.lemmings.contains(where: { $0.direction < 0 })) { game.step() }
    guard let turned = game.lemmings.first(where: { $0.direction < 0 }),
        let approaching = game.lemmings.first(where: { $0.direction > 0 }) else {
        check(false, "Expected one turned lemming and one still approaching the wall"); return
    }
    check(approaching.x < turned.x, "The trailing lemming should not yet have reached the wall")
    let slot = c.skills.firstIndex(of: .climber)!
    check(game.target(slot: slot, x: turned.x, y: turned.y - 5, preferApproaching: true)?.id == approaching.id,
        "favorApproachingLemmings should target the lemming still walking toward the wall")
    check(game.target(slot: slot, x: turned.x, y: turned.y - 5)?.id == turned.id,
        "Plain nearest-distance targeting should keep choosing the closer, already-turned lemming")
    print("PASS favorApproachingLemmings prefers the lemming still walking toward the wall")
}
```

Find where the file's other top-level `test...()` functions are invoked (search for a `run()`-style dispatch or a flat sequence of `try test...()` calls near the bottom of the file, matching how `testFavorApproachingLemming` should be called), and add:

```swift
try testFavorApproachingLemming()
```

alongside them.

- [ ] **Step 2: Run the test to verify it fails**

Run: `Scripts/run-lemmings2-runtime-tests.sh`
Expected: FAIL to build — `extra argument 'preferApproaching' in call`

- [ ] **Step 3: Implement the preference**

In `Sources/NxlvKit/Lemmings2Runtime.swift`, replace `target(slot:x:y:)` (around line 486):

```swift
    /// Hover and click use the same stable, eligible-first target selection.
    public func target(slot: Int, x: Int, y: Int, preferApproaching: Bool = false) -> Lemming? {
        lemmings.filter { $0.active && $0.state != .exiting && $0.state != .exploding &&
            abs($0.x - x) <= 9 && abs($0.y - 5 - y) <= 12 }.min { a, b in
                let eligibleA = canAssign(slot: slot, to: a.id), eligibleB = canAssign(slot: slot, to: b.id)
                if eligibleA != eligibleB { return eligibleA }
                if preferApproaching, eligibleA, eligibleB {
                    let approachingA = (x - a.x) * a.direction >= 0, approachingB = (x - b.x) * b.direction >= 0
                    if approachingA != approachingB { return approachingA }
                }
                let da = abs(a.x - x) + abs(a.y - 5 - y), db = abs(b.x - x) + abs(b.y - 5 - y)
                return da == db ? a.id < b.id : da < db
            }
    }
```

In `Sources/LemmingsLocal/Lemmings2PlayWindow.swift`, update the call site inside `assign(_:_:)` (around line 629):

```swift
        if !fanSelected, let lem = game?.target(slot: selected, x: x, y: y, preferApproaching: audioSettings.favorApproachingLemmings) {
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `Scripts/run-lemmings2-runtime-tests.sh`
Expected: `PASS favorApproachingLemmings prefers the lemming still walking toward the wall`, plus every other existing `PASS` line, script exits 0.

- [ ] **Step 5: Commit**

```bash
git add Sources/NxlvKit/Lemmings2Runtime.swift Sources/LemmingsLocal/Lemmings2PlayWindow.swift Tests/Lemmings2RuntimeTests/main.swift
git commit -m "$(cat <<'EOF'
Lemmings 2: prefer the approaching lemming when a click is ambiguous

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Lemmings 3 — extract a testable targeting helper and use it

**Files:**
- Create: `Sources/LemmingsLocal/Lemmings3Targeting.swift`
- Create: `Tests/Lemmings3TargetingTests/main.swift`
- Create: `Scripts/run-lemmings3-targeting-tests.sh`
- Modify: `Sources/LemmingsLocal/Lemmings3PlayWindow.swift:463` (`assign(x:y:)`)

**Interfaces:**
- Consumes: `Lemmings3Runtime.Lemming.{id,x,y,direction,tool,active}` (all `public`, `Lemmings3Runtime.swift:68-89`), `Lemmings3Runtime.Tool` (public enum).
- Produces: `Lemmings3TargetCandidate` (a plain, publicly-constructible struct) and `Lemmings3Targeting.nearest(among:x:y:selected:favorApproaching:) -> Lemmings3TargetCandidate?`, both usable from tests without AppKit or a running `Lemmings3Runtime`.

`Lemmings3Runtime.Lemming` has no public initializer (only its `NxlvKit`-internal memberwise one), so a test cannot build one directly. `Lemmings3TargetCandidate` is a small, local, freely-constructible stand-in carrying only what targeting needs — this is what makes the decision testable without an AppKit window or a full running game.

- [ ] **Step 1: Write the failing test**

Create `Tests/Lemmings3TargetingTests/main.swift`:

```swift
import Foundation
import NxlvKit

private struct Failure: Error, CustomStringConvertible { let description: String }

private func require(
    _ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String
) throws {
    guard condition() else { throw Failure(description: message()) }
}

/// The turned lemming sits closer to the click but already faces away from
/// it. The approaching lemming is one step behind, still walking toward it.
private func testApproachingLemmingPreferred() throws {
    let turned = Lemmings3TargetCandidate(id: 0, x: 50, y: 40, direction: -1, tool: nil, active: true)
    let approaching = Lemmings3TargetCandidate(id: 1, x: 48, y: 40, direction: 1, tool: nil, active: true)

    let favored = Lemmings3Targeting.nearest(
        among: [turned, approaching], x: 52, y: 40, selected: 0, favorApproaching: true)
    try require(favored?.id == approaching.id,
        "favorApproaching should pick the lemming still walking toward the click")

    let plain = Lemmings3Targeting.nearest(
        among: [turned, approaching], x: 52, y: 40, selected: 0, favorApproaching: false)
    try require(plain?.id == turned.id,
        "Without the setting, nearest-distance picking should keep choosing the turned lemming")

    let onlyTurned = Lemmings3Targeting.nearest(
        among: [turned], x: 52, y: 40, selected: 0, favorApproaching: true)
    try require(onlyTurned?.id == turned.id,
        "With no approaching candidate, targeting should fall back to the nearest one")

    print("PASS Lemmings 3 targeting prefers the lemming still walking toward the click")
}

do {
    try testApproachingLemmingPreferred()
    print("Lemmings 3 targeting tests passed.")
} catch {
    FileHandle.standardError.write(Data("Lemmings 3 targeting tests failed: \(error)\n".utf8))
    exit(1)
}
```

Create `Scripts/run-lemmings3-targeting-tests.sh` (mirrors `Scripts/run-classic-settings-tests.sh`, adding the one extra source file):

```bash
#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/lemmings3-targeting-tests"
mkdir -p "$build_dir/modules"
swiftc -swift-version 6 -warnings-as-errors -parse-as-library \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" "$project_dir"/Sources/NxlvKit/*.swift
swiftc -swift-version 6 -warnings-as-errors \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  -o "$build_dir/Lemmings3TargetingTests" \
  "$project_dir/Sources/LemmingsLocal/Lemmings3Targeting.swift" \
  "$project_dir/Tests/Lemmings3TargetingTests/main.swift"
"$build_dir/Lemmings3TargetingTests"
```

```bash
chmod +x Scripts/run-lemmings3-targeting-tests.sh
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `Scripts/run-lemmings3-targeting-tests.sh`
Expected: FAIL to build — `cannot find 'Lemmings3TargetCandidate' in scope`

- [ ] **Step 3: Create the targeting helper**

Create `Sources/LemmingsLocal/Lemmings3Targeting.swift`:

```swift
import NxlvKit

/// One lemming as the click-targeting decision needs to see it.
///
/// `Lemmings3Runtime.Lemming` has no public initializer, so this local,
/// freely-constructible shape lets tests build fixtures directly.
struct Lemmings3TargetCandidate {
  let id: Int
  let x: Int
  let y: Int
  let direction: Int
  let tool: Lemmings3Runtime.Tool?
  let active: Bool
}

/// Picks which lemming a click or hover point resolves to.
///
/// `Lemmings3PlayWindow.assign(x:y:)` calls this, so hover and click agree.
/// Pulling the decision out here lets it run without an AppKit window.
enum Lemmings3Targeting {
  static func nearest(
    among candidates: [Lemmings3TargetCandidate], x: Int, y: Int,
    selected: Int, favorApproaching: Bool
  ) -> Lemmings3TargetCandidate? {
    let nearby = candidates.filter { $0.active && abs($0.x - x) <= 9 && abs($0.y - 8 - y) <= 12 }
    return nearby.min(by: {
      if selected >= 3, ($0.tool == nil) != ($1.tool == nil) { return $0.tool != nil }
      if favorApproaching {
        let approachingA = (x - $0.x) * $0.direction >= 0
        let approachingB = (x - $1.x) * $1.direction >= 0
        if approachingA != approachingB { return approachingA }
      }
      return abs($0.x - x) + abs($0.y - 8 - y) < abs($1.x - x) + abs($1.y - 8 - y)
    })
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `Scripts/run-lemmings3-targeting-tests.sh`
Expected: `PASS Lemmings 3 targeting prefers the lemming still walking toward the click`, script exits 0.

- [ ] **Step 5: Use the helper from `Lemmings3PlayWindow.assign(x:y:)`**

In `Sources/LemmingsLocal/Lemmings3PlayWindow.swift`, replace `assign(x:y:)` (around line 463):

```swift
    private func assign(x: Int, y: Int) {
        let candidates = game.lemmings.map {
            Lemmings3TargetCandidate(id: $0.id, x: $0.x, y: $0.y, direction: $0.direction, tool: $0.tool, active: $0.active)
        }
        guard let picked = Lemmings3Targeting.nearest(among: candidates, x: x, y: y, selected: selected,
            favorApproaching: audioSettings.favorApproachingLemmings) else { return }
        if selected == 3 && (picked.tool == .bricks || picked.tool == .spade) {
            pendingTool = picked.id
            canvas.directionPoint = CGPoint(x: picked.x, y: picked.y)
            canvas.needsDisplay = true
            return
        }
        applyAction(to: picked.id, direction: .right)
    }
```

- [ ] **Step 6: Rebuild and run the existing Lemmings 3 test suites to confirm nothing regressed**

Run: `Scripts/run-lemmings3-runtime-tests.sh`
Expected: all existing `PASS` lines, script exits 0. (This suite exercises `Lemmings3Runtime` directly and does not touch `assign(x:y:)`, so it is a regression check, not new coverage for this change.)

Run: `Scripts/build-local-app.sh` (or the project's usual local build command)
Expected: build succeeds with no new warnings, confirming `Lemmings3PlayWindow.swift` still compiles against the new helper.

- [ ] **Step 7: Commit**

```bash
git add Sources/LemmingsLocal/Lemmings3Targeting.swift Sources/LemmingsLocal/Lemmings3PlayWindow.swift \
  Tests/Lemmings3TargetingTests/main.swift Scripts/run-lemmings3-targeting-tests.sh
git commit -m "$(cat <<'EOF'
Lemmings 3: extract a testable targeting helper and prefer the approaching lemming

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Cross-engine manual verification

**Files:** none (manual QA only, per `Documentation/UIPrinciples.md` and the AGENTS.md cross-game-parity rule)

- [ ] **Step 1: Run every touched automated suite once more, back to back**

```bash
Scripts/run-settings-tests.sh
Scripts/run-playfield-draw-tests.sh
Scripts/run-lemmings2-runtime-tests.sh
Scripts/run-lemmings3-targeting-tests.sh
Scripts/run-lemmings3-runtime-tests.sh
```

Expected: every script exits 0.

- [ ] **Step 2: Manual check, Classic**

Load a level with two lemmings close together near a wall (or wait for two walkers to bunch up at one). With "Favor lemmings still approaching" on, click near the pair right as one turns around; confirm the skill lands on the one still facing the wall. Turn the setting off and repeat; confirm the old nearest-pixel behavior returns.

- [ ] **Step 3: Manual check, Lemmings 2**

Same check, in a Lemmings 2 level with a wall close to the entrance. Confirm hover highlight and the actual click agree in both settings states.

- [ ] **Step 4: Manual check, Lemmings 3**

Same check, in a Lemmings 3 level. Also confirm the existing "brick/spade direction picker" flow (the `pendingTool` path in `assign(x:y:)`) still opens correctly for a builder/digger tool, since Task 5 changed how that function picks its lemming.

- [ ] **Step 5: Record the result**

If every check passes, this plan is complete. If any engine-specific limitation turns up during manual testing (for example, a targeting edge case unique to one engine's collision rules), record it in `Documentation/` rather than silently dropping it, per the AGENTS.md cross-game-parity rule.
