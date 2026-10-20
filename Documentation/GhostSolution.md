# Ghost solution

Classic offers default-off **Ghost solution** controls after the existing
full-solution reveal confirmation. Mac keeps a checkbox beneath the Your game /
Solution selector. iOS uses a full-width toggle in the paused replay panel.
tvOS uses large, focusable rows beside that panel. The whole ghost row is one
input target. The switch position, On/Off value and focus border distinguish its states.

On iOS and tvOS, open a ghost from Pause > Hint > Ghost solution. It uses the
same spoiler confirmation as Watch solution. Confirmation turns the ghost on and
returns to the paused attempt. The Solution view stays available through the
selector. If the solution is already revealed, Ghost solution turns the ghost
on immediately. The Hint page shows Ghost solution only for Classic sessions
with a verified solution.

Mac Hot Seat also shows ghosts of earlier players' turns (see
[Hot Seat](HotSeat.md)). iOS and tvOS do not have these Hot Seat ghosts yet.

On Mac, the whole selector uses the system arrow, including the gaps between
Your game, Solution and Ghost solution. Hover clears the gameplay reticle and
skill badge. Gameplay restores the selected cursor when the pointer leaves the
selector. The policy applies with pointer confinement on or off and with flat
or CRT presentation. Switching display modes retains the selector above the
active playfield.

The overlay uses sharp, translucent blue silhouettes with an outline from the
current sprite artwork. Draw ghosts behind the live lemmings, before camera and
CRT projection. Ghosts add no targeting, assignment feedback, countdown labels,
sound or input surface. They do not change skill stock, records or run ownership.

`ClassicSolutionGhost` owns a separate simulation, terrain and replay commands.
Rendering synchronises it to the live game's simulation tick. Speed changes,
paused stepping and rewinds therefore follow the live game. With the checkbox
off, the cursor stays parked until the next enable. It reconstructs the matching
tick when enabled during a run. Ten-second checkpoints and a bounded sprite cache
limit repeat seeking and rendering work. Playback stops at the solution's end.

This cursor is separate from the retained Solution view's tick, camera and speed.
Toggling the ghost preserves the current pause or Ready state. Switching views
continues to pause both. A same-level retry for the same owner retains the choice
and synchronises the ghost to the new attempt. A different level or Hot Seat owner
does not inherit the revealed solution or ghost.

Only sprites are overlaid. The ghost follows its own solution terrain, so bridges
or tunnels absent from the live attempt can leave ghosts above ground or inside
terrain. A different release rate can also separate live and solution lemmings.
The overlay demonstrates the recorded route and timing, without making moves.

Verified solutions currently cover Classic and matching Classic fan levels.
Lemmings 2 and 3 retain their existing coaching and checkpoint flows. They do not
offer this toggle because their verified-solution adapters and data are absent.
Recorded movies cannot provide simulation sprites.
Hint pages name their evidence as Checked example route or General coaching.
General coaching begins No level-specific hints available. It cannot imply a
verified solution. Replay and ghost actions still require a separate verified
Classic solution and retain their existing spoiler confirmation.

## Touch and remote controls

Replay choices appear in the paused or Ready panel on iOS and tvOS. They hide
during gameplay and other subpages, so they cannot cover assignment targets.
The ghost row belongs to Your game. The retained Solution view keeps its own
position and transport controls.

- iOS keeps Your game / Solution above a full-width, 56-point Ghost solution row.
  Its On/Off value and moving pixel switch make the state visible. The entire
  row accepts touch, including the label, state and switch.
- tvOS puts wide Your game, Solution and Ghost solution rows beside the pause
  overview. At 2×, the mode rows are 96 points high and the ghost row is 112.
  The selected view has an underline. Focus has a white border. Native remote
  focus and controller navigation share the same row order and action targets.

Closing the panel clears selector focus and resets its activation gate. Opening
it requires a neutral press before TV activation. Toggling preserves the live
attempt, pause or Ready state, retained solution position and player ownership.
Returning to a Ready handover still requires Ready. Replays remain explicit Play actions.

## Validation

- Shared cursor tests compare scheduled and after-tick actions, release-rate
  changes and nuke against the replay player. They cover repeated paused ticks,
  backward and forward seeks, start and completion, changed level data and live
  simulation isolation. Pixel tests cover transparent space and the outline.
- The existing retained replay and sequel checkpoint regressions pass.
- `Tools/IOSMenuAudit` with `--ghost-solution` verifies unchanged live checkpoints,
  silent ghost seeking, retained study position, opaque live sprite priority,
  rewind, retry and changed-level rejection. Ten on/off renders cover narrow
  phone, phone, landscape, iPad and TV sizes. Gameplay captures contain no replay controls.
- The retained-solution pause audit uses the same selector geometry and bitmap
  renderer as UIKit. Fifty-six captures cover narrow phone, phone, landscape,
  iPad, 1080p TV, 720p TV and TV safe areas. Checks cover both views, on/off and
  focus states, complete labels, contained targets, non-overlap and reachable
  TV actions. TV previews and counters stay above the action shelf, including
  720p. Representative renders were inspected.
- UIKit selector tests check native target frames, full-row hit testing,
  displayed scaling, accessibility values, unavailable/hidden activation,
  focus destinations and neutral-press consumption. They are SDK typechecked for iOS and tvOS. Native
  touch and Siri Remote event delivery remain device checks.
- The native Mac retained-solution check presses the actual checkbox and checks
  its hit target. Offscreen, muted captures verify sprites and checkbox artwork.
  It checks running/paused toggles, retained study position, live rewind, Hot Seat
  Ready state, same-owner retry and different-owner invalidation.
- The Mac system-pointer checks pass for Original and Modern cursors in flat
  and CRT views. They cover both mode buttons, the ghost row, gaps, clearing the
  gameplay pointer and restoring it over terrain. Switching display modes keeps
  the selector attached. The CRT fixture loads a source frame before input checks.
- Cursor-region checks cover visible and hidden groups, disabled controls,
  bare terrain and flipped coordinates. Checks use the muted, offscreen runner.
- The Mac app and shared frontends compile for Apple silicon Mac, iOS and tvOS.

Native checks run through `Tools/UITestRunner/run.py` in its default offscreen,
muted mode. The focused build uses isolated shared modules to avoid another
task's SwiftPM build lock. AppKit registration requires the same offscreen
runner outside the filesystem sandbox. Physical touch, Siri Remote focus,
VoiceOver and CRT/HDR display appearance remain manual device checks.
