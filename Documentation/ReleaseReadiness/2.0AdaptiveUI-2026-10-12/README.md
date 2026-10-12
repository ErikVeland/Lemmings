# Adaptive iPad and Duo source work

12 October 2026. This source increment continues the Mac-style panel and cover
browser work already present in the checkout. It does not replace the installed
build 8 candidate or close the full iOS parity gate.

The wide Classic HUD retains the original 320×40 panel at whole-number scales.
The minimum panel scale is 3× so its 16-pixel sockets meet the 44-point touch
minimum. Smaller views use the same artwork in grouped skill and transport
sockets. Menu has a readable name. Slower, speed and faster have separate input
rectangles matching their rendered regions. Step stays dimmed while running.
The minimap shares its bitmap drawing with the headless audit and rejects hits
outside the visible map. iPad keeps the cover browser in both orientations when
the available menu region is wide enough.

An availability-gated UIKit adapter reads active division and occlusion frames
in the root view's coordinate space, including system interactive margins.
Fixed controls, scrolling menus and touch loupes avoid those regions. Gameplay
can remain continuous across a vertical division. Touch assignments cannot begin
or finish inside a reserved region. A horizontal division puts the live level
above it and the control console below it. These are system-region responses,
not device-name or fixed-screen-size detection.

The first useful playfield size fits the level. Later resize events keep zoom
and the camera centre, subject to level boundaries, and retain the same session,
selected skill, run ID and checkpoint owner. Active input cancels when layout
changes. Insufficient space pauses and saves the run. Restoring space presents
Resume and waits for the player. Ready, pause and result pages disable covered
playfield input, including pinch gestures.

When a menu expands into a display with a vertical division, the shipped pixel
walker takes a few steps along its stone border. The 1.2-second decoration has
no input target and never runs during gameplay. Reduced motion suppresses it.
Animation generations prevent an older completion from cancelling a newer walk.
The app artwork package now includes the native lemming sprite bank.

## Verification

All mechanical checks ran headlessly with `LEMMINGS_TEST_AUDIO=muted`.
No app or Simulator was launched. No test window, audio or focus change occurred.

- 24 mobile core tests pass. New checks cover control geometry across Classic,
  L2 and L3 control sets, safe areas, division/occlusion avoidance, Diorama,
  small-view suspension, menu scrolling regions and camera continuity.
- 19 iOS release-tooling tests pass.
- The audit draws 66 front-end pages, 40 Classic HUD states, six cover artwork
  states and three unfold frames. HUD drawing, minimap drawing, control targets,
  cover geometry and pixel lettering are shared with UIKit.
- The HUD states cover Ready, running, fast speed, armed End Run and Undo in
  iPad portrait/landscape, compact, open, horizontal-division, camera-occlusion,
  resized and unavailable layouts. Button targets are at least 44 points,
  remain in the safe area, do not overlap and avoid reserved frames.
- The unsigned arm64 Debug iOS app compiles with Xcode beta 27.2 and the iOS
  27.2 SDK, retaining the iOS 16 deployment baseline. The built artwork package
  contains the eight walking frames.

Rendered iPad, compact, resized, Diorama, occlusion/Undo, cover and unfold states
were inspected. Captures remain in ignored `.build/ios-adaptive-audit` and
`.build/ios-adaptive-audit-packaged` because they contain original game artwork.
The final audit also passes against the compiled app's packaged artwork and
content. All 48 recorded source inputs stayed unchanged through that audit.
The JSON report is retained here.

## Open acceptance

The AppKit offscreen runner cannot exercise UIKit. Native UIKit touch dispatch,
perspective cover layers, VoiceOver order, fold transitions, physical input and
Duo hardware remain unverified. The synthetic division frames validate layout
policy, not a physical pose API or hardware event sequence. The compact deck is
bottom-aligned; dedicated one-thumb vertical-edge controls remain future work.
The fitted minimap's visible height can be smaller than 44 points for long
levels. Its physical touch usability needs device acceptance.

L2/L3 control geometry and existing session/checkpoint tests pass, but their
mobile content factories, native panel artwork, playfield renderers and campaign
flows are still unavailable. Profiles, Hot Seat, Journey, filters/favourites,
records, replays/hints, full settings, music and Mac celebrations remain open.
The cover audit verifies the card artwork and wide-page target geometry, not
UIKit's composited perspective carousel. Reduced-motion cover navigation still
needs parity work and acceptance. No signed candidate, installation, TestFlight
upload or release acceptance is claimed.

Evidence: [render and target report](render-validation.json), [audit](render-audit.log),
[core tests](mobile-core-tests.log), [release-tooling tests](tooling-tests.log),
[unsigned build](ios-build.log), [source inputs](source-manifest.json).
