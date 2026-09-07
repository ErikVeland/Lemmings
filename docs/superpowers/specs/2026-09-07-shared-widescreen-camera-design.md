# Shared widescreen camera

Date: 2026-09-07
Status: approved, not implemented

## Context

The macOS app runs three engines in one window: the classic DOS engine, the
Lemmings 2 runtime, and the Lemmings 3 runtime. Each engine carries its own
camera code. The three copies disagree.

| Engine | Type | Scale | Pixel shape | Edge scroll |
| --- | --- | --- | --- | --- |
| Classic | `Viewport` in `Sources/LemmingsLocal/PlayfieldView.swift` | Free zoom, default 3.0 | Square | Horizontal only, frame-rate tied |
| Lemmings 2 | `Sources/NxlvKit/Lemmings2Viewport.swift`, untracked | Fit to window | 1.2 vertical stretch | Both axes, time-based |
| Lemmings 3 | Inline in `Sources/LemmingsLocal/Lemmings3PlayWindow.swift` | Fit to window | Square | None |

Three results follow from this split. The same lemming has a different shape in
each engine. Lemmings 3 has no widescreen camera and no edge scroll. Classic
scrolls at a speed that follows the frame rate, because `edgeScrollDelta`
returns a fixed step and reads no elapsed time.

This design is sub-project 1 of five. The other four are the Lemmings 3 panel
and gutter, a shared minimap, shared save slots, and shared rewind. Each one
gets its own spec.

## Goal

Replace the three camera implementations with one geometry type. Give all three
engines widescreen width, edge scrolling, free zoom, and one clamp rule.

## Non-goals

- The Lemmings 3 control panel. Sub-project 2 covers it. This design only
  reserves the 40 rows the panel needs.
- The minimap, save slots, and rewind.
- Any change to physics, level data, replays, or progression.
- A shared canvas view. Each engine keeps its own drawing code.

## Decisions

**Square pixels in all three engines.** The 1.2 vertical stretch in Lemmings 2
goes away. The `GameViewport` type carries no pixel-aspect field. The design deletes the
factor rather than makes it configurable. This removes `zoom * 1.2` from about
twenty call sites in `Lemmings2PlayWindow.swift`.

This spec records the tradeoff. All three games ran at 320x200 on 4:3 displays,
so a 1.2 stretch is the shape the original hardware produced. Square pixels
trade that fidelity for one geometry rule and sharper integer scaling. The
Lemmings 2 window changes from an effective 320x240 to 320x200. It looks
squatter than it does today.

**Widescreen expands on both axes.** A wide window shows more level to the left
and right. A tall window shows more level above and below. Lemmings 2 letterboxes
vertically today. That behavior ends. Camera clamping keeps the view inside the
level. A level shorter than the view centers.

**The viewport works in simulation space.** Artwork resolution is separate. The
Macintosh sets render at 2x, and `ClassicMacScene` already models this. It sets
`width = rendered.width * 2` and multiplies each placement, but the collision
mask stays at 1x and terrain edits paint as 2x2 blocks. `GameViewport` therefore
reports `scale` in view points for each *simulation* pixel. The drawing code
applies the artwork factor on top.

The type carries an `artworkScale` value for one purpose. Free zoom snaps to
steps that keep artwork pixels on whole device pixels. A zoom that puts a 2x
artwork pixel on a fractional device pixel makes the sprites shimmer. The
Lemmings 2 and Lemmings 3 Macintosh sets now in progress make this rule apply
to all three engines, not only classic.

**Classic keeps its sibling panel view.** `PanelView` stays a separate view under
Auto Layout, as `main.swift` sets up at lines 293 to 300. Classic therefore
configures a panel height of zero. Lemmings 2 and Lemmings 3 draw their panel
inside the canvas and configure a panel height of 40.

**The work lands on the current working tree.** The tree holds about 4187
uncommitted insertions of beta 8 work across 39 files. Two of those files,
`Lemmings2PlayWindow.swift` and `PlayfieldView.swift`, are the files this
refactor changes most. The camera changes join that diff.

## The type

Add `Sources/NxlvKit/GameViewport.swift`. The type is a value type. It holds no
AppKit code, no drawing code, and no engine state. The caller builds one from a
view size each time it needs one, as `Lemmings2Viewport` does today. Nothing
caches it, so nothing invalidates it.

```swift
public struct GameViewport: Sendable {
    public enum Scaling: Sendable {
        case fitToWindow
        case free(Double)
    }

    public struct Configuration: Sendable {
        public var baseWidth = 320.0
        public var playfieldHeight = 160.0
        public var panelHeight = 0.0
        public var scaling = Scaling.fitToWindow
        public var edgeBand = 12.0
        public var edgeSpeed = 160.0
        public var zoomLimits = 0.5...8.0
        public var artworkScale = 1.0
    }
}
```

### Members

| Member | Meaning |
| --- | --- |
| `scale` | View points for each simulation pixel |
| `logicalWidth` | `viewWidth / scale`. More level fits. The level does not stretch |
| `logicalPlayfieldHeight` | `viewHeight / scale - panelHeight` |
| `originY` | Letterbox offset |
| `contentOffset` | Centers a level smaller than the view |
| `panelX` | Where to draw the 320-wide panel in a wider canvas |
| `edgeVelocity(x:y:)` | Logical pixels per second for each axis |
| `clampCamera(_:level:bounds:)` | One clamp rule, with optional authored bounds |
| `levelPoint(from:)` | View point to level pixel |
| `viewPoint(fromLevel:)` | Level pixel to view point |

`scale` comes from the scaling mode. `fitToWindow` computes
`min(viewWidth / baseWidth, viewHeight / (playfieldHeight + panelHeight))`.
`free` takes the caller's zoom and clamps it to `zoomLimits`. Both modes then
use the same `logicalWidth` formula, so no mode needs a special case.

### Authored camera bounds

Lemmings 2 levels carry camera limits that the designer set. `clampCamera`
takes those bounds as an optional argument. The rule that `Lemmings2Viewport`
already implements in `clampedX` moves into the shared clamp. It subtracts the
extra widescreen width from the right limit, so a wide window does not scroll
past the limit the designer set. Classic and Lemmings 3 pass no bounds, and the
clamp uses the level size.

## Adoption

**Classic.** Delete the `Viewport` struct from `PlayfieldView.swift`. The view
holds a `GameViewport.Configuration` with `scaling` set to `free` and
`panelHeight` set to zero. It keeps its own camera position. `edgeScrollDelta`
goes away, and the shared edge scroller replaces it.

**Lemmings 2.** Delete the untracked `Lemmings2Viewport.swift`. The file is not
committed yet, so no history changes. Set `panelHeight` to 40. Remove the 1.2
factor from every draw call. Route `cameraBounds` into the shared clamp. Add
free zoom.

**Lemmings 3.** Delete the inline `zoom`, `origin`, and `pan` code from the
canvas in `Lemmings3PlayWindow.swift`. Set `panelHeight` to 40, which reserves
the band that sub-project 2 fills with the original panel. Add edge scrolling
and free zoom. The scale divisor changes from `min(w/320, h/160)` to
`min(w/320, h/200)`, so the Lemmings 3 view geometry changes with this work.

## View-side plumbing

Move only the code that all three copies repeat. Add an `EdgeScroller` helper
that owns the per-frame step. Each frame it reads the mouse position, asks
`edgeVelocity` for a speed, multiplies by elapsed time, and pans the camera.
Share the scroll-wheel handler in the same way.

Tracking areas, cursor rectangles, and hit testing stay in each canvas. This
design does not unify the canvas views. That would restructure two large views
that already carry uncommitted beta 8 changes.

The shared edge scroller fixes the classic frame-rate bug. Classic multiplies by
a fixed step today. Lemmings 2 multiplies by elapsed time. The shared helper
uses elapsed time for all three.

### Open item for the implementer

The `edgeVelocity` ramp shape is a feel decision. Lemmings 2 ramps linearly
across a 12-pixel band to 160 pixels per second. Classic ramps linearly across
a 48-point band to a frame-tied step. The code does not say which curve, band
width, or top speed is right. The implementation hands this function body to
the user, with the signature and the tests already in place.

## Testing

Add `Tests/GameViewportTests` and `Scripts/run-game-viewport-tests.sh`. This
matches the per-area harness convention the repository already uses.

The type is pure geometry, so these tests need no game assets:

1. Widescreen width at 16:9, 4:3, and portrait view sizes.
2. Edge velocity sign and ramp at each band, and zero in the dead zone.
3. Clamping against level bounds.
4. Clamping against authored Lemmings 2 bounds in a wide window.
5. Round trip from `levelPoint` to `viewPoint` and back.
6. Centering for a level shorter and narrower than the view.
7. Zoom clamped to `zoomLimits` in `free` mode.
8. Zoom snapping keeps 2x artwork pixels on whole device pixels.

Then run the existing harnesses as a regression pass:
`run-playfield-draw-tests.sh`, `run-lemmings2-runtime-tests.sh`,
`run-lemmings3-runtime-tests.sh`, and `run-unified-game-tests.sh`.

Golden screenshot tests that assert pixel geometry need new reference images,
because square pixels change the Lemmings 2 output and the scale divisor changes
the Lemmings 3 output.

## Risks

| Risk | Response |
| --- | --- |
| The refactor mixes into a large uncommitted diff | The user chose this. Keep the camera changes in files a reviewer can read on their own |
| Lemmings 2 players see a shape change | The decisions section records this choice |
| Lemmings 3 geometry changes before its panel exists | The reserved 40 rows draw as empty background until sub-project 2 fills them |
| Widescreen shows level area the designer hid | Authored bounds still clamp Lemmings 2. Classic and Lemmings 3 clamp to the level edge |
