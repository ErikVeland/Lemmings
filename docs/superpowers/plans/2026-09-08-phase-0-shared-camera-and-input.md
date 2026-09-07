# Phase 0: Shared Camera and Input Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the classic, Lemmings 2 and Lemmings 3 engines one camera type, one keymap, and a written record of where their shared mechanics diverge.

**Architecture:** Add one pure value type, `GameViewport`, to NxlvKit. It computes scale, widescreen extent, edge-scroll velocity, camera clamping and both coordinate conversions in simulation space. The three play windows delete their own camera code and construct one. A separate `GameKeyBinding` table replaces three hand-written key switches.

**Tech Stack:** Swift 6, AppKit, Swift Package Manager. Tests are standalone `swiftc` executables run by `zsh` scripts, not XCTest.

## Global Constraints

- Swift 6 language mode. Every test script uses `-swift-version 6 -warnings-as-errors`. Warnings fail the build.
- `GameViewport` imports `Foundation` only. It must not import AppKit or CoreGraphics. `Sources/NxlvKit/Lemmings2Viewport.swift` sets this precedent by importing nothing.
- Square pixels in all three engines. The `zoom * 1.2` factor is deleted, not made configurable.
- The viewport works in simulation pixels. Artwork resolution is a separate multiplier.
- No change may alter a simulation. If a replay test fails, the change reached the simulation and must be reverted.
- Target selection is input, not simulation. Task 8 records divergences. It changes no behavior.
- Execution happens in a git worktree. A peer session is editing `PlayfieldView.swift`, `Lemmings2PlayWindow.swift` and `Lemmings3PlayWindow.swift` in the main checkout.
- Line numbers in this plan are hints only. Anchor every edit on the quoted code, because the files move.
- The Macintosh 2x work for the sequels is already in the tree. `Sources/NxlvKit/Lemmings2MacArtwork.swift`, `Lemmings2MacRuleTables.swift` and `Tools/SequelMacArtwork/` exist. Do not change them. Phase 2 adopts them.

## Spec refinement

The spec lists `originY` as a letterbox offset. The decision that widescreen
expands on both axes removes the letterbox. Extra space on either axis becomes
more visible level. `originY` therefore collapses into `contentOffset`, which
still centers a level smaller than the view. This plan implements
`contentOffset` and no `originY`.

## File structure

| File | Responsibility |
| --- | --- |
| `Sources/NxlvKit/GameViewport.swift` | Create. All camera geometry. No AppKit |
| `Sources/NxlvKit/GameKeyBinding.swift` | Create. One key table for the three engines |
| `Tests/GameViewportTests/main.swift` | Create. Geometry tests |
| `Tests/GameKeyBindingTests/main.swift` | Create. Key table tests |
| `Scripts/run-game-viewport-tests.sh` | Create. Builds and runs both test executables |
| `Sources/NxlvKit/Lemmings2Viewport.swift` | Delete in Task 5 |
| `Sources/LemmingsLocal/PlayfieldView.swift` | Modify. Delete `Viewport` and `edgeScrollDelta` |
| `Sources/LemmingsLocal/Lemmings2PlayWindow.swift` | Modify. Delete local camera math and the 1.2 factor |
| `Sources/LemmingsLocal/Lemmings3PlayWindow.swift` | Modify. Delete local camera math, add the panel band |
| `Sources/LemmingsLocal/main.swift` | Modify. Route classic keys through the shared table |
| `Documentation/EngineDivergence.md` | Create in Task 8. The audit |

---

### Task 1: GameViewport scale, extent and conversions

**Files:**
- Create: `Sources/NxlvKit/GameViewport.swift`
- Create: `Tests/GameViewportTests/main.swift`
- Create: `Scripts/run-game-viewport-tests.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `GameViewport.Configuration` with fields `baseWidth`, `playfieldHeight`, `panelHeight`, `scaling`, `edgeBand`, `edgeSpeed`, `minimumZoom`, `maximumZoom`, `artworkScale`. `GameViewport.Scaling` with cases `fitToWindow` and `free(Double)`. `GameViewport.Point` with `x` and `y` of type `Double`. `GameViewport.init(configuration:viewWidth:viewHeight:)`. Read-only `scale`, `logicalWidth`, `logicalPlayfieldHeight`, `panelX`. Methods `snappedZoom(_:)`, `contentOffset(levelWidth:levelHeight:)`, `levelPoint(fromView:camera:levelWidth:levelHeight:)`, `viewPoint(fromLevel:camera:levelWidth:levelHeight:)`.

- [ ] **Step 1: Write the failing test**

Create `Tests/GameViewportTests/main.swift`:

```swift
import Foundation
import NxlvKit

func require(_ value: Bool, _ message: String) throws {
    if !value { throw SequelDataError.invalid(message) }
}

func near(_ a: Double, _ b: Double, _ tolerance: Double = 0.0001) -> Bool {
    abs(a - b) < tolerance
}

do {
    // A 320x200 game in a 1280x800 window fits at exactly 4x with nothing spare.
    var config = GameViewport.Configuration()
    config.playfieldHeight = 160
    config.panelHeight = 40
    let exact = GameViewport(configuration: config, viewWidth: 1280, viewHeight: 800)
    try require(near(exact.scale, 4), "exact fit scales to 4")
    try require(near(exact.logicalWidth, 320), "exact fit shows the base width")
    try require(near(exact.logicalPlayfieldHeight, 160), "exact fit shows the base playfield")
    try require(near(exact.panelX, 0), "exact fit centers the panel at zero")

    // A wide window keeps the same scale and shows more level sideways.
    let wide = GameViewport(configuration: config, viewWidth: 1920, viewHeight: 800)
    try require(near(wide.scale, 4), "a wide window keeps the height-limited scale")
    try require(near(wide.logicalWidth, 480), "a wide window widens the camera")
    try require(near(wide.logicalPlayfieldHeight, 160), "a wide window does not change playfield rows")
    try require(near(wide.panelX, 80), "the panel centers in the wider camera")

    // A tall window shows more level vertically. There is no letterbox.
    let tall = GameViewport(configuration: config, viewWidth: 1280, viewHeight: 1200)
    try require(near(tall.scale, 4), "a tall window keeps the width-limited scale")
    try require(near(tall.logicalWidth, 320), "a tall window does not widen the camera")
    try require(near(tall.logicalPlayfieldHeight, 260), "a tall window shows more playfield rows")
    print("PASS GameViewport widescreen extent on both axes")

    // Fit scale snaps down to whole device pixels, so leftover space shows level.
    let awkward = GameViewport(configuration: config, viewWidth: 1500, viewHeight: 900)
    try require(near(awkward.scale, 4), "1500x900 snaps 4.5 down to 4")
    try require(near(awkward.logicalWidth, 375), "the snapped scale widens the camera")

    // A window too small for one device pixel does not snap, so the base still fits.
    let tiny = GameViewport(configuration: config, viewWidth: 240, viewHeight: 150)
    try require(tiny.scale < 1, "a tiny window keeps a fractional scale")
    try require(near(tiny.logicalWidth, 320), "a tiny window still shows the base width")
    print("PASS GameViewport snaps fit scale to whole device pixels")

    // Free zoom clamps and snaps. 2x artwork allows half-step simulation zoom.
    var free = GameViewport.Configuration()
    free.scaling = .free(3.4)
    free.artworkScale = 1
    try require(near(GameViewport(configuration: free, viewWidth: 800, viewHeight: 600).scale, 3),
        "1x artwork snaps 3.4 to 3")
    free.scaling = .free(1.7)
    free.artworkScale = 2
    try require(near(GameViewport(configuration: free, viewWidth: 800, viewHeight: 600).scale, 1.5),
        "2x artwork snaps 1.7 to 1.5")
    free.scaling = .free(99)
    free.artworkScale = 1
    try require(near(GameViewport(configuration: free, viewWidth: 800, viewHeight: 600).scale, 8),
        "free zoom clamps to the maximum")
    print("PASS GameViewport zoom snapping and clamping")

    // A level smaller than the camera centers. A larger one does not offset.
    let small = GameViewport(configuration: config, viewWidth: 1920, viewHeight: 800)
    let centered = small.contentOffset(levelWidth: 320, levelHeight: 160)
    try require(near(centered.x, 80), "a narrow level centers horizontally")
    try require(near(centered.y, 0), "a level matching the playfield does not offset")
    let filled = small.contentOffset(levelWidth: 1600, levelHeight: 160)
    try require(near(filled.x, 0), "a wide level does not offset")
    print("PASS GameViewport centers small levels")

    // Migrated from Tests/Lemmings2ViewportTests, which Task 5 deletes.
    // The old code divided height by 240. This divides by 200 and snaps down.
    // Both give the same scale and camera width at these two sizes.
    let old43 = GameViewport(configuration: config, viewWidth: 960, viewHeight: 720)
    try require(near(old43.scale, 3), "960x720 still scales to 3")
    try require(near(old43.logicalWidth, 320), "960x720 still shows exactly the base width")
    try require(near(old43.panelX, 0), "960x720 still centers the panel at zero")
    let old169 = GameViewport(configuration: config, viewWidth: 1280, viewHeight: 720)
    try require(near(old169.scale, 3), "1280x720 still scales to 3")
    try require(near(old169.logicalWidth, 1280.0 / 3), "1280x720 still widens to 426.67")
    try require(near(old169.panelX * old169.scale, 160), "1280x720 still centers the panel at 160 points")
    print("PASS GameViewport keeps the Lemmings 2 viewport geometry")

    // View and level points round trip through the camera.
    let camera = GameViewport.Point(x: 100, y: 20)
    let round = small.levelPoint(fromView: GameViewport.Point(x: 640, y: 320),
        camera: camera, levelWidth: 1600, levelHeight: 400)
    let back = small.viewPoint(fromLevel: round, camera: camera, levelWidth: 1600, levelHeight: 400)
    try require(near(back.x, 640) && near(back.y, 320), "view and level points round trip")
    print("PASS GameViewport coordinate round trip")
} catch {
    print("FAIL \(error)")
    exit(1)
}
```

- [ ] **Step 2: Create the test script**

Create `Scripts/run-game-viewport-tests.sh`:

```sh
#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/game-viewport-tests"
mkdir -p "$build_dir/modules"
swiftc -swift-version 6 -warnings-as-errors -parse-as-library \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" \
  "$project_dir/Sources/NxlvKit/SequelBinary.swift" \
  "$project_dir/Sources/NxlvKit/GameViewport.swift" \
  "$project_dir/Sources/NxlvKit/GameKeyBinding.swift"
for suite in GameViewportTests GameKeyBindingTests; do
  if [[ -f "$project_dir/Tests/$suite/main.swift" ]]; then
    swiftc -swift-version 6 -warnings-as-errors \
      -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
      -Xlinker -rpath -Xlinker "$build_dir" \
      -o "$build_dir/$suite" "$project_dir/Tests/$suite/main.swift"
    "$build_dir/$suite"
  fi
done
```

Then make it executable:

```bash
chmod +x Scripts/run-game-viewport-tests.sh
```

Create an empty placeholder so the script compiles before Task 7:

```bash
mkdir -p Sources/NxlvKit && printf '// Filled in by Task 7.\n' > Sources/NxlvKit/GameKeyBinding.swift
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `zsh Scripts/run-game-viewport-tests.sh`
Expected: FAIL. The compiler reports `cannot find 'GameViewport' in scope`.

- [ ] **Step 4: Write the implementation**

Create `Sources/NxlvKit/GameViewport.swift`:

```swift
import Foundation

/// Camera geometry shared by the classic, Lemmings 2 and Lemmings 3 engines.
///
/// All values are simulation pixels. Artwork resolution is separate. The
/// Macintosh sets draw at 2x over a 1x collision mask, so drawing code applies
/// `artworkScale` on top of `scale`.
///
/// Extra window space becomes more visible level on both axes. There is no
/// letterbox. A level smaller than the camera centers through `contentOffset`.
public struct GameViewport: Sendable {
    public enum Scaling: Sendable {
        /// Scale so the authored window fits, then snap down to whole device pixels.
        case fitToWindow
        /// A caller-owned zoom, clamped to the configured limits and snapped.
        case free(Double)
    }

    public struct Configuration: Sendable {
        public var baseWidth = 320.0
        public var playfieldHeight = 160.0
        public var panelHeight = 0.0
        public var scaling = Scaling.fitToWindow
        public var edgeBand = 12.0
        public var edgeSpeed = 160.0
        public var minimumZoom = 0.5
        public var maximumZoom = 8.0
        /// Artwork pixels for each simulation pixel. The Macintosh sets use 2.
        public var artworkScale = 1.0
        public init() {}
    }

    public struct Point: Equatable, Sendable {
        public var x: Double
        public var y: Double
        public init(x: Double, y: Double) { self.x = x; self.y = y }
    }

    public let configuration: Configuration
    public let viewWidth: Double
    public let viewHeight: Double
    public let scale: Double

    public init(configuration: Configuration, viewWidth: Double, viewHeight: Double) {
        self.configuration = configuration
        self.viewWidth = max(1, viewWidth)
        self.viewHeight = max(1, viewHeight)
        switch configuration.scaling {
        case .fitToWindow:
            let base = configuration.playfieldHeight + configuration.panelHeight
            let fit = min(self.viewWidth / configuration.baseWidth,
                          self.viewHeight / max(1, base))
            // Snapping down only ever shows more level, so the base still fits.
            let device = fit * configuration.artworkScale
            scale = device >= 1 ? device.rounded(.down) / configuration.artworkScale : fit
        case .free(let zoom):
            scale = Self.snap(zoom, configuration)
        }
    }

    private static func snap(_ zoom: Double, _ configuration: Configuration) -> Double {
        let clamped = min(max(zoom, configuration.minimumZoom), configuration.maximumZoom)
        let device = clamped * configuration.artworkScale
        guard device >= 1 else { return 1 / configuration.artworkScale }
        return device.rounded() / configuration.artworkScale
    }

    /// Clamps and snaps a zoom without building a viewport.
    public func snappedZoom(_ zoom: Double) -> Double { Self.snap(zoom, configuration) }

    /// Simulation pixels visible across the camera. Never less than `baseWidth`.
    public var logicalWidth: Double { viewWidth / scale }

    /// Simulation rows of level visible above the panel band.
    public var logicalPlayfieldHeight: Double {
        max(0, viewHeight / scale - configuration.panelHeight)
    }

    /// Where the authored-width panel starts inside a wider camera.
    public var panelX: Double { (logicalWidth - configuration.baseWidth) / 2 }

    /// Centers a level that does not fill the camera.
    public func contentOffset(levelWidth: Double, levelHeight: Double) -> Point {
        Point(x: levelWidth < logicalWidth ? (logicalWidth - levelWidth) / 2 : 0,
              y: levelHeight < logicalPlayfieldHeight ? (logicalPlayfieldHeight - levelHeight) / 2 : 0)
    }

    public func levelPoint(fromView point: Point, camera: Point,
                           levelWidth: Double, levelHeight: Double) -> Point {
        let offset = contentOffset(levelWidth: levelWidth, levelHeight: levelHeight)
        return Point(x: camera.x + point.x / scale - offset.x,
                     y: camera.y + point.y / scale - offset.y)
    }

    public func viewPoint(fromLevel point: Point, camera: Point,
                          levelWidth: Double, levelHeight: Double) -> Point {
        let offset = contentOffset(levelWidth: levelWidth, levelHeight: levelHeight)
        return Point(x: (point.x - camera.x + offset.x) * scale,
                     y: (point.y - camera.y + offset.y) * scale)
    }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `zsh Scripts/run-game-viewport-tests.sh`
Expected: PASS on all five printed lines, ending with `PASS GameViewport coordinate round trip`.

- [ ] **Step 6: Commit**

```bash
git add Sources/NxlvKit/GameViewport.swift Sources/NxlvKit/GameKeyBinding.swift Tests/GameViewportTests/main.swift Scripts/run-game-viewport-tests.sh
git commit -m "Give the three engines one camera geometry"
```

---

### Task 2: Edge velocity

**Files:**
- Modify: `Sources/NxlvKit/GameViewport.swift`
- Modify: `Tests/GameViewportTests/main.swift`

**Interfaces:**
- Consumes: `GameViewport` from Task 1.
- Produces: `edgeVelocity(at:) -> Point`, returning simulation pixels per second for each axis. The argument is a point in camera space, where x runs `0 ..< logicalWidth` and y runs `0 ..< logicalPlayfieldHeight`.

> **Designated handoff.** The ramp curve is a feel decision, not a correctness
> one. The implementation below is a working linear ramp that satisfies the
> tests. The repository owner may replace the body of `ramp` with a different
> curve. The tests define the contract the replacement must keep: zero in the
> dead zone, negative near the low edge, positive near the high edge, and
> magnitude rising toward each edge.

- [ ] **Step 1: Write the failing test**

Append inside the `do` block of `Tests/GameViewportTests/main.swift`, before the closing brace:

```swift
    // Edge velocity: zero in the middle, signed and rising toward each edge.
    var edge = GameViewport.Configuration()
    edge.playfieldHeight = 160
    edge.panelHeight = 40
    edge.edgeBand = 12
    edge.edgeSpeed = 160
    let scroller = GameViewport(configuration: edge, viewWidth: 1280, viewHeight: 800)
    let middle = scroller.edgeVelocity(at: GameViewport.Point(x: 160, y: 80))
    try require(near(middle.x, 0) && near(middle.y, 0), "the dead zone does not scroll")

    let left = scroller.edgeVelocity(at: GameViewport.Point(x: 1, y: 80))
    let further = scroller.edgeVelocity(at: GameViewport.Point(x: 6, y: 80))
    try require(left.x < 0, "the low edge scrolls backward")
    try require(left.x < further.x, "speed rises closer to the edge")

    let right = scroller.edgeVelocity(at: GameViewport.Point(x: scroller.logicalWidth - 1, y: 80))
    try require(right.x > 0, "the high edge scrolls forward")
    try require(abs(right.x) <= edge.edgeSpeed, "speed never exceeds the configured maximum")

    let top = scroller.edgeVelocity(at: GameViewport.Point(x: 160, y: 1))
    let bottom = scroller.edgeVelocity(at: GameViewport.Point(x: 160, y: scroller.logicalPlayfieldHeight - 1))
    try require(top.y < 0 && bottom.y > 0, "both vertical edges scroll")

    let outside = scroller.edgeVelocity(at: GameViewport.Point(x: -5, y: 80))
    try require(near(outside.x, 0) && near(outside.y, 0), "a point outside the camera does not scroll")
    let panel = scroller.edgeVelocity(at: GameViewport.Point(x: 160, y: scroller.logicalPlayfieldHeight + 10))
    try require(near(panel.x, 0) && near(panel.y, 0), "the panel band does not scroll")
    // Migrated from Tests/Lemmings2ViewportTests. In a widescreen camera the
    // old 320-pixel boundary is ordinary level, not an edge.
    let widescreen = GameViewport(configuration: edge, viewWidth: 1280, viewHeight: 720)
    try require(widescreen.logicalWidth > 320, "the widescreen camera is wider than the base")
    try require(near(widescreen.edgeVelocity(at: GameViewport.Point(x: 320, y: 80)).x, 0),
        "the old 320-pixel boundary does not scroll")
    print("PASS GameViewport edge velocity")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `zsh Scripts/run-game-viewport-tests.sh`
Expected: FAIL. The compiler reports `value of type 'GameViewport' has no member 'edgeVelocity'`.

- [ ] **Step 3: Write the implementation**

Add to `Sources/NxlvKit/GameViewport.swift`, inside the `GameViewport` struct, after `viewPoint(fromLevel:camera:levelWidth:levelHeight:)`:

```swift
    /// Simulation pixels per second to scroll while the pointer rests near an edge.
    ///
    /// The point is in camera space. Points outside the playfield, including the
    /// panel band, do not scroll.
    public func edgeVelocity(at point: Point) -> Point {
        let height = logicalPlayfieldHeight
        guard point.x >= 0, point.x < logicalWidth, point.y >= 0, point.y < height else {
            return Point(x: 0, y: 0)
        }
        return Point(x: ramp(point.x, logicalWidth), y: ramp(point.y, height))
    }

    /// The speed curve across the edge band. Replace the body to change the feel.
    /// Keep the contract: zero in the dead zone, signed toward the nearer edge,
    /// magnitude rising toward it, never above `edgeSpeed`.
    private func ramp(_ coordinate: Double, _ extent: Double) -> Double {
        let band = min(configuration.edgeBand, extent / 2)
        guard band > 0 else { return 0 }
        if coordinate < band {
            return -configuration.edgeSpeed * (1 - coordinate / band)
        }
        if coordinate > extent - band {
            return configuration.edgeSpeed * (1 - (extent - coordinate) / band)
        }
        return 0
    }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `zsh Scripts/run-game-viewport-tests.sh`
Expected: PASS, ending with `PASS GameViewport edge velocity`.

- [ ] **Step 5: Commit**

```bash
git add Sources/NxlvKit/GameViewport.swift Tests/GameViewportTests/main.swift
git commit -m "Scroll the camera when the pointer nears an edge"
```

---

### Task 3: Camera clamping

**Files:**
- Modify: `Sources/NxlvKit/GameViewport.swift`
- Modify: `Tests/GameViewportTests/main.swift`

**Interfaces:**
- Consumes: `GameViewport` from Task 1.
- Produces: `clampCamera(_:levelWidth:levelHeight:authored:) -> Point`. The `authored` argument is `ClosedRange<Double>?`, the designer's horizontal limits in simulation pixels. Pass `nil` for classic and Lemmings 3.

- [ ] **Step 1: Write the failing test**

Append inside the `do` block of `Tests/GameViewportTests/main.swift`, before the closing brace:

```swift
    // Clamping keeps the camera inside the level.
    var clampConfig = GameViewport.Configuration()
    clampConfig.playfieldHeight = 160
    clampConfig.panelHeight = 40
    let clamper = GameViewport(configuration: clampConfig, viewWidth: 1920, viewHeight: 800)
    try require(near(clamper.logicalWidth, 480), "the clamp test camera is 480 wide")

    let low = clamper.clampCamera(GameViewport.Point(x: -50, y: -50),
        levelWidth: 1600, levelHeight: 400, authored: nil)
    try require(near(low.x, 0) && near(low.y, 0), "the camera does not go past the level origin")

    let high = clamper.clampCamera(GameViewport.Point(x: 9999, y: 9999),
        levelWidth: 1600, levelHeight: 400, authored: nil)
    try require(near(high.x, 1120), "the camera stops at level width minus camera width")
    try require(near(high.y, 240), "the camera stops at level height minus playfield height")

    // A level narrower than the camera pins to zero rather than going negative.
    let narrow = clamper.clampCamera(GameViewport.Point(x: 40, y: 0),
        levelWidth: 320, levelHeight: 160, authored: nil)
    try require(near(narrow.x, 0), "a narrow level pins the camera to zero")

    // Authored Lemmings 2 bounds shrink by the extra widescreen width.
    // Bounds 100...600 in a 480-wide camera allow 100 through 440.
    let authored = clamper.clampCamera(GameViewport.Point(x: 9999, y: 0),
        levelWidth: 1600, levelHeight: 400, authored: 100...600)
    try require(near(authored.x, 440), "widescreen does not scroll past an authored limit")
    let authoredLow = clamper.clampCamera(GameViewport.Point(x: 0, y: 0),
        levelWidth: 1600, levelHeight: 400, authored: 100...600)
    try require(near(authoredLow.x, 100), "the authored left limit holds")
    print("PASS GameViewport camera clamping")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `zsh Scripts/run-game-viewport-tests.sh`
Expected: FAIL. The compiler reports `value of type 'GameViewport' has no member 'clampCamera'`.

- [ ] **Step 3: Write the implementation**

Add to `Sources/NxlvKit/GameViewport.swift`, inside the struct, after `edgeVelocity(at:)`:

```swift
    /// Keeps the camera inside the level, and inside authored limits when given.
    ///
    /// Lemmings 2 levels carry horizontal limits the designer set for a
    /// 320-pixel window. A wider camera must not reveal level past that limit,
    /// so the right limit loses the extra width.
    public func clampCamera(_ camera: Point, levelWidth: Double, levelHeight: Double,
                            authored: ClosedRange<Double>? = nil) -> Point {
        var left = 0.0
        var right = max(0, levelWidth - logicalWidth)
        if let authored {
            left = authored.lowerBound
            let extra = logicalWidth - configuration.baseWidth
            right = max(left, min(right, authored.upperBound - extra))
        }
        let bottom = max(0, levelHeight - logicalPlayfieldHeight)
        return Point(x: min(max(camera.x, left), max(left, right)),
                     y: min(max(camera.y, 0), bottom))
    }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `zsh Scripts/run-game-viewport-tests.sh`
Expected: PASS, ending with `PASS GameViewport camera clamping`.

- [ ] **Step 5: Run the full regression pass**

```bash
zsh Scripts/run-swift-tests.sh
```

Expected: no new failures against the state before Task 1.

- [ ] **Step 6: Commit**

```bash
git add Sources/NxlvKit/GameViewport.swift Tests/GameViewportTests/main.swift
git commit -m "Clamp every camera by one rule"
```

---

### Task 4: Adopt the shared camera in the classic engine

**Files:**
- Modify: `Sources/LemmingsLocal/PlayfieldView.swift` (the `Viewport` struct at the top, and `edgeScrollDelta`)
- Modify: `Sources/LemmingsLocal/main.swift` (`applyEdgeScroll`)

**Interfaces:**
- Consumes: `GameViewport` and its `Configuration`, `Point`, `edgeVelocity(at:)`, `clampCamera(_:levelWidth:levelHeight:authored:)`, `contentOffset(levelWidth:levelHeight:)` from Tasks 1 to 3.
- Produces: `Viewport` keeps every member it has today: `scrollX`, `scrollY`, `zoom`, `levelSize`, `viewSize`, `visibleSize`, `maximumScrollX`, `maximumScrollY`, `clamp()`, `scroll(dx:dy:)`, `center(on:)`, `contentOffset`, `levelPoint(from:)`, `viewPoint(fromLevel:)`, `visibleLevelRect`. It gains `edgeVelocity(at:)`. `PlayfieldView.edgeScrollDelta` is replaced by `edgeScrollVelocity`, returning `CGPoint` in level pixels per second.

**Why an adapter.** `viewport` has 25 call sites in `PlayfieldView.swift` and 20 in
`main.swift`. Changing all 45 in one task would be unreviewable. Keep the member
names and replace the arithmetic underneath. The existing draw tests then prove
the swap did not change behavior.

- [ ] **Step 1: Run the existing tests to record the starting state**

```bash
zsh Scripts/run-playfield-draw-tests.sh
```

Expected: PASS. Write down the output. Task 4 must end with the same result.

- [ ] **Step 2: Replace the `Viewport` struct**

In `Sources/LemmingsLocal/PlayfieldView.swift`, replace the whole `struct Viewport { ... }` block. It starts at the line `struct Viewport {` near the top of the file, after the doc comment reading `/// Maps between level pixels and view points for a scrolled, zoomed playfield.`, and ends at the closing brace after `visibleLevelRect`. Replace it with:

```swift
/// Maps between level pixels and view points for a scrolled, zoomed playfield.
///
/// The arithmetic lives in `GameViewport`, which the three engines share. This
/// keeps the member names the drawing code already uses.
struct Viewport {
  var scrollX = 0.0
  var scrollY = 0.0
  var zoom = 3.0
  var levelSize = CGSize(width: 1, height: 1)
  var viewSize = CGSize(width: 1, height: 1)

  /// Classic draws its panel in a sibling view, so the camera reserves no band.
  private var shared: GameViewport {
    var configuration = GameViewport.Configuration()
    configuration.playfieldHeight = max(1, levelSize.height)
    configuration.panelHeight = 0
    configuration.scaling = .free(zoom)
    GameViewport(configuration: configuration,
      viewWidth: Double(viewSize.width), viewHeight: Double(viewSize.height))
  }

  var visibleSize: CGSize {
    let view = shared
    return CGSize(width: view.logicalWidth, height: view.logicalPlayfieldHeight)
  }

  var maximumScrollX: Double { max(0, levelSize.width - visibleSize.width) }
  var maximumScrollY: Double { max(0, levelSize.height - visibleSize.height) }

  mutating func clamp() {
    let clamped = shared.clampCamera(GameViewport.Point(x: scrollX, y: scrollY),
      levelWidth: Double(levelSize.width), levelHeight: Double(levelSize.height))
    scrollX = clamped.x
    scrollY = clamped.y
  }

  mutating func scroll(dx: Double, dy: Double) {
    scrollX += dx
    scrollY += dy
    clamp()
  }

  mutating func center(on x: Double) {
    scrollX = x - visibleSize.width / 2
    clamp()
  }

  /// Centers the level when it does not fill the view.
  var contentOffset: CGPoint {
    let offset = shared.contentOffset(levelWidth: Double(levelSize.width),
      levelHeight: Double(levelSize.height))
    return CGPoint(x: offset.x * shared.scale, y: offset.y * shared.scale)
  }

  /// Level pixels per second to scroll while the pointer rests near an edge.
  func edgeVelocity(at viewPoint: CGPoint) -> CGPoint {
    let view = shared
    let point = GameViewport.Point(x: Double(viewPoint.x) / view.scale,
      y: Double(viewPoint.y) / view.scale)
    let velocity = view.edgeVelocity(at: point)
    return CGPoint(x: velocity.x, y: velocity.y)
  }

  /// Converts a view point to level pixels. The view is flipped, so both
  /// coordinate systems increase downward.
  func levelPoint(from viewPoint: CGPoint) -> CGPoint {
    let point = shared.levelPoint(fromView: GameViewport.Point(x: Double(viewPoint.x), y: Double(viewPoint.y)),
      camera: GameViewport.Point(x: scrollX, y: scrollY),
      levelWidth: Double(levelSize.width), levelHeight: Double(levelSize.height))
    return CGPoint(x: point.x, y: point.y)
  }

  func viewPoint(fromLevel point: CGPoint) -> CGPoint {
    let converted = shared.viewPoint(fromLevel: GameViewport.Point(x: Double(point.x), y: Double(point.y)),
      camera: GameViewport.Point(x: scrollX, y: scrollY),
      levelWidth: Double(levelSize.width), levelHeight: Double(levelSize.height))
    return CGPoint(x: converted.x, y: converted.y)
  }

  var visibleLevelRect: CGRect {
    CGRect(x: scrollX, y: scrollY, width: visibleSize.width, height: visibleSize.height)
  }
}
```

- [ ] **Step 3: Replace `edgeScrollDelta`**

In the same file, find the computed property that starts with the comment
`/// Level pixels to scroll this frame when the cursor rests near an edge.` and
declares `var edgeScrollDelta: Double?`. Replace the whole property with:

```swift
  /// Level pixels per second to scroll while the cursor rests near an edge.
  ///
  /// The classic game scrolls while the cursor sits in the outer margin. The
  /// speed rises closer to the edge. The caller multiplies by elapsed time,
  /// so the speed no longer follows the frame rate.
  var edgeScrollVelocity: CGPoint? {
    guard let point = cursorViewPoint, bounds.width > 0, bounds.contains(point) else { return nil }
    let velocity = viewport.edgeVelocity(at: point)
    return velocity == .zero ? nil : velocity
  }
```

- [ ] **Step 4: Update the caller**

In `Sources/LemmingsLocal/main.swift`, replace the whole `applyEdgeScroll` method. It reads:

```swift
  private func applyEdgeScroll() {
    guard phase == .playing, let delta = playfield.edgeScrollDelta, delta != 0 else { return }
    playfield.viewport.scroll(dx: delta, dy: 0)
    playfield.needsDisplay = true
    syncPanelViewport()
  }
```

Replace it with:

```swift
  private func applyEdgeScroll(elapsed: Double) {
    guard phase == .playing, let velocity = playfield.edgeScrollVelocity else { return }
    let step = min(0.05, max(0, elapsed))
    playfield.viewport.scroll(dx: Double(velocity.x) * step, dy: Double(velocity.y) * step)
    playfield.needsDisplay = true
    syncPanelViewport()
  }
```

- [ ] **Step 5: Fix the call site**

Find the single call to `applyEdgeScroll()` in `main.swift`:

```bash
grep -n "applyEdgeScroll()" Sources/LemmingsLocal/main.swift
```

That call sits in the frame update, near the line `accumulator += elapsed * (isFastForward ? 3 : 1)`, where a local named `elapsed` already exists. Change the call to `applyEdgeScroll(elapsed: elapsed)`.

- [ ] **Step 6: Build and test**

```bash
zsh Scripts/run-playfield-draw-tests.sh && zsh Scripts/build-local-app.sh
```

Expected: the draw tests PASS with the same output recorded in Step 1, and the app builds with no warnings.

- [ ] **Step 7: Commit**

```bash
git add Sources/LemmingsLocal/PlayfieldView.swift Sources/LemmingsLocal/main.swift
git commit -m "Point the classic camera at the shared geometry"
```

---

### Task 5: Adopt the shared camera in Lemmings 2

**Files:**
- Delete: `Sources/NxlvKit/Lemmings2Viewport.swift`
- Modify: `Sources/LemmingsLocal/Lemmings2PlayWindow.swift`

**Interfaces:**
- Consumes: `GameViewport` from Tasks 1 to 3.
- Produces: the canvas keeps `zoom`, `visibleWidth`, `origin`, `panelX`, `advanceEdgeScrolling(elapsed:)`, `clampCamera()` and `pan(x:y:)`. `Lemmings2Viewport` no longer exists.

**The 1.2 factor.** Lemmings 2 draws with `zoom * 1.2`, which stretched 200
logical rows into a 240-row box. Square pixels remove it. Every `zoom * 1.2`
becomes `zoom`, and every `/ (zoom * 1.2)` becomes `/ zoom`. The window layout
goes from an effective 320x240 to 320x200 and looks squatter. That is the
recorded decision, not a defect.

- [ ] **Step 1: Count the sites to change**

```bash
grep -c "zoom \* 1.2" Sources/LemmingsLocal/Lemmings2PlayWindow.swift
grep -n "zoom \* 1.2" Sources/LemmingsLocal/Lemmings2PlayWindow.swift
```

Record both numbers. Step 4 verifies the count reaches zero.

- [ ] **Step 2: Replace the canvas viewport accessors**

In `Sources/LemmingsLocal/Lemmings2PlayWindow.swift`, find the block that reads:

```swift
    private var viewport: Lemmings2Viewport {
        Lemmings2Viewport(viewWidth: Double(bounds.width), viewHeight: Double(bounds.height))
    }
    private var zoom: CGFloat { CGFloat(viewport.scale) }
    private var visibleWidth: CGFloat { CGFloat(viewport.width) }
    private var origin: NSPoint { NSPoint(x: 0, y: viewport.originY) }
    private var panelX: CGFloat { CGFloat(viewport.panelX) * zoom }
```

Replace it with:

```swift
    private var viewport: GameViewport {
        var configuration = GameViewport.Configuration()
        configuration.playfieldHeight = 160
        configuration.panelHeight = 40
        configuration.scaling = .fitToWindow
        return GameViewport(configuration: configuration,
            viewWidth: Double(bounds.width), viewHeight: Double(bounds.height))
    }
    private var zoom: CGFloat { CGFloat(viewport.scale) }
    private var visibleWidth: CGFloat { CGFloat(viewport.logicalWidth) }
    /// Square pixels fill the window on both axes, so there is no letterbox.
    private var origin: NSPoint { NSPoint(x: 0, y: 0) }
    private var panelX: CGFloat { CGFloat(viewport.panelX) * zoom }
```

- [ ] **Step 3: Replace `advanceEdgeScrolling` and `clampCamera`**

Find `func advanceEdgeScrolling(elapsed: Double)` and replace its body's velocity lines. The method currently reads:

```swift
    func advanceEdgeScrolling(elapsed: Double) {
        guard let window, window.isKeyWindow, !isHidden else { return }
        let point = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        guard bounds.contains(point) else { return }
        let velocity = viewport.edgeVelocity(x: Double((point.x - origin.x) / zoom),
            y: Double((point.y - origin.y) / (zoom * 1.2)))
        guard velocity.x != 0 || velocity.y != 0 else { return }
        pan(x: CGFloat(velocity.x * min(0.05, max(0, elapsed))),
            y: CGFloat(velocity.y * min(0.05, max(0, elapsed))))
    }
```

Replace it with:

```swift
    func advanceEdgeScrolling(elapsed: Double) {
        guard let window, window.isKeyWindow, !isHidden else { return }
        let point = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        guard bounds.contains(point) else { return }
        let velocity = viewport.edgeVelocity(at: GameViewport.Point(
            x: Double((point.x - origin.x) / zoom), y: Double((point.y - origin.y) / zoom)))
        guard velocity.x != 0 || velocity.y != 0 else { return }
        let step = min(0.05, max(0, elapsed))
        pan(x: CGFloat(velocity.x * step), y: CGFloat(velocity.y * step))
    }
```

Then find `private func clampCamera()`, which currently reads:

```swift
    private func clampCamera() {
        guard let game else { return }
        cameraX = CGFloat(viewport.clampedX(Double(cameraX), minimum: Double(cameraBounds.left),
            maximum: Double(cameraBounds.right), levelWidth: Double(game.configuration.width)))
        let bottom = max(cameraBounds.top, min(cameraBounds.bottom, CGFloat(game.configuration.height - 160)))
        cameraY = min(bottom, max(cameraBounds.top, cameraY))
    }
```

Replace it with:

```swift
    private func clampCamera() {
        guard let game else { return }
        let authored = Double(cameraBounds.left)...max(Double(cameraBounds.left), Double(cameraBounds.right))
        let clamped = viewport.clampCamera(GameViewport.Point(x: Double(cameraX), y: Double(cameraY)),
            levelWidth: Double(game.configuration.width),
            levelHeight: Double(game.configuration.height),
            authored: authored)
        cameraX = CGFloat(clamped.x)
        cameraY = CGFloat(min(max(Double(cameraBounds.top), clamped.y), max(Double(cameraBounds.top), Double(cameraBounds.bottom))))
    }
```

- [ ] **Step 4: Remove the 1.2 factor everywhere**

```bash
sed -i '' 's/zoom \* 1\.2/zoom/g' Sources/LemmingsLocal/Lemmings2PlayWindow.swift
grep -c "1\.2" Sources/LemmingsLocal/Lemmings2PlayWindow.swift
```

Expected: the second command prints `0`. If it prints more, inspect each remaining
site by hand. Also change the two clip and draw rectangles that assume a 240-row
box. Search for `192 * zoom` and `48 * zoom` and change them to `160 * zoom` and
`40 * zoom`:

```bash
grep -n "192 \* zoom\|48 \* zoom" Sources/LemmingsLocal/Lemmings2PlayWindow.swift
```

- [ ] **Step 5: Delete the old viewport and the suite it fed**

`Tests/Lemmings2ViewportTests/main.swift` tests `Lemmings2Viewport` directly, and
`Scripts/run-lemmings2-viewport-tests.sh` builds it against that one file. Both
go with the type. Task 1 and Task 2 already carry its distinctive assertions,
under the two `PASS` lines that name the Lemmings 2 geometry and the old
320-pixel boundary. Confirm those two lines print before deleting anything.

```bash
zsh Scripts/run-game-viewport-tests.sh | grep -c "keeps the Lemmings 2 viewport geometry"
```

Expected: `1`. If it prints `0`, stop. Task 1 is incomplete and the coverage
would be lost.

```bash
git rm -r --ignore-unmatch Sources/NxlvKit/Lemmings2Viewport.swift Tests/Lemmings2ViewportTests Scripts/run-lemmings2-viewport-tests.sh
rm -rf Sources/NxlvKit/Lemmings2Viewport.swift Tests/Lemmings2ViewportTests Scripts/run-lemmings2-viewport-tests.sh
grep -rn "Lemmings2Viewport" Sources Tests Scripts
```

Expected: the grep prints nothing.

- [ ] **Step 6: Build and test**

```bash
zsh Scripts/run-lemmings2-runtime-tests.sh && zsh Scripts/build-native-l2.sh
```

Expected: the runtime tests PASS and the app builds with no warnings. The runtime
tests cover simulation behavior, which this task must not change.

- [ ] **Step 7: Commit**

```bash
git add -A Sources/LemmingsLocal/Lemmings2PlayWindow.swift Sources/NxlvKit
git commit -m "Square the Lemmings 2 pixels and share its camera"
```

---

### Task 6: Adopt the shared camera in Lemmings 3

**Files:**
- Modify: `Sources/LemmingsLocal/Lemmings3PlayWindow.swift`

**Interfaces:**
- Consumes: `GameViewport` from Tasks 1 to 3.
- Produces: the canvas gains `viewport`, `visibleWidth`, `panelX` and `advanceEdgeScrolling(elapsed:)`. `zoom`, `origin` and `pan(_:_:)` keep their names.

**Geometry change.** The canvas divides height by 160 today, so it reserves no
panel band and draws no panel. Dividing by 200 reserves the 40 rows that Phase 2
fills with the authentic panel. Until Phase 2 lands, that band draws as
background. This is expected, not a defect.

- [ ] **Step 1: Replace the scale and origin**

In `Sources/LemmingsLocal/Lemmings3PlayWindow.swift`, find the canvas properties:

```swift
    private var zoom: CGFloat { max(0.1, min(bounds.width / 320, bounds.height / 160)) }
    private var origin: NSPoint { NSPoint(x: (bounds.width - 320 * zoom) / 2, y: (bounds.height - 160 * zoom) / 2) }
```

Replace them with:

```swift
    private var viewport: GameViewport {
        var configuration = GameViewport.Configuration()
        configuration.playfieldHeight = 160
        configuration.panelHeight = 40
        configuration.scaling = .fitToWindow
        return GameViewport(configuration: configuration,
            viewWidth: Double(bounds.width), viewHeight: Double(bounds.height))
    }
    private var zoom: CGFloat { CGFloat(viewport.scale) }
    private var visibleWidth: CGFloat { CGFloat(viewport.logicalWidth) }
    /// Phase 2 draws the authentic panel here. Until then the band is background.
    private var panelX: CGFloat { CGFloat(viewport.panelX) * zoom }
    /// Square pixels fill the window on both axes, so there is no letterbox.
    private var origin: NSPoint { NSPoint(x: 0, y: 0) }
```

- [ ] **Step 2: Replace `pan`**

Find:

```swift
    private func pan(_ x: CGFloat, _ y: CGFloat) {
        cameraX = max(0, min(CGFloat(max(0, mapWidth - 320)), cameraX + x))
        cameraY = max(0, min(CGFloat(max(0, mapHeight - 160)), cameraY + y)); needsDisplay = true
```

Replace those three lines with:

```swift
    private func pan(_ x: CGFloat, _ y: CGFloat) {
        let clamped = viewport.clampCamera(
            GameViewport.Point(x: Double(cameraX + x), y: Double(cameraY + y)),
            levelWidth: Double(mapWidth), levelHeight: Double(mapHeight))
        cameraX = CGFloat(clamped.x)
        cameraY = CGFloat(clamped.y); needsDisplay = true
```

- [ ] **Step 3: Add edge scrolling**

Add this method to the canvas class, directly after `pan(_:_:)`:

```swift
    /// Scrolls while the pointer rests near a playfield edge.
    func advanceEdgeScrolling(elapsed: Double) {
        guard let window, window.isKeyWindow, !isHidden else { return }
        let point = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        guard bounds.contains(point) else { return }
        let velocity = viewport.edgeVelocity(at: GameViewport.Point(
            x: Double((point.x - origin.x) / zoom), y: Double((point.y - origin.y) / zoom)))
        guard velocity.x != 0 || velocity.y != 0 else { return }
        let step = min(0.05, max(0, elapsed))
        pan(CGFloat(velocity.x * step), CGFloat(velocity.y * step))
    }
```

Add a tracking area so the canvas receives pointer movement. Add this method next to `advanceEdgeScrolling`:

```swift
    override func updateTrackingAreas() {
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self))
        super.updateTrackingAreas()
    }
```

- [ ] **Step 4: Drive it from the frame update**

Find `private func update()` in `Lemmings3PlayWindow`. It reads:

```swift
    private func update() {
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = min(0.1, now - lastTime); lastTime = now
        guard !paused, !game.isComplete else { return }
```

Insert one line after the `elapsed` line and before the `guard`, so edge scrolling
works while paused, as it does in Lemmings 2:

```swift
        canvas.advanceEdgeScrolling(elapsed: elapsed)
```

- [ ] **Step 5: Fix the click and hit-test conversions**

The canvas converts clicks with a line of the form:

```swift
        let x = (point.x - origin.x) / zoom, y = (point.y - origin.y) / zoom
```

Confirm the bound check that follows uses the camera width rather than a fixed 320:

```bash
grep -n "x < 320\|x >= 320\|visibleWidth" Sources/LemmingsLocal/Lemmings3PlayWindow.swift
```

Change any `320` bound in a hit test to `visibleWidth`, and any `160` playfield
bound to `CGFloat(viewport.logicalPlayfieldHeight)`.

- [ ] **Step 6: Build and test**

```bash
zsh Scripts/run-lemmings3-runtime-tests.sh && zsh Scripts/build-native-l3.sh
```

Expected: the runtime tests PASS and the app builds with no warnings.

- [ ] **Step 7: Commit**

```bash
git add Sources/LemmingsLocal/Lemmings3PlayWindow.swift
git commit -m "Give Lemmings 3 a widescreen camera and an edge scroll"
```

---

### Task 7: One key table for the three engines

**Files:**
- Modify: `Sources/NxlvKit/GameKeyBinding.swift` (created as a placeholder in Task 1)
- Create: `Tests/GameKeyBindingTests/main.swift`
- Modify: `Sources/LemmingsLocal/main.swift`
- Modify: `Sources/LemmingsLocal/Lemmings3PlayWindow.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `GameKeyBinding.Action` with cases `skill(Int)`, `pause`, `step`, `stepBack`, `rewind`, `fastForward`, `retry`, `nextLevel`, `nuke`, `menu`, `confirm`, `zoomIn`, `zoomOut`, `pan(dx: Int, dy: Int)`. `GameKeyBinding.Capabilities` with `skillCount`, `supportsStep`, `supportsRewind`, `supportsNuke`, and the presets `classic`, `lemmings2`, `lemmings3`. `GameKeyBinding.action(characters:keyCode:capabilities:) -> Action?`. `GameKeyBinding.fastForwardMultiplier: Double`.

**The divergence this ends.** Classic binds `z` to rewind, `,` and `.` to step,
`n` to next, `p` to pause and `x` to nuke. Lemmings 2 has no step, no rewind and
no nuke key, because nuking needs a double click on the panel. Lemmings 3 has
`.` for step and sends `Escape` to an end-run sheet where Lemmings 2 returns to
the menu.

**Fast forward.** Classic and Lemmings 2 use three times. Lemmings 3 uses eight
times. `fastForwardMultiplier` is one constant, set to `3`, because two of the
three engines and the original games use it. Change that one line to `8` if the
faster value is preferred.

**Pan is a direction, not a distance.** `pan(dx:dy:)` returns -1, 0 or 1 on each
axis. Each caller multiplies by its own step, so this task changes no scroll
distance.

- [ ] **Step 1: Write the failing test**

Create `Tests/GameKeyBindingTests/main.swift`:

```swift
import Foundation
import NxlvKit

func require(_ value: Bool, _ message: String) throws {
    if !value { throw SequelDataError.invalid(message) }
}

do {
    // The same key means the same thing in all three engines.
    for capabilities in [GameKeyBinding.Capabilities.classic,
                         GameKeyBinding.Capabilities.lemmings2,
                         GameKeyBinding.Capabilities.lemmings3] {
        try require(GameKeyBinding.action(characters: " ", keyCode: 49, capabilities: capabilities) == .pause,
            "space pauses in every engine")
        try require(GameKeyBinding.action(characters: "p", keyCode: 35, capabilities: capabilities) == .pause,
            "p pauses in every engine")
        try require(GameKeyBinding.action(characters: "r", keyCode: 15, capabilities: capabilities) == .retry,
            "r retries in every engine")
        try require(GameKeyBinding.action(characters: "f", keyCode: 3, capabilities: capabilities) == .fastForward,
            "f fast forwards in every engine")
        try require(GameKeyBinding.action(characters: "", keyCode: 53, capabilities: capabilities) == .menu,
            "escape opens the menu in every engine")
        try require(GameKeyBinding.action(characters: "", keyCode: 123, capabilities: capabilities) == .pan(dx: -1, dy: 0),
            "left arrow pans left in every engine")
        try require(GameKeyBinding.action(characters: ".", keyCode: 47, capabilities: capabilities) == .step,
            "period steps in every engine")
    }
    print("PASS GameKeyBinding shares one vocabulary")

    // Capitals bind the same as lower case.
    try require(GameKeyBinding.action(characters: "R", keyCode: 15, capabilities: .classic) == .retry,
        "an upper case key binds like its lower case")

    // An engine without a capability yields nothing rather than a wrong action.
    try require(GameKeyBinding.action(characters: "z", keyCode: 6, capabilities: .classic) == .rewind,
        "classic rewinds")
    try require(GameKeyBinding.action(characters: "z", keyCode: 6, capabilities: .lemmings2) == nil,
        "Lemmings 2 has no rewind yet")
    try require(GameKeyBinding.action(characters: "x", keyCode: 7, capabilities: .lemmings2) == .nuke,
        "Lemmings 2 gains a nuke key")
    try require(GameKeyBinding.action(characters: "x", keyCode: 7, capabilities: .lemmings3) == nil,
        "Lemmings 3 has no nuke until Phase 4")
    print("PASS GameKeyBinding respects engine capabilities")

    // Skill digits stop at each engine's count.
    try require(GameKeyBinding.action(characters: "5", keyCode: 23, capabilities: .lemmings3) == .skill(4),
        "digit five selects the fifth Lemmings 3 action")
    try require(GameKeyBinding.action(characters: "6", keyCode: 22, capabilities: .lemmings3) == nil,
        "Lemmings 3 has only five actions")
    try require(GameKeyBinding.action(characters: "8", keyCode: 28, capabilities: .classic) == .skill(7),
        "digit eight selects the eighth classic skill")
    try require(GameKeyBinding.action(characters: "0", keyCode: 29, capabilities: .classic) == nil,
        "zero selects no skill")
    print("PASS GameKeyBinding maps skill digits")

    try require(GameKeyBinding.fastForwardMultiplier == 3,
        "one fast forward multiplier for the three engines")
    print("PASS GameKeyBinding shares one fast forward speed")
} catch {
    print("FAIL \(error)")
    exit(1)
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `zsh Scripts/run-game-viewport-tests.sh`
Expected: FAIL. The compiler reports `cannot find 'GameKeyBinding' in scope`.

- [ ] **Step 3: Write the implementation**

Replace the whole contents of `Sources/NxlvKit/GameKeyBinding.swift` with:

```swift
import Foundation

/// One key vocabulary for the classic, Lemmings 2 and Lemmings 3 engines.
///
/// The three engines bound different keys to the same idea, and the same key to
/// different ideas. This table is the single answer. An engine that cannot
/// perform an action yields nothing for its key rather than a wrong action.
public struct GameKeyBinding: Sendable {
    public enum Action: Equatable, Sendable {
        case skill(Int)
        case pause
        case step
        case stepBack
        case rewind
        case fastForward
        case retry
        case nextLevel
        case nuke
        case menu
        case confirm
        case zoomIn
        case zoomOut
        /// A direction, not a distance. Each caller applies its own step.
        case pan(dx: Int, dy: Int)
    }

    public struct Capabilities: Sendable {
        public var skillCount: Int
        public var supportsStep: Bool
        public var supportsRewind: Bool
        public var supportsNuke: Bool

        public init(skillCount: Int, supportsStep: Bool, supportsRewind: Bool, supportsNuke: Bool) {
            self.skillCount = skillCount
            self.supportsStep = supportsStep
            self.supportsRewind = supportsRewind
            self.supportsNuke = supportsNuke
        }

        public static let classic = Capabilities(skillCount: 8, supportsStep: true,
            supportsRewind: true, supportsNuke: true)
        /// Lemmings 2 gains step and a nuke key here. Rewind waits for Phase 5.
        public static let lemmings2 = Capabilities(skillCount: 8, supportsStep: true,
            supportsRewind: false, supportsNuke: true)
        /// Lemmings 3 has no nuke in its runtime yet. Phase 4 adds it.
        public static let lemmings3 = Capabilities(skillCount: 5, supportsStep: true,
            supportsRewind: false, supportsNuke: false)
    }

    /// Simulation speed while fast forward is on. Two of the three engines and
    /// the original games use three.
    public static let fastForwardMultiplier = 3.0

    public static func action(characters: String, keyCode: UInt16,
                              capabilities: Capabilities) -> Action? {
        switch keyCode {
        case 123: return .pan(dx: -1, dy: 0)
        case 124: return .pan(dx: 1, dy: 0)
        case 125: return .pan(dx: 0, dy: 1)
        case 126: return .pan(dx: 0, dy: -1)
        case 53: return .menu
        case 36, 76: return .confirm
        default: break
        }
        let key = characters.lowercased()
        if let digit = Int(key), digit >= 1, digit <= capabilities.skillCount {
            return .skill(digit - 1)
        }
        switch key {
        case " ", "p": return .pause
        case "r": return .retry
        case "f": return .fastForward
        case "n": return .nextLevel
        case "=", "+": return .zoomIn
        case "-", "_": return .zoomOut
        case ".": return capabilities.supportsStep ? .step : nil
        case ",": return capabilities.supportsStep ? .stepBack : nil
        case "z": return capabilities.supportsRewind ? .rewind : nil
        case "x": return capabilities.supportsNuke ? .nuke : nil
        default: return nil
        }
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `zsh Scripts/run-game-viewport-tests.sh`
Expected: PASS on all four `GameKeyBinding` lines.

- [ ] **Step 5: Commit the table before wiring it**

```bash
git add Sources/NxlvKit/GameKeyBinding.swift Tests/GameKeyBindingTests/main.swift
git commit -m "Name every game key once"
```

- [ ] **Step 6: Route the Lemmings 3 keys through the table**

In `Sources/LemmingsLocal/Lemmings3PlayWindow.swift`, find the `canvas.onKey` closure:

```swift
        canvas.onKey = { [weak self] key in
            guard let self else { return }
            if let number = Int(key), (1...5).contains(number) { self.selected = number - 1; self.refresh() }
            else if key == " " { self.togglePause() }
            else if key == "." { self.singleStep() }
            else if key.lowercased() == "r" { self.restart() }
            else if key.lowercased() == "f" { self.toggleFast() }
            else if key == "\u{1b}" { self.confirmEndRun() }
```

Replace those lines through the closing brace of the closure with:

```swift
        canvas.onKey = { [weak self] key in
            guard let self else { return }
            let code: UInt16 = key == "\u{1b}" ? 53 : 0
            switch GameKeyBinding.action(characters: key, keyCode: code,
                                         capabilities: .lemmings3) {
            case .skill(let index): self.selected = index; self.refresh()
            case .pause: self.togglePause()
            case .step: self.singleStep()
            case .retry: self.restart()
            case .fastForward: self.toggleFast()
            case .menu: self.confirmEndRun()
            default: break
            }
        }
```

- [ ] **Step 7: Use the shared multiplier**

In the same file, find:

```swift
        accumulator += elapsed * (fast ? 8 : 1)
```

Replace it with:

```swift
        accumulator += elapsed * (fast ? GameKeyBinding.fastForwardMultiplier : 1)
```

Then find the button title `"Fast ×8 (F)"` and the status string containing `"8×"`, and change both to read from the constant:

```bash
grep -n '8×\|Fast ×8' Sources/LemmingsLocal/Lemmings3PlayWindow.swift
```

Change the button title to `"Fast ×\(Int(GameKeyBinding.fastForwardMultiplier)) (F)"` and the status fragment to `"\(Int(GameKeyBinding.fastForwardMultiplier))×"`.

- [ ] **Step 8: Route the classic keys through the table**

In `Sources/LemmingsLocal/main.swift`, find the `switch characters` block inside the key monitor. It starts at `case "z": self.rewind(seconds: 2)` and ends with `default: return event`. Replace the whole switch with:

```swift
      switch GameKeyBinding.action(characters: characters, keyCode: event.keyCode,
                                   capabilities: .classic) {
      case .rewind: self.rewind(seconds: 2)
      case .stepBack: self.stepBackward()
      case .step: self.stepForward()
      case .confirm: self.advancePhase()
      case .nextLevel: self.nextLevel()
      case .retry: self.retry()
      case .pause:
        if characters == " ", self.phase != .playing { self.advancePhase() }
        else { self.togglePause() }
      case .fastForward: self.toggleFastForward()
      case .nuke: self.handle(.nuke)
      default:
        if characters == "q" {
          if var current = self.flow {
            current.abandonLevel()
            self.flow = current
            self.renderScreen()
          }
        } else { return event }
      }
      return nil
```

The digit handling above this switch already covers skills, so leave it. The
screen-key block above it also stays, because it must run first.

- [ ] **Step 9: Build and test**

```bash
zsh Scripts/run-game-viewport-tests.sh && zsh Scripts/build-local-app.sh && zsh Scripts/build-native-l3.sh
```

Expected: tests PASS, both apps build with no warnings.

- [ ] **Step 10: Commit**

```bash
git add Sources/LemmingsLocal/main.swift Sources/LemmingsLocal/Lemmings3PlayWindow.swift
git commit -m "Bind the same key to the same idea in every engine"
```

---

### Task 8: The divergence audit

**Files:**
- Create: `Documentation/EngineDivergence.md`
- Modify: `Documentation/SequelInterpreters.md`

**Interfaces:**
- Consumes: nothing. This task changes no behavior.
- Produces: `Documentation/EngineDivergence.md`, the register Phase 4 executes from.

**This task writes only.** It records what the engines do and what each
difference is worth. It changes no code. Every later phase adds rows here before
it changes behavior.

- [ ] **Step 1: Write the audit**

Create `Documentation/EngineDivergence.md`:

```markdown
# Engine divergence

The classic, Lemmings 2 and Lemmings 3 engines share a window and a player. They
do not share every rule. This register records each shared mechanic, what each
engine does, and one verdict.

A verdict of **authentic** means the original games differed. Leave the
difference in place. A verdict of **unify** means the difference came from this
port, not from the originals. Phase 4 removes it.

No entry gets a verdict without evidence. Name the file and the symbol.

## Cursor targeting. Verdict: unify

| Engine | Rule |
| --- | --- |
| Classic | `PlayfieldView.lemming(at:)`. Strict containment, no snapping, last drawn wins |
| Lemmings 2 | `Lemmings2Runtime.target(slot:x:y:)`. Box of 9 by 12, eligible first, then Manhattan distance, then lowest id |
| Lemmings 3 | `Lemmings3PlayWindow.assign(x:y:)`. Same box, anchor `y - 8` against `y - 5`, carrier first, no eligibility check |

The classic comment argues against the other two. It says that picking the
nearest lemming inside a radius looks like the cursor sticks to a lemming it is
not over, and that two lemmings side by side become impossible to tell apart.

Nothing in the original games explains why Lemmings 2 and Lemmings 3 use
different anchors and different priorities. Choose one rule for all three.

Target selection is input, not simulation. Replays call `assign` with an id and
never call `target`, so this change cannot alter a replay.

## Release rate. Verdict: authentic

| Engine | Rule |
| --- | --- |
| Classic | `ClassicDOSSimulation.releaseRate` is mutable and logs `releaseRateChanged(Int)` |
| Lemmings 2 | `Lemmings2Runtime` computes `21 - level.releaseRate` once |
| Lemmings 3 | `Lemmings3Runtime` takes `level.releaseRate` once |

Only classic lets the player change the rate. The original sequels removed the
rate buttons. Keep this difference.

## Nuke. Verdict: unify

| Engine | Rule |
| --- | --- |
| Classic | `ClassicDOSSimulation.beginNuke()`, bound to `x` |
| Lemmings 2 | `Lemmings2Runtime.nuke()`, reached by a double click on the panel |
| Lemmings 3 | None. `grep -c nuke` returns zero in the runtime and the window |

The original Lemmings 3 panel carries a nuke button. The decoded `PAN004.RAW`
shows it in the ninth slot. Phase 4 adds `nuke()` to `Lemmings3Runtime` and
wires the panel button and the `x` key.

## Fast forward. Verdict: unify. Closed in Phase 0

Classic and Lemmings 2 used three times. Lemmings 3 used eight times. Nothing in
the data explains the difference. `GameKeyBinding.fastForwardMultiplier` is now
the one value.

## Key bindings. Verdict: unify. Closed in Phase 0

The three engines bound different keys to the same idea. Classic had rewind,
step and a nuke key. Lemmings 2 had none of the three. Lemmings 3 sent `Escape`
to an end-run sheet where Lemmings 2 returned to the menu.
`GameKeyBinding.action(characters:keyCode:capabilities:)` is now the one table.
An engine that cannot perform an action yields nothing for its key.

## Pixel shape. Verdict: unify. Closed in Phase 0

Lemmings 2 drew with `zoom * 1.2`. Classic and Lemmings 3 drew square. All three
now draw square. This trades the 4:3 shape of the original hardware for one
geometry rule. The choice is deliberate and recorded in the camera spec.

## Open questions for later phases

These need evidence before they get a verdict.

- Blocker release. Lemmings 3 releases a blocker with Walker. Check what classic
  and Lemmings 2 do, and whether the originals differed.
- Time limit and bonus seconds. Lemmings 3 grants bonus seconds from a clock
  tool. Check how the others present remaining time.
- Retry semantics. Check whether retry restores the starting population in each
  engine.
- Results and failure screens. Check what each engine shows after a lost level.
```

- [ ] **Step 2: Link it from the existing documentation**

In `Documentation/SequelInterpreters.md`, add this line directly under the first paragraph:

```markdown
See [engine divergence](EngineDivergence.md) for the register of shared
mechanics and their verdicts.
```

- [ ] **Step 3: Lint the prose**

```bash
python3 ~/.claude/skills/ste-writing/ste-lint.py Documentation/EngineDivergence.md
```

Expected: `em_dash= 0` and a `per100w` figure below 3.0. Fix any long sentence
the linter counts, then run it again.

- [ ] **Step 4: Commit**

```bash
git add Documentation/EngineDivergence.md Documentation/SequelInterpreters.md
git commit -m "Write down where the engines disagree"
```

---

## Phase 0 completion check

- [ ] Run the full regression pass:

```bash
zsh Scripts/run-game-viewport-tests.sh
zsh Scripts/run-playfield-draw-tests.sh
zsh Scripts/run-lemmings2-runtime-tests.sh
zsh Scripts/run-lemmings3-runtime-tests.sh
zsh Scripts/run-classic-dos-replay-tests.sh
zsh Scripts/run-unified-game-tests.sh
```

Every one must pass. The replay tests are the guard on the convergence boundary.
A replay failure means a change reached a simulation, which Phase 0 forbids.

- [ ] Confirm no engine keeps private camera math:

```bash
grep -rn "zoom \* 1.2\|Lemmings2Viewport" Sources
```

Expected: no output.

- [ ] Golden screenshot references need regenerating, because square pixels
  change the Lemmings 2 output and the new scale divisor changes the Lemmings 3
  output. Regenerate and inspect them before accepting the diff.

---

### Task 9: Free zoom in Lemmings 2 and Lemmings 3

**Files:**
- Modify: `Sources/LemmingsLocal/Lemmings2PlayWindow.swift`
- Modify: `Sources/LemmingsLocal/Lemmings3PlayWindow.swift`

**Interfaces:**
- Consumes: `GameViewport.Scaling.free(_:)` and `snappedZoom(_:)` from Task 1, and `GameKeyBinding.Action.zoomIn` and `.zoomOut` from Task 7.
- Produces: each canvas gains `var zoomOverride: Double?` and `func adjustZoom(_ steps: Int)`. A `nil` override means fit to window.

**Why this task exists.** The camera spec says Lemmings 2 and Lemmings 3 gain
free zoom, which classic already has. Tasks 5 and 6 set `.fitToWindow` only, so
without this task `snappedZoom`, `zoomIn` and `zoomOut` would be public API that
nothing calls.

**The reset matters.** Fit to window is the default and stays reachable. Zooming
out past the fit scale returns the override to `nil` rather than showing space
outside the level.

- [ ] **Step 1: Add the override to the Lemmings 2 canvas**

In `Sources/LemmingsLocal/Lemmings2PlayWindow.swift`, find the `viewport` property written in Task 5:

```swift
    private var viewport: GameViewport {
        var configuration = GameViewport.Configuration()
        configuration.playfieldHeight = 160
        configuration.panelHeight = 40
        configuration.scaling = .fitToWindow
        return GameViewport(configuration: configuration,
            viewWidth: Double(bounds.width), viewHeight: Double(bounds.height))
    }
```

Replace it with:

```swift
    /// A nil override fits the window. A value zooms freely from that fit.
    var zoomOverride: Double?

    private var viewport: GameViewport {
        var configuration = GameViewport.Configuration()
        configuration.playfieldHeight = 160
        configuration.panelHeight = 40
        configuration.scaling = zoomOverride.map { .free($0) } ?? .fitToWindow
        return GameViewport(configuration: configuration,
            viewWidth: Double(bounds.width), viewHeight: Double(bounds.height))
    }

    /// Steps the zoom, snapping so artwork pixels stay on whole device pixels.
    /// Zooming out past the fit scale returns to fit rather than showing
    /// space outside the level.
    func adjustZoom(_ steps: Int) {
        var fit = GameViewport.Configuration()
        fit.playfieldHeight = 160
        fit.panelHeight = 40
        let fitted = GameViewport(configuration: fit,
            viewWidth: Double(bounds.width), viewHeight: Double(bounds.height))
        let current = zoomOverride ?? fitted.scale
        let next = fitted.snappedZoom(current + Double(steps) / fitted.configuration.artworkScale)
        zoomOverride = next <= fitted.scale ? nil : next
        clampCamera()
        needsDisplay = true
    }
```

- [ ] **Step 2: Wire the Lemmings 2 keys**

Find where `Lemmings2PlayWindow` handles keys. The window sets both
`front.onKey` and `canvas.onKey` to `{ [weak self] key in self?.key(key) }`.
Locate `private func key(_ key: String)` and add these two cases to its handling,
before any existing default:

```swift
        if key == "=" || key == "+" { canvas.adjustZoom(1); return }
        if key == "-" || key == "_" { canvas.adjustZoom(-1); return }
```

- [ ] **Step 3: Add the override to the Lemmings 3 canvas**

In `Sources/LemmingsLocal/Lemmings3PlayWindow.swift`, find the `viewport` property written in Task 6 and replace it with the same pattern:

```swift
    /// A nil override fits the window. A value zooms freely from that fit.
    var zoomOverride: Double?

    private var viewport: GameViewport {
        var configuration = GameViewport.Configuration()
        configuration.playfieldHeight = 160
        configuration.panelHeight = 40
        configuration.scaling = zoomOverride.map { .free($0) } ?? .fitToWindow
        return GameViewport(configuration: configuration,
            viewWidth: Double(bounds.width), viewHeight: Double(bounds.height))
    }

    /// Steps the zoom, snapping so artwork pixels stay on whole device pixels.
    /// Zooming out past the fit scale returns to fit rather than showing
    /// space outside the level.
    func adjustZoom(_ steps: Int) {
        var fit = GameViewport.Configuration()
        fit.playfieldHeight = 160
        fit.panelHeight = 40
        let fitted = GameViewport(configuration: fit,
            viewWidth: Double(bounds.width), viewHeight: Double(bounds.height))
        let current = zoomOverride ?? fitted.scale
        let next = fitted.snappedZoom(current + Double(steps) / fitted.configuration.artworkScale)
        zoomOverride = next <= fitted.scale ? nil : next
        pan(0, 0)
    }
```

`pan(0, 0)` reuses the clamp and redraw that Task 6 already wrote.

- [ ] **Step 4: Wire the Lemmings 3 keys**

In the `canvas.onKey` switch written in Task 7 Step 6, add two cases before `default`:

```swift
            case .zoomIn: self.canvas.adjustZoom(1)
            case .zoomOut: self.canvas.adjustZoom(-1)
```

- [ ] **Step 5: Build and test**

```bash
zsh Scripts/run-game-viewport-tests.sh && zsh Scripts/build-native-l2.sh && zsh Scripts/build-native-l3.sh
```

Expected: tests PASS and both apps build with no warnings.

- [ ] **Step 6: Verify by hand**

Open either app, start a level, and press `=` several times then `-` several
times. The view must zoom in whole steps, stay crisp with no shimmering, and
settle back to the fitted view rather than showing space outside the level.

- [ ] **Step 7: Commit**

```bash
git add Sources/LemmingsLocal/Lemmings2PlayWindow.swift Sources/LemmingsLocal/Lemmings3PlayWindow.swift
git commit -m "Let the sequels zoom as the classic game does"
```

---

## Deviations from the spec

The self-review found two places where this plan departs from the camera spec.
A reviewer may accept or reject each one.

**No `EdgeScroller` helper type.** Section 4 of the spec asks for a small helper
owning the per-frame edge-scroll tick. This plan puts `advanceEdgeScrolling`
directly on each canvas instead, matching the method Lemmings 2 already has. The
shared `edgeVelocity` already removes the arithmetic that was duplicated. What
remains is a ten-line wrapper whose only variation is each canvas's own `pan`
signature. A helper covering three different view types would need a protocol,
which costs more than the duplication it removes. Revisit this if a fourth
caller appears.

**Scroll-wheel handling stays per canvas.** Section 4 also asks for shared
scroll-wheel handling. The three implementations differ in axis mapping and in
modifier behavior, and classic inverts its deltas where the sequels do not.
Unifying them changes feel, and feel changes belong with evidence in the
divergence register. Task 8 does not list scroll-wheel behavior yet. Add it as
an open question and settle it in Phase 4 rather than silently here.
