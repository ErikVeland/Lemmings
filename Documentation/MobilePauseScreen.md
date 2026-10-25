# iOS and tvOS pause overview

## Pause response and resume timing

The touch HUD pauses a running attempt on touch-down. Releasing that press
keeps it paused. Play activates on release so holding the same control can
still open the pause menu without advancing the attempt. Fast-speed reset
retains its existing first-press behaviour.

Resume presents the frozen tick before restarting the simulation clock.
The new clock baseline follows the first display callback's controller draws,
HUD work and layout. Older queued display timestamps cannot move that baseline
backward. Pending catch-up ticks and pause time are discarded. This shared
controller path covers Classic, Lemmings 2 and Lemmings 3 on iOS and tvOS,
including planning pauses and Resume from the menu. Ready handovers and the
fresh-start countdown retain their existing boundaries.

Validation on 23 October 2026: 23 focused clock, touch and HUD tests pass.
Their timing cases cover all three engines' tick rates at 1×, 2× and 8×.
Both arm64 Simulator SDK builds pass, including the final shared UI module.
The muted, hostless UIKit suite passes 13 tests on the booted iOS Simulator.
It checks touch-down pause, release behaviour, an unchanged hit target, distinct
Pause/Play renders and the frozen first frame for planning and menu Resume.
The three button renders were inspected. The first run needed corrected
accessibility-label expectations and was stopped after Xcode stalled collecting
its results. The corrected run completes successfully.
Physical iPad touch response and Apple TV controller/display timing remain
device checks.

## Overview

The pause menu shows the current level, attempt owner and frozen playfield.
It groups rescue progress, population, time, controls and music in the shipped
bitmap lettering and stone artwork. Resume remains the primary action at the
bottom-right. Resume stays visible while tools and information scroll.
The opening fade respects Reduce Motion, Reduce Flashes and the system setting.
Ready handovers retain their existing paused boundary.

The fixed header holds Back to library at the left and Main menu at the right.
Do not repeat the return action in the footer. Level tools come before the
preview and statistics: Hint, Restart level and eligible Skip level or Bonus
skill actions. Skip level shows the attempt owner's balance, including a disabled
zero. Lemmings 2 adds its Fan / Skill mode toggle. Replay, Inspect, and Help and
settings form separate groups when present. Controls help retains the platform's
input guide. Each group chooses columns from its available width and full labels.
Every occupied row fills its width, including the final row.
Restart level opens a confirmation with Cancel focused. Confirmation retires
the old checkpoint and starts a fresh attempt with the current owner.
Hot Seat waits at Ready. Replays omit Hint and Restart level.
Keyboard, remote and accessibility focus reveal tools and text above the fixed
Resume shelf. Covered controls and gaps cannot activate tools beneath that shelf.
Large lettering adapts in landscape to keep the action targets within the viewport.

## Rescue and run details

The overview shows saved and required counts, active lemmings, waiting lemmings,
losses, further permitted losses, time left, elapsed simulation time, speed,
release rate, population, skill assignments, rewind use and remaining skill stock.
Long level names, pack names and track titles wrap at the font's fixed size.
All text retains its full accessibility label.

`Lost = released - saved - active`.
`Can lose = max(0, saved + active + waiting - required)`.
A zero margin differs from an unreachable rescue target. Target reached,
run ending and replay states have separate labels. The audio group uses the
actual announced track and soundtrack, including an Original fallback, and
shows paused/beat-only/disabled music and sound-effect volume.

Classic supplies its live simulation count. L2 and L3 count active native actors
and successful action records. L2/L3 retain their shared adapter's one-survivor
rescue requirement and fixed release rate. Both support rewind. L3 has no shared
skill stock, so the screen omits an aggregate stock list. These counts do not
represent tribe medals or per-actor tool stock.

## Journey placement

Let's be careful out there, retail Fun 27, moves from journey lesson 32 to
lesson 94 in Intermediate. Its placement is 287.5, between The Strange Relict
of Rhodes and Take care, Sweetie. The original source and winning witness stay
unchanged. This is an editorial correction from the user's 14 October 2026
playtest. The generator records the correction and route validation enforces
its placement floor.

The journey version is `learning-22`. Migration preserves the run ID, visits,
owner and Hot Seat state. A pending attempt on this level moves later in the
queue. Completed visits retain their history.

The Crankshaft moves from the early Fun lessons, reported at lesson 34, to
lesson 126 in Difficult. Its placement is 377.5, after more worker-coordination
practice. The original source and exact winning witness stay unchanged.
Pending saved attempts move later while past visits and ownership remain intact.

## Replay identity

The replay pause overview retains the full level caption and title. Playback
shows the level number and name on one line in the top status box. Long names
end in an ellipsis. Accessibility retains the full identity. The skill-use
panel sits at the playfield's upper-right edge. Exported replay movies include
the same single-line identity above the complete gameplay image.

## Retained solution views across Mac, iOS and tvOS

After the first confirmed reveal, Your game and Solution share a stone selector.
The live attempt and replay retain separate simulations, cameras, selections and
speeds. Every switch pauses both views. Play or Resume is a separate action.
Returning from the solution goes directly to the game, without reopening Hints.
Ready handovers still require Ready. Switching does not retire a checkpoint,
record a result, pass a turn or replace the attempt owner.

The same player's retry retains the replay position. A different level or player
clears it. Mac retention checks the initial simulation, player/session identity
and game window. Mobile retention checks the engine, level identity/fingerprint
and solo or Hot Seat owner/scope. These views are retained in memory, not restored
after closing the app. The original spoiler confirmation remains required.

Mac supports Control-Tab to switch views, Escape or controller Back to return,
and Control-Left/Right for move navigation. Touch uses the selector and stone
Previous move/Next move icons on either side of the map. Each target is at least
44 points. One-finger dragging moves the replay camera while running or paused,
without changing the simulation or transport. TV uses the same
selector, direct remote Back, and focused move actions on the pause page.
Held activation cannot accept a new TV page before neutral input.

Classic also offers Ghost solution beneath the live selector after reveal.
The checkbox shows solution sprites at the live tick, behind real lemmings.
It follows pause, speed, stepping and rewind without changing the retained replay
position or Hot Seat owner. Toggle changes preserve the current pause/Ready state.
See [Ghost solution](GhostSolution.md) for scope and validation.

Move navigation uses successful skill assignments. Multiple uses at one tick
form one stop. Failed commands, rate changes and end-run commands are excluded.
The first and last move disable the outward action. Seeking stays paused,
reconstructs stock and skill-use counts, and leaves the live checkpoint intact.

Verified solutions currently cover Classic, including matching fan lessons.
Lemmings 2 and 3 retain general coaching and do not have verified solution data
in the current hint route. NeoLemmix and recorded movie playback retain their
existing capabilities. They do not gain an invented solution or move timeline.

## Validation

14 October 2026:

- 26 muted background tests pass: journey validation/migration, loss margins,
  rescue states, native actor losses in all three engines, planning assignments
  and assignment counts.
- 216 windowless bitmap and target checks pass across six rescue states,
  six phone/iPad geometries, three interface sizes and both scroll endpoints.
  Checks cover complete action captions, stock names, target sizes, overlap,
  gap input and pinned Resume reachability. Representative renders were inspected.
- The arm64 iOS `LemmingsMobileUI` target compiles against the iPhoneOS SDK.
- The journey generator's reproducibility check and whitespace check pass.

The renderer checks use fixture rescue counts and track names. Native UIKit
scrolling, VoiceOver dispatch and the opening fade still need a device check.
L2/L3 session adapters were checked headlessly. Native sequel campaigns and
imports still need device checks. No test window or audible playback was used.

Pause shelf follow-up, 18 October 2026:

- 246 muted, windowless pause renders pass with the new shelf on phone, narrow
  phone, iPad and TV geometries. Representative iPhone, landscape, narrow and
  TV renders were inspected.
- The audit now accepts captions that wrap at word boundaries, as the renderer
  does. It reports words that are wider than their button. At 320 points with
  the Large interface size, Library, Resume, Settings, Restart and Controls
  break inside the word. The old shelf had the same defect.
- The restart-confirmation check later in the same audit fails before and after
  this change. It still expects single-line captions.
- The shared mobile modules compile for the arm64 iOS and tvOS simulators.
  Physical touch, VoiceOver and Siri Remote focus remain device checks.

The focused render check is `LemmingsMobileMenuAudit ARTWORK CLASSIC_DATA OUTPUT --pause`,
run through `Tools/UITestRunner/run.py` with its default offscreen, muted settings.

Restart and replay follow-up, 14 October 2026:

- 40 focused background checks pass for journey migration, Hot Seat state,
  fresh retry preparation, rescue margins and native losses across all three engines.
- 252 muted, windowless pause render and target checks pass across phone,
  iPad and TV geometries. Four replay-title and restart-confirmation widths
  check complete captions and action targets. Representative images were inspected.
- The journey generator reproduces its outputs.
- The final shared artwork and mobile UI compile against the arm64 iOS and TV SDKs.
- Full SwiftPM test compilation encountered an unrelated stored-property
  override error in MusicTitleCardTests. The focused suites ran in an isolated
  package using the current shared sources and original test files.
- Native UIKit scrolling, VoiceOver, Siri Remote focus, physical restart journeys
  and movie playback remain manual device checks.

Retained-solution validation, 14 October 2026:

- 16 focused background tests pass for successful move boundaries, rejected
  commands, replay seek/count reconstruction, unchanged live checkpoints,
  Hot Seat state and fresh retry preparation.
- 40 windowless game/solution renders and target checks pass across phone,
  iPad and TV sizes, plus four touch move-button widths. Selected modes,
  disabled directions and representative images were inspected.
- Native Mac checks pass offscreen and muted at 1120x720 and 800x600. They
  exercise repeated switching, retained camera/tick, direct controller return,
  paused simulations, actual Hot Seat ownership, unchanged records after reveal,
  same-player retry retention and different-owner invalidation. Native button
  bounds and hit targets pass, and the rendered pages were inspected.
- Shared iOS/tvOS modules compile against their arm64 SDKs. Physical UIKit
  focus, VoiceOver, hardware shortcuts and Ready handovers remain device checks.
- AppKit registration aborts under the workspace sandbox. The Mac runtime check
  used the same offscreen/muted runner with process-registration access and a
  temporary Hot Seat store. The existing standalone Mac test build script omits
  TV-core dependencies required by current shared artwork. Validation used an
  isolated dependency build and the current production sources with the focused
  test method. No foreground window, audible playback or release audit was used.

Replay viewing update, 24 October 2026: a muted, windowless audit checks 60
start, playing, move and end renders at five phone/tablet sizes across three
engine HUD layouts. It checks single-line truncation, top-right skill history,
44-point move targets and their separation from the map and other controls.
Representative portrait, landscape and tablet renders were inspected. These
use a Classic scene fixture; sequel replay playback is not implemented on mobile.
The shared UI compiles against iOS and tvOS SDKs. UIKit regressions for camera-only
input, paused/running/final frames and disabled move targets compile, but their
execution and physical finger gestures remain unverified.


## Skip and menu layout update, 25 October 2026

Pause and failed results expose the same Skip level balance in Classic, Lemmings 2
and Lemmings 3. Learning skips retain an unsolved lesson under Try later. A skip
saves progression before leaving, charges the attempt owner once and passes a
Hot Seat loss turn once. A failed transition refunds the skip and restores the
prepared progression. L2 carries the whole starting population forward. L3 keeps
its current population. Final campaign and tribe levels remain ineligible.

Main menu occupies the top-right of the fixed navigation band. Results and
recovery pages omit duplicate bottom Menu actions. Complete and
partial button rows fill their width. This applies to pause, results, Settings,
lists, recovery pages, Home footer actions and the level browser. The browser
wraps its controls on narrow screens while retaining Back and Play at the bottom.

Muted windowless checks pass 11 tests, including campaign persistence and rollback,
full-width action rows, 44-point browser targets and top-right navigation. They
produce 32 representative pause, result, settings and collection renders at four
phone/tablet widths. Representative renders were inspected. Shared iOS and tvOS
SDK compilation passes. Seven hostless UIKit tests cover live balances in all three
engine layouts, both Hot Seat rules, one-time charges, handover refunds, result
exit ownership, browser captions/targets, fixed navigation during scrolling and
Main menu placement clear of book/tabletop hinges. Physical touch, folding and Siri Remote focus remain
device checks.

Final mobile validation uses a saved snapshot of the shared sources because
NeoLemmix presentation interfaces changed during the first build. The snapshot
and input hashes remain in `.build/ios-skip-menu-snapshot`.
