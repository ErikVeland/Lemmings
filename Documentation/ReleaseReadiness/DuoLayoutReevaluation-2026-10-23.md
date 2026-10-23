# Duo layout re-evaluation

Date: 23 October 2026, Australia/Brisbane.
Status: source corrections and synthetic validation. Physical pose acceptance remains open.

The owner reported menu buttons changing width during scrolling in Tent Pose,
as though a right bar were present. They also reported stacked skill icons in
a partly folded pose and requested a review of all poses and their transitions.

## Attribution

The menu reflow and unnecessary native skill stacking are app defects.

The previous menu code queried occlusions from the scrolling canvas, then
changed each intersecting row's width. Scroll callbacks explicitly repeated
this operation. Its earlier bitmap audit accepted the changing widths.
The defect therefore does not require an OS region to change while scrolling.

The divided HUD also selected half as many skill columns when a lower pane
was tall. This forced two skill rows even when all eight native skills fit
across its width. A separate full-display path discarded camera occlusions
before placing controls, leaving bottom-corner cameras unprotected after rotation.

Apple defines a reserved region's frame in the queried view's coordinates,
including its interactive margins. The runtime bridge matches the installed
27.2 SDK's selectors, signatures, active-state getter and query option.
See [UIViewReservedRegion](https://developer.apple.com/documentation/uikit/uiviewreservedregion)
and [Apple's adaptive-layout guidance](https://developer.apple.com/videos/play/tech-talks/111463/).

This establishes app causes. It does not establish whether the reported
non-existent bar also reflects a stale UIKit region in a particular 27.2 beta.
No matching device region trace or controlled 27.1 comparison was obtained.
Absence of an active division is a layout policy for an undivided surface,
not proof of front-display identity or a system property named Tent Pose.

## Corrections

- Choose a fixed menu viewport in scene coordinates before measuring controls.
  Prefer full width above or below a corner cutout. Keep backgrounds edge to edge.
  Scroll and bounce move content without changing individual button sizes.
- Keep native skills in one row whenever 44-point targets fit. Bound skill
  cells to 144 points high and transport controls to 80 points in the divided
  deck. Give spare lower-pane space to the overview. In tabletop layouts,
  group navigation beside it rather than stretching navigation buttons.
- Clear the full fixed deck around bottom-corner cameras. Calculate header
  clearance relative to its resulting safe frame so a bar is not counted twice.
- Cancel held HUD buttons, minimap dragging and skill-strip momentum before
  input geometry changes. Clamp the retained skill-strip offset after resizing.
  Cancel menu tracking and scrolling before moving its viewport or book panes.
- Preserve selected skills, sessions, turn ownership and paused Ready boundaries.
  Layout does not advance a turn or resume play.
- Keep a bounded DEBUG history of scene bounds, safe insets, active regions,
  selected menu frame, OS build and app build. The keys are
  `DuoMenuDebugGeometry`, `DuoMenuDebugHistory`, `DuoMenuDebugOS` and
  `DuoMenuDebugBuild`. These distinguish app geometry decisions from raw OS input.

## Layout policy

| Surface | Policy and review boundary |
| --- | --- |
| Front display and tent, portrait and landscape | Fixed scrolling viewport. Test every camera corner, no-region input and real side bars separately. |
| Flat inner display | Tablet Home box and available native gameplay panel. No invented hinge or side bar. |
| Book | Home and results retain separate panes. Gameplay can cross the vertical fold. Control targets and text stay clear of it. |
| Tabletop | Gameplay above the fold. Overview and grouped controls below it. Native skills form one row when they fit. |
| Compact divided layouts | Preserve 44-point targets and all native skills. Keep the original panel only where it fits. |
| Actual leading or trailing navigation space | Retain the shared rail geometry when valid. Do not infer a menu rail from changing scroll coordinates. |
| Pose or window change | Cancel old contacts, retain selection and clamp scroll offsets. Keep Ready and handover paused. |
| Insufficient usable area | Retain the controller's paused fallback. Do not squeeze interactive targets below their minimum. |

The native render checks cover Classic, Lemmings 2 and Lemmings 3.
Imported extended skill sets can still require scrolling or wrapping when
44-point targets cannot fit. Their complete NeoLemmix device coverage remains open.

## Evidence

All mechanical runs use `Tools/UITestRunner/run.py`, default offscreen windows
and muted audio. Bitmap checks create no windows. A frozen source copy avoids
mixing simultaneous touch-input edits from another task into these checks.
The companion JSON records counts and source hashes.

| Check | Evidence |
| --- | --- |
| Focused core suites | 53 tests pass across adaptive layout, portrait HUD/press behaviour and Desk Clock triggers. |
| Partial folds | 120 native-engine layouts cover both hinge axes, four canvas sizes and five hinge widths. Skills remain in one row with bounded heights and clear, separate targets. |
| Rotated front cameras | 24 native-engine cases cover portrait, landscape and all four corners. Fixed controls, status and minimap clear the camera. |
| Menus | 2,923 captures and 6,085 scroll/bounce layouts across 31 pose/region fixtures, 17 pages and all three interface sizes. Checks include fixed widths, action sets, Back/forward ordering, disabled targets and cutout clearance. |
| Gameplay | 341 bitmap captures include 18 pose/region fixtures, six HUD states, all three native engines, previews and five Desk Clock layouts. |
| Split results | 360 result and achievement captures across Classic, L2 and L3. |
| Book Home | 120 captures cover panes, scrolling, input targets and disabled, selected and busy states. |
| Navigation | 82 states, 1,968 layouts and 656 bitmap renders. |
| SDK compilation | DEBUG modules compile for iOS and tvOS. Final changed core, artwork and UI modules are compiled from the frozen source copy. |
| UIKit regressions | Sources type-check. Includes 18 pose/region/rail fixtures and 918 directed HUD transitions, selected-skill visibility and target checks, stale-press cancellation, menu bounce and viewport-tracking cancellation. These tests were not executed. |

Visual review includes scrolled tent Home with both sequel logos, L2 tabletop,
L3 book with the last skill selected, compact Classic tabletop and a bottom-right
camera in Classic landscape. Counts are synthetic geometry evidence, not
physical folding or touch acceptance.

Logs, source copies and captures remain in ignored `.build/duo-layout-*`
paths. Artwork and game data come from the installed Mac app. This does not
validate a signed iOS candidate's resources. No new app was installed or published.

An initial focused invocation could not write the global Clang cache. Local
module caches resolved it. The expanded audit needed a 0.001-point tolerance
for floating-point intersections at the viewport boundary. A live SDK compile
also saw an incomplete touch-effect switch while another task edited it.
The frozen-source compilation resolves that moving-source problem.
Headless CoreSimulator service access failed, so no Simulator window was opened.

## Remaining acceptance

1. Record the installed app build and exact 27.2 beta OS build. Capture the DEBUG
   region history in the failing tent orientation while scrolling Home and settings.
2. Compare closed, front, flat, book, tabletop and tent transitions in both
   directions and orientations, including any camera or navigation-edge change.
3. Repeat while holding a skill or rate button, dragging the minimap, scrolling
   skills and scrolling a menu. Old contacts must not activate after the move.
4. Repeat from running play, Pause, replay, results, settings and Hot Seat Ready.
   Check the selected skill, run, player and turn. Ready still requires Ready.
5. Execute the new UIKit regressions headlessly when Simulator access permits.
   Check physical touch, controller routing, VoiceOver and composited output.
6. If a phantom active region persists, reproduce it with a minimal UIKit view
   and compare the same pose on 27.1 and the exact 27.2 build before attributing
   that remaining defect to iOS.

The earlier Duo records remain historical evidence. Their passing captures do
not close these device checks or override the reported regressions.
